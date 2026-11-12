import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

/// GlobalKey para poder navegar desde el interceptor sin BuildContext
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DioClient {
  static DioClient? _instance;
  late final Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // QueuedInterceptor: encola peticiones mientras se refresca el token
    dio.interceptors.add(_AuthInterceptor(dio));
  }

  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  /// Traduce excepciones de Dio a mensajes claros en español
  static String handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado. Verifica tu conexión a internet.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        // Si la API devuelve un mensaje de error personalizado
        if (responseData is Map && responseData['message'] != null) {
          return responseData['message'].toString();
        }

        if (statusCode == 400) return 'Solicitud inválida. Revisa los datos enviados.';
        if (statusCode == 401) return 'Credenciales incorrectas o sesión expirada.';
        if (statusCode == 403) return 'Acceso denegado.';
        if (statusCode == 404) return 'Recurso no encontrado en el servidor.';
        if (statusCode != null && statusCode >= 500) {
          return 'Error en el servidor ($statusCode). Intenta de nuevo más tarde.';
        }
        return 'Error en la respuesta del servidor ($statusCode).';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Revisa tu conexión o la URL base.';
      case DioExceptionType.cancel:
        return 'La solicitud fue cancelada.';
      default:
        return 'Ocurrió un error inesperado al comunicarse con el servidor.';
    }
  }
}

/// Interceptor que encola peticiones mientras se refresca el token.
/// Si el access token expiró (401), intenta refrescar con el refresh token.
/// Si ambos expiraron, limpia la sesión y muestra diálogo para re-loguearse.
class _AuthInterceptor extends QueuedInterceptor {
  final Dio _dio;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Evitar loop: si el 401 viene del propio refresh, no reintentar
    if (err.requestOptions.path == ApiConstants.refreshEndpoint) {
      await _forceLogout();
      return handler.next(err);
    }

    // Intentar refrescar el token
    final refreshToken = await TokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _forceLogout();
      return handler.next(err);
    }

    try {
      // Usar un Dio limpio (sin interceptores) para evitar loops
      final freshDio = Dio(BaseOptions(baseUrl: _dio.options.baseUrl));
      final response = await freshDio.post(
        ApiConstants.refreshEndpoint,
        data: {'refresh': refreshToken},
      );

      final newAccessToken = response.data['access'] as String;
      await TokenStorage.saveToken(newAccessToken);

      // Reintentar la petición original con el nuevo token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccessToken';
      final retryResponse = await freshDio.fetch(opts);
      return handler.resolve(retryResponse);
    } catch (_) {
      // El refresh token también expiró
      await _forceLogout();
      return handler.next(err);
    }
  }

  /// Limpia tokens y muestra diálogo para volver a iniciar sesión
  Future<void> _forceLogout() async {
    await TokenStorage.clearAuth();

    final context = navigatorKey.currentContext;
    if (context != null) {
      // Verificar que no haya ya un diálogo abierto
      if (ModalRoute.of(context)?.isCurrent == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Sesión expirada'),
            content: const Text(
              'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Navegar al inicio eliminando todo el stack
                  navigatorKey.currentState?.pushNamedAndRemoveUntil(
                    '/',
                    (_) => false,
                  );
                },
                child: const Text('Iniciar sesión'),
              ),
            ],
          ),
        );
      }
    }
  }
}
