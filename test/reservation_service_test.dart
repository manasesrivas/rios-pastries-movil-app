import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';

void main() {
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
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.test/api/',
        validateStatus: (status) => status != null && status < 500,
      ),
    )..httpClientAdapter = adapter;

    final reservations = await ReservationService(dio: dio).getReservations();

    expect(adapter.requests.single.uri.path, '/api/reservations/');
    expect(reservations, hasLength(1));
    expect(reservations.single.hall.hallName, 'Sala #1');
    expect(reservations.single.venue.address, 'San Miguel Centro, San Miguel');
  });
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
