import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';
import 'package:rios_pastries/presentation/screens/reservations/reservation_create_page.dart';

void main() {
  testWidgets('rejects zero attendees before sending a reservation', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ReservationCreatePage(
          reservationService: ReservationService(dio: _dioWithAdapter(adapter)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), '0');
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();

    expect(find.text('La cantidad debe ser mayor que cero.'), findsOneWidget);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'GET');
  });

  testWidgets('allows saving an unchanged past date when editing', (
    tester,
  ) async {
    final adapter = _ReservationAdapter([
      {
        'statusCode': 200,
        'data': [
          {'id': 4, 'name': 'Sala principal'},
        ],
      },
      {
        'statusCode': 200,
        'data': {'id': 12},
      },
    ]);
    final reservation = Reservation(
      id: 12,
      fechaEvento: DateTime(2020, 1, 2),
      cantidadPersonas: 3,
      sala: 4,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReservationCreatePage(
                      reservation: reservation,
                      reservationService: ReservationService(
                        dio: _dioWithAdapter(adapter),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar reservación'));
    await tester.pumpAndSettle();

    expect(adapter.requests.map((request) => request.method), ['GET', 'PATCH']);
    expect(adapter.requests.last.uri.path, '/api/reservations/12/');
  });
}

Dio _dioWithAdapter(_ReservationAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test/api/',
      validateStatus: (status) => status != null && status < 300,
    ),
  )..httpClientAdapter = adapter;
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
