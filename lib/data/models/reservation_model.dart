class ReservationModel {
  final int id;
  final DateTime fechaEvento;
  final int cantidadPersonas;
  final String estado;
  final HallModel hall;
  final VenueModel venue;

  const ReservationModel({
    required this.id,
    required this.fechaEvento,
    required this.cantidadPersonas,
    required this.estado,
    required this.hall,
    required this.venue,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final hallData = _nestedMap(json['hall']);
    final venueData = _nestedMap(json['venue']);
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
      estado: json['estado']?.toString() ?? '',
      hall: HallModel(
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
    );
  }
}

class HallModel {
  final String hallName;
  final String? image;
  final int? capacity;
  final double? price;
  final String? status;

  const HallModel({
    required this.hallName,
    this.image,
    this.capacity,
    this.price,
    this.status,
  });

  String get name => hallName;

  factory HallModel.fromJson(Map<String, dynamic> json) {
    return HallModel(
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
