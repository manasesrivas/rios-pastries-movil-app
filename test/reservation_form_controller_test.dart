import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';
import 'package:rios_pastries/presentation/controllers/reservation_form_controller.dart';

void main() {
  test(
    'maps backend validation errors and active reservation conflicts',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'))
        ..httpClientAdapter = _ErrorAdapter({
          'fecha_evento': ['La fecha no puede estar vacía.'],
          'cantidad_personas': ['Debe ser un entero positivo.'],
          'sala': ['The fields sala and fecha_evento must make a unique set.'],
          'non_field_errors': ['No se pudo completar la reservación.'],
        });
      final controller = ReservationFormController(
        reservationService: ReservationService(dio: dio),
      );

      final saved = await controller.save(
        Reservation(
          fechaEvento: DateTime(2026, 11, 27),
          cantidadPersonas: 3,
          sala: 4,
        ),
      );

      expect(saved, isFalse);
      expect(
        controller.fieldErrors['fecha_evento'],
        'La fecha no puede estar vacía.',
      );
      expect(
        controller.fieldErrors['cantidad_personas'],
        'Debe ser un entero positivo.',
      );
      expect(
        controller.fieldErrors['sala'],
        'Esta sala ya tiene una reservación activa para esa fecha.',
      );
      expect(controller.errorMessage, 'No se pudo completar la reservación.');

      controller.clearFieldError('fecha_evento');
      expect(controller.fieldErrors.containsKey('fecha_evento'), isFalse);
      controller.dispose();
    },
  );
}

class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter(this._data);

  final Map<String, dynamic> _data;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(_data),
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
