import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_api_error.dart';
import 'package:rios_pastries/data/models/reservation_create_request.dart';
import 'package:rios_pastries/data/services/halls_service.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';

void main() {
  test('HallsService requests and parses the hall API response', () async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {
            'id': 1,
            'venueName': 'Local #1',
            'venue': {
              'id': 1,
              'name': 'Local #1',
              'address': 'San Miguel Centro, San Miguel',
              'descripcion': 'descripcion',
              'status': 'activo',
            },
            'name': 'Sala #1',
            'image': null,
            'capacity': 100,
            'price': '100.00',
            'status': 'DISPONIBLE',
          },
        ],
      },
    ]);

    final halls = await HallsService(dio: _dioWithAdapter(adapter)).getHalls();

    expect(adapter.requests.single.uri.path, '/api/halls/');
    expect(halls.single.toJson(), {
      'id': 1,
      'venueName': 'Local #1',
      'venue': {
        'id': 1,
        'name': 'Local #1',
        'address': 'San Miguel Centro, San Miguel',
        'descripcion': 'descripcion',
        'status': 'activo',
      },
      'name': 'Sala #1',
      'image': null,
      'capacity': 100,
      'price': '100.00',
      'status': 'DISPONIBLE',
    });
  });

  test('loads halls and parses a paginated response', () async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': {
          'results': [
            {'id': 4, 'name': 'Sala principal'},
          ],
        },
      },
    ]);
    final service = ReservationService(dio: _dioWithAdapter(adapter));

    final halls = await service.getHalls();

    expect(adapter.requests.single.uri.path, '/api/halls/');
    expect(halls.single.id, 4);
    expect(halls.single.hallName, 'Sala principal');
  });

  test('creates and updates reservations with the API payload', () async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 201,
        'data': _reservationResponse(items: []),
      },
      {
        'statusCode': 200,
        'data': _reservationResponse(items: []),
      },
    ]);
    final service = ReservationService(dio: _dioWithAdapter(adapter));
    final request = ReservationCreateRequest(
      fechaEvento: DateTime(2026, 11, 27),
      cantidadPersonas: 3,
      sala: 4,
    );

    final reservation = await service.createReservation(request);
    await service.updateReservation(id: 12, request: request);

    expect(adapter.requests.map((request) => request.method), [
      'POST',
      'PATCH',
    ]);
    expect(adapter.requests.map((request) => request.uri.path), [
      '/api/reservations/',
      '/api/reservations/12/',
    ]);
    expect(reservation.id, 12);
    for (final request in adapter.requests) {
      expect(_requestData(request), {
        'fecha_evento': '2026-11-27',
        'cantidad_personas': 3,
        'sala': 4,
      });
    }
  });

  test('throws a typed error for HTTP 400 reservation errors', () async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 400,
        'data': {
          'fecha_evento': ['Fecha ocupada.'],
          'items': [
            {
              'product_id': 3,
              'name': 'Pastel',
              'error': 'No disponible.',
            },
          ],
        },
      },
    ]);
    final service = ReservationService(dio: _dioWithAdapter(adapter));
    final request = ReservationCreateRequest(
      fechaEvento: DateTime(2026, 11, 27),
      cantidadPersonas: 3,
      sala: 4,
    );

    await expectLater(
      service.createReservation(request),
      throwsA(
        isA<ReservationApiException>().having(
          (error) => error.error.fieldErrors['fecha_evento'],
          'errores de fecha',
          ['Fecha ocupada.'],
        ),
      ),
    );
  });

  test('requests the configured endpoint and parses reservations', () async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {
            'id': 11,
            'fecha_evento': '2026-11-27',
            'cantidad_personas': 3,
            'estado': 'CONFIRMADA',
            'hallName': 'Sala #1',
            'venueName': 'Local #1',
            'venueAddress': 'San Miguel Centro, San Miguel',
            'hall': null,
            'venue': null,
          },
        ],
      },
    ]);
    final reservations = await ReservationService(dio: _dioWithAdapter(adapter))
        .getReservations();

    expect(adapter.requests.single.uri.path, '/api/reservations/');
    expect(reservations, hasLength(1));
    expect(reservations.single.hall.hallName, 'Sala #1');
    expect(reservations.single.venue.address, 'San Miguel Centro, San Miguel');
  });
}

Map<String, dynamic> _reservationResponse({
  required List<Map<String, dynamic>> items,
}) {
  return {
    'id': 12,
    'cliente': 4,
    'fecha_evento': '2026-11-27',
    'cantidad_personas': 3,
    'sala': 4,
    'estado': 'CONFIRMADA',
    'hallName': 'Sala #1',
    'venueName': 'Local #1',
    'venueAdress': 'Centro',
    'hall': null,
    'venue': null,
    'total_productos': '0.00',
    'items': items,
  };
}

Dio _dioWithAdapter(_ReservationAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test/api/',
      validateStatus: (status) => status != null && status < 300,
    ),
  )..httpClientAdapter = adapter;
}

Map<String, dynamic> _requestData(RequestOptions request) {
  final data = request.data;
  if (data is Map<String, dynamic>) return data;
  if (data is String) return jsonDecode(data) as Map<String, dynamic>;
  throw FormatException(
    'Tipo de payload de prueba inesperado: ${data.runtimeType}',
  );
}

class _ReservationAdapter implements HttpClientAdapter {
  _ReservationAdapter(this._responses);

  final List<Map<String, dynamic>> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response['data']),
      response['statusCode'] as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
