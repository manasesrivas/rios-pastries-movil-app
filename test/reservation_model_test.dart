import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_api_error.dart';
import 'package:rios_pastries/data/models/reservation_create_request.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';

void main() {
  test('parses and serializes the nested venue returned with a hall', () {
    final hall = HallModel.fromJson({
      'id': 1,
      'venue': {
        'id': 2,
        'name': 'Local #1',
        'address': 'San Miguel Centro, San Miguel',
        'descripcion': 'Descripción del local',
        'status': 'activo',
      },
      'name': 'Sala #1',
      'capacity': 100,
      'price': '100.00',
      'status': 'DISPONIBLE',
    });

    expect(hall.venueName, 'Local #1');
    expect(hall.venue?.id, 2);
    expect(hall.venue?.address, 'San Miguel Centro, San Miguel');
    expect(hall.venue?.descripcion, 'Descripción del local');
    expect(hall.venue?.status, 'activo');
    expect(hall.toJson()['venue'], {
      'id': 2,
      'name': 'Local #1',
      'address': 'San Miguel Centro, San Miguel',
      'descripcion': 'Descripción del local',
      'status': 'activo',
    });
    expect(
      () => HallModel.fromJson({'name': 'Sala', 'venue': 'invalid'}),
      throwsFormatException,
    );
  });

  test('parses and serializes the hall API response', () {
    final hall = HallModel.fromJson({
      'id': 1,
      'venueName': 'Local #1',
      'name': 'Sala #1',
      'image': null,
      'capacity': 100,
      'price': '100.00',
      'status': 'DISPONIBLE',
    });

    expect(hall.id, 1);
    expect(hall.venueName, 'Local #1');
    expect(hall.hallName, 'Sala #1');
    expect(hall.image, isNull);
    expect(hall.capacity, 100);
    expect(hall.price, 100);
    expect(hall.status, 'DISPONIBLE');
    expect(hall.toJson(), {
      'id': 1,
      'venueName': 'Local #1',
      'name': 'Sala #1',
      'image': null,
      'capacity': 100,
      'price': '100.00',
      'status': 'DISPONIBLE',
    });
  });

  test('omits empty items from the create request', () {
    final request = ReservationCreateRequest(
      fechaEvento: DateTime(2026, 11, 27),
      cantidadPersonas: 3,
      sala: 4,
    );

    expect(request.toJson(), {
      'fecha_evento': '2026-11-27',
      'cantidad_personas': 3,
      'sala': 4,
    });
  });

  test('serializes attached items with integer IDs and quantities', () {
    final request = ReservationCreateRequest(
      fechaEvento: DateTime(2026, 12, 20),
      cantidadPersonas: 50,
      sala: 3,
      items: const [
        ReservationItemInput(productId: 1, quantity: 2),
        ReservationItemInput(productId: 5, quantity: 1),
      ],
    );

    expect(request.toJson(), {
      'fecha_evento': '2026-12-20',
      'cantidad_personas': 50,
      'sala': 3,
      'items': [
        {'product_id': 1, 'quantity': 2},
        {'product_id': 5, 'quantity': 1},
      ],
    });
  });

  test('parses a reservation with null halls and empty products', () {
    final reservation = Reservation.fromJson({
      'id': 11,
      'cliente': 4,
      'fecha_evento': '2026-12-20',
      'cantidad_personas': 50,
      'sala': 3,
      'estado': 'CONFIRMADA',
      'hallName': 'Sala #1',
      'venueName': 'Local #1',
      'venueAdress': 'Centro',
      'hall': null,
      'venue': null,
      'total_productos': '0.00',
      'items': [],
    });

    expect(reservation.id, 11);
    expect(reservation.cliente, 4);
    expect(reservation.sala, 3);
    expect(reservation.hall, isNull);
    expect(reservation.venue, isNull);
    expect(reservation.venueAdress, 'Centro');
    expect(reservation.totalProductos, 0);
    expect(reservation.items, isEmpty);
    expect(reservation.toJson()['items'], isEmpty);
  });

  test('parses numeric totals and reservation item prices', () {
    final reservation = Reservation.fromJson({
      'id': 12,
      'fecha_evento': '2026-12-20',
      'cantidad_personas': 50,
      'sala': 3,
      'total_productos': 150,
      'items': [
        {
          'product': 1,
          'name': 'Pastel',
          'quantity': 2,
          'price': '25.00',
          'subtotal': 50,
        },
      ],
    });

    expect(reservation.totalProductos, 150);
    expect(reservation.items.single.productId, 1);
    expect(reservation.items.single.quantity, 2);
    expect(reservation.items.single.price, 25);
    expect(reservation.items.single.subtotal, 50);
  });

  test('parses field, general, and multiple product API errors', () {
    final error = ReservationApiError.fromJson({
      'fecha_evento': ['Fecha ocupada.'],
      'cantidad_personas': ['Cantidad inválida.'],
      'non_field_errors': ['No se pudo crear.'],
      'items': [
        {'product_id': 3, 'name': 'Pastel', 'error': 'No disponible.'},
        {'product_id': 7, 'name': 'Mesa', 'error': 'No existe.'},
        'Error general de productos.',
      ],
    });

    expect(error.fieldErrors['fecha_evento'], ['Fecha ocupada.']);
    expect(error.fieldErrors['cantidad_personas'], ['Cantidad inválida.']);
    expect(error.nonFieldErrors, ['No se pudo crear.']);
    expect(error.itemErrors, hasLength(3));
    expect(error.itemErrors.first.productId, 3);
    expect(error.itemErrors[1].productId, 7);
    expect(error.itemErrors.last.error, 'Error general de productos.');
  });

  test('parses flattened reservation response fields', () {
    final reservation = Reservation.fromJson({
      'id': 13,
      'fecha_evento': '2026-12-20',
      'cantidad_personas': 50,
      'sala': 3,
      'hallName': 'Sala #1',
      'venueName': 'Local #1',
      'venueAdress': 'Centro',
      'hall': null,
      'venue': null,
      'total_productos': 0,
    });

    expect(reservation.hallName, 'Sala #1');
    expect(reservation.venueName, 'Local #1');
    expect(reservation.venueAdress, 'Centro');
    expect(reservation.totalProductos, 0);
  });

  test('parses reservation identifiers, state, and read-only total', () {
    final reservation = ReservationModel.fromJson({
      'id': 11,
      'fecha_evento': '2026-11-27',
      'cantidad_personas': 3,
      'sala': {'id': 4},
      'estado': 'CANCELADA',
      'total_productos': '125.50',
      'items': [],
    });

    expect(reservation.id, 11);
    expect(reservation.salaId, 4);
    expect(reservation.estado, 'CANCELADA');
    expect(reservation.totalProductos, 125.5);
  });

  test(
    'parses the reservation response with flattened hall and venue data',
    () {
      final reservation = ReservationModel.fromJson({
        'id': 11,
        'cliente': 9,
        'fecha_evento': '2026-11-27',
        'cantidad_personas': 3,
        'sala': 1,
        'estado': 'CONFIRMADA',
        'hallName': 'Sala #1',
        'venueName': 'Local #1',
        'venueAddress': 'San Miguel Centro, San Miguel',
        'hall': null,
        'venue': null,
      });

      expect(reservation.id, 11);
      expect(reservation.fechaEvento, DateTime(2026, 11, 27));
      expect(reservation.cantidadPersonas, 3);
      expect(reservation.estado, 'CONFIRMADA');
      expect(reservation.hall.hallName, 'Sala #1');
      expect(reservation.venue.name, 'Local #1');
      expect(reservation.venue.venueName, 'Local #1');
      expect(reservation.venue.address, 'San Miguel Centro, San Miguel');
      expect(reservation.hall.capacity, isNull);
      expect(reservation.venue.status, isNull);
    },
  );

  test('parses hall and venue detail when nested objects are available', () {
    final reservation = ReservationModel.fromJson({
      'id': 12,
      'fecha_evento': '2026-12-01',
      'cantidad_personas': '15',
      'estado': 'PENDIENTE',
      'hall': {
        'name': 'Salón principal',
        'image': 'hall.jpg',
        'capacity': 40,
        'price': '125.50',
        'status': 'ACTIVA',
      },
      'venue': {
        'name': 'Local central',
        'address': 'Centro',
        'descripcion': 'Salón para eventos',
        'status': 'ACTIVO',
      },
    });

    expect(reservation.hall.hallName, 'Salón principal');
    expect(reservation.hall.image, 'hall.jpg');
    expect(reservation.hall.capacity, 40);
    expect(reservation.hall.price, 125.5);
    expect(reservation.venue.name, 'Local central');
    expect(reservation.venue.address, 'Centro');
    expect(reservation.venue.descripcion, 'Salón para eventos');
  });
}
