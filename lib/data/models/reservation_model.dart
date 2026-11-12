enum ReservationStatus {
  pendiente('PENDIENTE'),
  confirmada('CONFIRMADA'),
  cancelada('CANCELADA'),
  finalizada('FINALIZADA'),
  eliminada('ELIMINADA');

  const ReservationStatus(this.apiValue);

  final String apiValue;

  static ReservationStatus fromApiValue(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return ReservationStatus.values.firstWhere(
      (status) => status.apiValue == normalized,
      orElse: () => throw FormatException(
        'Estado de reservación no reconocido: $value.',
      ),
    );
  }
}

class Reservation {
  final int? id;
  final DateTime fechaEvento;
  final int cantidadPersonas;
  final int sala;
  final ReservationStatus estado;
  final double? totalProductos;

  const Reservation({
    this.id,
    required this.fechaEvento,
    required this.cantidadPersonas,
    required this.sala,
    this.estado = ReservationStatus.confirmada,
    this.totalProductos,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final eventDate = DateTime.tryParse(json['fecha_evento']?.toString() ?? '');
    if (eventDate == null) {
      throw const FormatException(
        'La fecha_evento de la reservación no tiene un formato válido.',
      );
    }

    final rawHall = json['sala'] ?? json['sala_id'] ?? json['hall'];
    final hallId = rawHall is Map ? rawHall['id'] : rawHall;
    final status = json['estado'];

    return Reservation(
      id: _nullableInt(json['id']),
      fechaEvento: eventDate,
      cantidadPersonas: _requiredInt(
        json['cantidad_personas'],
        'cantidad_personas',
      ),
      sala: _requiredInt(hallId, 'sala'),
      estado: status == null
          ? ReservationStatus.confirmada
          : ReservationStatus.fromApiValue(status),
      totalProductos: _nullableDouble(json['total_productos']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fecha_evento':
          '${fechaEvento.year.toString().padLeft(4, '0')}-'
          '${fechaEvento.month.toString().padLeft(2, '0')}-'
          '${fechaEvento.day.toString().padLeft(2, '0')}',
      'cantidad_personas': cantidadPersonas,
      'sala': sala,
      'estado': estado.apiValue,
    };
  }
}

class ReservationModel {
  final int id;
  final DateTime fechaEvento;
  final int cantidadPersonas;
  final int? salaId;
  final String estado;
  final HallModel hall;
  final VenueModel venue;
  final double? totalProductos;

  const ReservationModel({
    required this.id,
    required this.fechaEvento,
    required this.cantidadPersonas,
    this.salaId,
    required this.estado,
    required this.hall,
    required this.venue,
    this.totalProductos,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final hallData = _nestedMap(json['hall']);
    final venueData = _nestedMap(json['venue']);
    final rawHall = json['sala'] ?? json['sala_id'] ?? json['hall'];
    final eventDate = DateTime.tryParse(json['fecha_evento']?.toString() ?? '');
    if (eventDate == null) {
      throw const FormatException(
        'La fecha_evento de la reservación no tiene un formato válido.',
      );
    }

    return ReservationModel(
      id: _requiredInt(json['id'], 'id'),
      fechaEvento: eventDate,
      cantidadPersonas: _requiredInt(
        json['cantidad_personas'],
        'cantidad_personas',
      ),
      salaId: _nullableInt(
        rawHall is Map ? rawHall['id'] : rawHall,
      ) ?? _nullableInt(hallData['id']),
      estado: json['estado']?.toString() ?? '',
      hall: HallModel(
        id: _nullableInt(rawHall is Map ? rawHall['id'] : rawHall) ??
            _nullableInt(hallData['id']),
        hallName: _firstValue([
          hallData['hallName'],
          hallData['hall_name'],
          hallData['name'],
          json['hallName'],
          json['hall_name'],
        ]),
        image: _nullableString(hallData['image'] ?? json['hallImage']),
        capacity: _nullableInt(hallData['capacity'] ?? json['hallCapacity']),
        price: _nullableDouble(hallData['price'] ?? json['hallPrice']),
        status: _nullableString(hallData['status'] ?? json['hallStatus']),
      ),
      venue: VenueModel(
        name: _firstValue([
          venueData['name'],
          venueData['venueName'],
          json['venueName'],
        ]),
        address: _firstValue([venueData['address'], json['venueAddress']]),
        descripcion: _firstValue([
          venueData['descripcion'],
          venueData['description'],
          json['venueDescripcion'],
        ]),
        status: _nullableString(venueData['status'] ?? json['venueStatus']),
      ),
      totalProductos: _nullableDouble(json['total_productos']),
    );
  }
}

class HallModel {
  final int? id;
  final String venueName;
  final String hallName;
  final String? image;
  final int? capacity;
  final double? price;
  final String? status;

  const HallModel({
    this.id,
    this.venueName = '',
    required this.hallName,
    this.image,
    this.capacity,
    this.price,
    this.status,
  });

  String get name => hallName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venueName': venueName,
      'name': hallName,
      'image': image,
      'capacity': capacity,
      'price': price?.toStringAsFixed(2),
      'status': status,
    };
  }

  factory HallModel.fromJson(Map<String, dynamic> json) {
    return HallModel(
      id: _nullableInt(json['id']),
      venueName: _firstValue([json['venueName'], json['venue_name']]),
      hallName: _firstValue([
        json['hallName'],
        json['hall_name'],
        json['name'],
      ]),
      image: _nullableString(json['image']),
      capacity: _nullableInt(json['capacity']),
      price: _nullableDouble(json['price']),
      status: _nullableString(json['status']),
    );
  }
}

class VenueModel {
  final String name;
  final String address;
  final String descripcion;
  final String? status;

  const VenueModel({
    required this.name,
    required this.address,
    required this.descripcion,
    this.status,
  });

  String get venueName => name;

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      name: _firstValue([json['name'], json['venueName']]),
      address: _firstValue([json['address'], json['venueAddress']]),
      descripcion: _firstValue([json['descripcion'], json['description']]),
      status: _nullableString(json['status']),
    );
  }
}

typedef Hall = HallModel;
typedef Venue = VenueModel;

Map<String, dynamic> _nestedMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

int _requiredInt(dynamic value, String field) {
  final parsed = _nullableInt(value);
  if (parsed == null) {
    throw FormatException('El campo $field de la reservación no es válido.');
  }
  return parsed;
}

int? _nullableInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _nullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String? _nullableString(dynamic value) => value?.toString();

String _firstValue(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}
