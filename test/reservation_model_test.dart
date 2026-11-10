import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';

void main() {
  test('parses the reservation response with flattened hall and venue data', () {
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
  });

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
