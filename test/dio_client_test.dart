import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/core/constants/api_constants.dart';
import 'package:rios_pastries/core/network/dio_client.dart';
import 'package:rios_pastries/core/storage/token_storage.dart';
import 'package:rios_pastries/data/models/reservation_create_request.dart';
import 'package:rios_pastries/data/models/user_model.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/controllers/reservation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final preferences = <String, Object>{};
  String? failedKey;
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          (call) async {
            switch (call.method) {
              case 'getAll':
                return Map<String, Object>.from(preferences);
              case 'setString':
                final key = call.arguments['key'] as String;
                if (key == failedKey) return false;
                preferences[key] = call.arguments['value'] as Object;
                return true;
              case 'remove':
                final key = call.arguments['key'] as String;
                if (key == failedKey) return false;
                preferences.remove(key);
                return true;
              default:
                throw MissingPluginException(
                  'Método no previsto: ${call.method}',
                );
            }
          },
        );
    await TokenStorage.init();
  });

  setUp(() async {
    failedKey = null;
    await TokenStorage.clearAuth();
    await TokenStorage.saveToken('old-access');
    await TokenStorage.saveRefreshToken('old-refresh');
    await TokenStorage.saveUser(_user);
  });

  test(
    'refreshes, rotates credentials and retries with the new token',
    () async {
      final adapter = _Adapter((options) async {
        if (options.path == ApiConstants.refreshEndpoint) {
          expect(options.data, {'refresh': 'old-refresh'});
          return _response(200, {
            'access': 'new-access',
            'refresh': 'new-refresh',
          });
        }
        if (options.headers['Authorization'] == 'Bearer old-access') {
          return _expired();
        }
        expect(options.headers['Authorization'], 'Bearer new-access');
        return _response(200, {'ok': true});
      });
      final auth = AuthController();
      await auth.checkAuthStatus();
      addTearDown(auth.dispose);

      final response = await _client(adapter).get('halls/');
      await Future<void>.delayed(Duration.zero);

      expect(response.data, {'ok': true});
      expect(await TokenStorage.getToken(), 'new-access');
      expect(await TokenStorage.getRefreshToken(), 'new-refresh');
      expect(auth.currentToken, 'new-access');
      expect(auth.currentUser?.id, '1');
      expect(adapter.requests.length, 3);
    },
  );

  test('refreshes only once for simultaneous expired requests', () async {
    final adapter = _Adapter((options) async {
      if (options.path == ApiConstants.refreshEndpoint) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _response(200, {'access': 'new-access'});
      }
      if (options.headers['Authorization'] == 'Bearer old-access') {
        return _expired();
      }
      return _response(200, {'ok': true});
    });

    final dio = _client(adapter);
    final responses = await Future.wait([
      dio.get('halls/'),
      dio.get('orders/'),
    ]);
    expect(responses.map((response) => response.statusCode), [200, 200]);
    expect(
      adapter.requests.where((r) => r.path == ApiConstants.refreshEndpoint),
      hasLength(1),
    );
    expect(await TokenStorage.getRefreshToken(), 'old-refresh');
  });

  test('does not refresh login failures or unrelated 401 responses', () async {
    final adapter = _Adapter(
      (options) async => _response(401, {'detail': 'No autorizado'}),
    );
    final dio = _client(adapter);
    await expectLater(
      dio.post(ApiConstants.loginEndpoint),
      throwsA(isA<DioException>()),
    );
    await expectLater(dio.get('halls/'), throwsA(isA<DioException>()));
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.headers['Authorization'], isNull);
    expect(await TokenStorage.getToken(), 'old-access');
  });

  test('keeps the session when the refresh has a network failure', () async {
    final adapter = _Adapter((options) async {
      if (options.path == ApiConstants.refreshEndpoint) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
      return _expired();
    });
    await expectLater(
      _client(adapter).get('halls/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.connectionError,
        ),
      ),
    );
    expect(await TokenStorage.getToken(), 'old-access');
    expect(await TokenStorage.getRefreshToken(), 'old-refresh');
  });

  test(
    'clears persistent and in-memory session only for invalid refresh',
    () async {
      final adapter = _Adapter(
        (options) async => options.path == ApiConstants.refreshEndpoint
            ? _response(401, {'code': 'token_not_valid'})
            : _expired(),
      );
      final auth = AuthController();
      await auth.checkAuthStatus();
      addTearDown(auth.dispose);
      await expectLater(
        _client(adapter).get('halls/'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await TokenStorage.getToken(), isNull);
      expect(await TokenStorage.getRefreshToken(), isNull);
      expect(await TokenStorage.getUser(), isNull);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUser, isNull);
    },
  );

  test(
    'does not interpret a refresh error as reservation validation',
    () async {
      final adapter = _Adapter(
        (options) async => options.path == ApiConstants.refreshEndpoint
            ? _response(400, {'code': 'token_not_valid'})
            : _expired(),
      );
      final service = ReservationService(dio: _client(adapter));
      await expectLater(
        service.createReservation(
          ReservationCreateRequest(
            fechaEvento: DateTime(2026, 11, 27),
            cantidadPersonas: 3,
            sala: 4,
          ),
        ),
        throwsA(isA<DioException>()),
      );
      expect(await TokenStorage.getToken(), isNull);
    },
  );

  test('propagates retry failure without logging out', () async {
    final adapter = _Adapter((options) async {
      if (options.path == ApiConstants.refreshEndpoint) {
        return _response(200, {'access': 'new-access'});
      }
      return options.headers['Authorization'] == 'Bearer old-access'
          ? _expired()
          : _response(503, {'detail': 'unavailable'});
    });
    await expectLater(
      _client(adapter).get('halls/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          503,
        ),
      ),
    );
    expect(await TokenStorage.getToken(), 'new-access');
    expect(await TokenStorage.getRefreshToken(), 'old-refresh');
    expect(adapter.requests, hasLength(3));
  });

  test('does not overwrite a session changed while refreshing', () async {
    final adapter = _Adapter((options) async {
      if (options.path == ApiConstants.refreshEndpoint) {
        await TokenStorage.saveToken('other-user');
        await TokenStorage.saveRefreshToken('other-refresh');
        return _response(200, {
          'access': 'new-access',
          'refresh': 'new-refresh',
        });
      }
      return _expired();
    });
    await expectLater(
      _client(adapter).get('halls/'),
      throwsA(isA<DioException>()),
    );
    expect(await TokenStorage.getToken(), 'other-user');
    expect(await TokenStorage.getRefreshToken(), 'other-refresh');
    expect(adapter.requests, hasLength(2));
  });

  test('does not use an access token that failed to persist', () async {
    final adapter = _Adapter(
      (options) async => options.path == ApiConstants.refreshEndpoint
          ? _response(200, {'access': 'new-access'})
          : _expired(),
    );
    failedKey = 'flutter.${ApiConstants.tokenKey}';
    await expectLater(
      _client(adapter).get('halls/'),
      throwsA(isA<DioException>()),
    );
    expect(await TokenStorage.getToken(), 'old-access');
    expect(await TokenStorage.getRefreshToken(), 'old-refresh');
    expect(adapter.requests, hasLength(2));
  });

  test('keeps the session when the refresh server fails', () async {
    final adapter = _Adapter(
      (options) async => options.path == ApiConstants.refreshEndpoint
          ? _response(503, {'detail': 'unavailable'})
          : _expired(),
    );
    await expectLater(
      _client(adapter).get('halls/'),
      throwsA(isA<DioException>()),
    );
    expect(await TokenStorage.getToken(), 'old-access');
    expect(await TokenStorage.getRefreshToken(), 'old-refresh');
  });

  test(
    'does not claim logout succeeded if storage cannot remove the token',
    () async {
      final adapter = _Adapter(
        (options) async => options.path == ApiConstants.refreshEndpoint
            ? _response(401, {'code': 'token_not_valid'})
            : _expired(),
      );
      final auth = AuthController();
      await auth.checkAuthStatus();
      addTearDown(auth.dispose);
      failedKey = 'flutter.${ApiConstants.tokenKey}';
      await expectLater(
        _client(adapter).get('halls/'),
        throwsA(isA<DioException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(await TokenStorage.getToken(), 'old-access');
      expect(auth.isAuthenticated, isTrue);
    },
  );

  test('does not refresh an unauthenticated request', () async {
    await TokenStorage.clearAuth();
    final adapter = _Adapter((options) async => _expired());
    await expectLater(
      _client(adapter).get('halls/'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.headers['Authorization'], isNull);
  });

  test(
    'reservation errors are generic without logging out on refresh failure',
    () async {
      final adapter = _Adapter(
        (options) async => options.path == ApiConstants.refreshEndpoint
            ? _response(503, {'detail': 'private server detail'})
            : _expired(),
      );
      final auth = AuthController();
      await auth.checkAuthStatus();
      final controller = ReservationController(
        reservationService: ReservationService(dio: _client(adapter)),
        authController: auth,
      );
      addTearDown(controller.dispose);
      addTearDown(auth.dispose);
      final saved = await controller.submit(
        fechaEvento: DateTime(2026, 11, 27),
        cantidadPersonas: 3,
        sala: 4,
        cartItems: [],
      );
      expect(saved, isFalse);
      expect(controller.errorMessage, 'Ocurrió un error');
      expect(controller.sessionExpired, isFalse);
      expect(auth.isAuthenticated, isTrue);
    },
  );

  test('reservation field validation remains specific', () async {
    final adapter = _Adapter(
      (options) async => _response(400, {
        'fecha_evento': ['Fecha ocupada.'],
      }),
    );
    final controller = ReservationController(
      reservationService: ReservationService(dio: _client(adapter)),
    );
    addTearDown(controller.dispose);
    final saved = await controller.submit(
      fechaEvento: DateTime(2026, 11, 27),
      cantidadPersonas: 3,
      sala: 4,
      cartItems: [],
    );
    expect(saved, isFalse);
    expect(controller.fieldErrors['fecha_evento'], ['Fecha ocupada.']);
  });

  test('does not replay multipart request bodies', () async {
    final adapter = _Adapter(
      (options) async => options.path == ApiConstants.refreshEndpoint
          ? _response(200, {'access': 'new-access'})
          : _expired(),
    );
    await expectLater(
      _client(adapter)
          .post('upload/', data: FormData.fromMap({'name': 'test'})),
      throwsA(isA<DioException>()),
    );
    expect(await TokenStorage.getToken(), 'new-access');
    expect(adapter.requests, hasLength(2));
  });
}

final _user = UserModel.fromJson({
  'id': 1,
  'email': 'test@example.com',
  'nombres': 'Test',
  'grupo': 'customer',
});

Dio _client(_Adapter adapter) {
  Dio transport() =>
      Dio(BaseOptions(baseUrl: 'https://example.test/api/'))
        ..httpClientAdapter = adapter;
  return DioClient(dio: transport(), refreshDio: transport()).dio;
}

ResponseBody _expired() => _response(401, {'code': 'token_not_valid'});

ResponseBody _response(int status, Object data) => ResponseBody.fromString(
  jsonEncode(data),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
