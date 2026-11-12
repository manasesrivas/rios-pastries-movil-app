class ReservationItemInput {
  final int productId;
  final int quantity;

  const ReservationItemInput({
    required this.productId,
    required this.quantity,
  });

  Map<String, dynamic> toJson() => {
    'product_id': productId,
    'quantity': quantity,
  };
}

class ReservationCreateRequest {
  final DateTime fechaEvento;
  final int cantidadPersonas;
  final int sala;
  final List<ReservationItemInput> items;

  const ReservationCreateRequest({
    required this.fechaEvento,
    required this.cantidadPersonas,
    required this.sala,
    this.items = const [],
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'fecha_evento':
          '${fechaEvento.year.toString().padLeft(4, '0')}-'
          '${fechaEvento.month.toString().padLeft(2, '0')}-'
          '${fechaEvento.day.toString().padLeft(2, '0')}',
      'cantidad_personas': cantidadPersonas,
      'sala': sala,
    };

    if (items.isNotEmpty) {
      json['items'] = items.map((item) => item.toJson()).toList();
    }

    return json;
  }
}
