import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';
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
        'data': {'id': 12},
      },
      {
        'statusCode': 200,
        'data': {'id': 12},
      },
    ]);
    final service = ReservationService(dio: _dioWithAdapter(adapter));
    final reservation = Reservation(
      id: 12,
      fechaEvento: DateTime(2026, 11, 27),
      cantidadPersonas: 3,
      sala: 4,
    );

    await service.createReservation(reservation);
    await service.updateReservation(id: 12, reservation: reservation);

    expect(adapter.requests.map((request) => request.method), [
      'POST',
      'PATCH',
    ]);
    expect(adapter.requests.map((request) => request.uri.path), [
      '/api/reservations/',
      '/api/reservations/12/',
    ]);
    for (final request in adapter.requests) {
      expect(_requestData(request), {
        'fecha_evento': '2026-11-27',
        'cantidad_personas': 3,
        'sala': 4,
        'estado': 'CONFIRMADA',
      });
    }
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

Dio _dioWithAdapter(_ReservationAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test/api/',
      validateStatus: (status) => status != null && status < 500,
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
