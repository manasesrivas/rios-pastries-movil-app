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
        id: _nullableInt(venueData['id']),
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

class Reservation {
  final int id;
  final int? cliente;
  final DateTime fechaEvento;
  final int cantidadPersonas;
  final int sala;
  final String estado;
  final String hallName;
  final String venueName;
  final String venueAdress;
  final HallModel? hall;
  final VenueModel? venue;
  final double totalProductos;
  final List<ReservationItem> items;

  const Reservation({
    required this.id,
    this.cliente,
    required this.fechaEvento,
    required this.cantidadPersonas,
    required this.sala,
    this.estado = 'CONFIRMADA',
    this.hallName = '',
    this.venueName = '',
    this.venueAdress = '',
    this.hall,
    this.venue,
    this.totalProductos = 0,
    this.items = const [],
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final eventDate = DateTime.tryParse(json['fecha_evento']?.toString() ?? '');
    if (eventDate == null) {
      throw const FormatException(
        'La fecha_evento de la reservación no tiene un formato válido.',
      );
    }

    final hallData = _nestedMap(json['hall']);
    final venueData = _nestedMap(json['venue']);
    final rawHallId = json['sala'] ?? json['sala_id'];
    final hallId = rawHallId is Map ? rawHallId['id'] : rawHallId;
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const FormatException(
        'La lista de productos de la reservación no es válida.',
      );
    }

    return Reservation(
      id: _requiredInt(json['id'], 'id'),
      cliente: _nullableInt(json['cliente']),
      fechaEvento: eventDate,
      cantidadPersonas: _requiredInt(
        json['cantidad_personas'],
        'cantidad_personas',
      ),
      sala: _requiredInt(hallId, 'sala'),
      estado: _nullableString(json['estado']) ?? 'CONFIRMADA',
      hallName: _firstValue([
        json['hallName'],
        hallData['hallName'],
        hallData['hall_name'],
        hallData['name'],
      ]),
      venueName: _firstValue([
        json['venueName'],
        venueData['venueName'],
        venueData['name'],
      ]),
      venueAdress: _firstValue([
        json['venueAdress'],
        json['venueAddress'],
        venueData['address'],
      ]),
      hall: json['hall'] == null ? null : HallModel.fromJson(hallData),
      venue: json['venue'] == null ? null : VenueModel.fromJson(venueData),
      totalProductos: _nullableDouble(json['total_productos']) ?? 0,
      items: (rawItems as List<dynamic>? ?? [])
          .map((item) {
            if (item is! Map) {
              throw const FormatException(
                'El servidor devolvió un producto de reservación inválido.',
              );
            }
            return ReservationItem.fromJson(item.cast<String, dynamic>());
          })
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente': cliente,
      'fecha_evento':
          '${fechaEvento.year.toString().padLeft(4, '0')}-'
          '${fechaEvento.month.toString().padLeft(2, '0')}-'
          '${fechaEvento.day.toString().padLeft(2, '0')}',
      'cantidad_personas': cantidadPersonas,
      'sala': sala,
      'estado': estado,
      'hallName': hallName,
      'venueName': venueName,
      'venueAdress': venueAdress,
      'hall': hall?.toJson(),
      'venue': venue?.toJson(),
      'total_productos': totalProductos.toStringAsFixed(2),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class ReservationItem {
  final int productId;
  final String name;
  final int quantity;
  final double? price;
  final double? subtotal;

  const ReservationItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.price,
    this.subtotal,
  });

  factory ReservationItem.fromJson(Map<String, dynamic> json) {
    return ReservationItem(
      productId: _requiredInt(json['product'] ?? json['product_id'], 'product'),
      name: _nullableString(json['name']) ?? '',
      quantity: _requiredInt(json['quantity'], 'quantity'),
      price: _nullableDouble(json['price']),
      subtotal: _nullableDouble(json['subtotal']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product': productId,
      'name': name,
      'quantity': quantity,
      'price': price?.toStringAsFixed(2),
      'subtotal': subtotal?.toStringAsFixed(2),
    };
  }
}

class HallModel {
  final int? id;
  final String venueName;
  final VenueModel? venue;
  final String hallName;
  final String? image;
  final int? capacity;
  final double? price;
  final String? status;
  final List<DateTime>? reservedDates;

  const HallModel({
    this.id,
    this.venueName = '',
    this.venue,
    required this.hallName,
    this.image,
    this.capacity,
    this.price,
    this.status,
    this.reservedDates,
  });

  String get name => hallName;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venueName': venueName,
      if (venue != null) 'venue': venue!.toJson(),
      'name': hallName,
      'image': image,
      'capacity': capacity,
      'price': price?.toStringAsFixed(2),
      'status': status,
      if (reservedDates != null)
        'reservedDates': reservedDates!
            .map((date) => date.toIso8601String().substring(0, 10))
            .toList(),
    };
  }

  factory HallModel.fromJson(Map<String, dynamic> json) {
    final rawVenue = json['venue'];
    if (rawVenue != null && rawVenue is! Map) {
      throw const FormatException('El local de la sala no es válido.');
    }
    final venue = rawVenue == null
        ? null
        : VenueModel.fromJson(rawVenue.cast<String, dynamic>());
    return HallModel(
      id: _nullableInt(json['id']),
      venueName: _firstValue([
        json['venueName'],
        json['venue_name'],
        venue?.name,
      ]),
      venue: venue,
      hallName: _firstValue([
        json['hallName'],
        json['hall_name'],
        json['name'],
      ]),
      image: _nullableString(json['image']),
      capacity: _nullableInt(json['capacity']),
      price: _nullableDouble(json['price']),
      status: _nullableString(json['status']),
      reservedDates: _reservedDatesFromJson(json['reservedDates']),
    );
  }
}

List<DateTime>? _reservedDatesFromJson(dynamic value) {
  if (value == null) return null;
  if (value is! List) {
    throw const FormatException('Las fechas reservadas de la sala no son válidas.');
  }
  final dates = <DateTime>[];
  for (final item in value) {
    if (item is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(item)) {
      throw const FormatException('Una fecha reservada de la sala no es válida.');
    }
    final date = DateTime.tryParse(item);
    if (date == null ||
        date.year < 1 ||
        date.toIso8601String().substring(0, 10) != item) {
      throw const FormatException('Una fecha reservada de la sala no es válida.');
    }
    dates.add(date);
  }
  return List.unmodifiable(dates);
}

class VenueModel {
  final int? id;
  final String name;
  final String address;
  final String descripcion;
  final String? status;

  const VenueModel({
    this.id,
    required this.name,
    required this.address,
    required this.descripcion,
    this.status,
  });

  String get venueName => name;

  factory VenueModel.fromJson(Map<String, dynamic> json) {
    return VenueModel(
      id: _nullableInt(json['id']),
      name: _firstValue([json['name'], json['venueName']]),
      address: _firstValue([json['address'], json['venueAddress']]),
      descripcion: _firstValue([json['descripcion'], json['description']]),
      status: _nullableString(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'address': address,
      'descripcion': descripcion,
      'status': status,
    };
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
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

double? _nullableDouble(dynamic value) {
  final parsed = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
  return parsed != null && parsed.isFinite ? parsed : null;
}

String? _nullableString(dynamic value) => value?.toString();

String _firstValue(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return '';
}
