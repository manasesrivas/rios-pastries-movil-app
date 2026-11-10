class OrderModel {
  final int? id;
  final int? user;
  final String subtotal;
  final String total;
  final String fecha;
  final String hora;
  final String direccion;
  final String metodoPago;
  final String tipoEntrega;
  final String status;
  final List<OrderDetailModel> details;

  OrderModel({
    this.id,
    this.user,
    required this.subtotal,
    required this.total,
    required this.fecha,
    required this.hora,
    required this.direccion,
    required this.metodoPago,
    required this.tipoEntrega,
    required this.status,
    this.details = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: _toInt(json['id']),
      user: _toInt(json['user']),
      subtotal: json['subtotal']?.toString() ?? '0.00',
      total: json['total']?.toString() ?? '0.00',
      fecha: json['fecha']?.toString() ?? '',
      hora: json['hora']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      metodoPago: json['metodo_pago']?.toString() ?? '',
      tipoEntrega: json['tipo_entrega']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      details: (json['details'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OrderDetailModel.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subtotal': subtotal,
      'total': total,
      'fecha': fecha,
      'hora': hora,
      'direccion': direccion,
      'metodo_pago': metodoPago,
      'tipo_entrega': tipoEntrega,
      'status': status,
      'details': details.map((detail) => detail.toJson()).toList(),
    };
  }
}

class OrderDetailModel {
  final int? id;
  final int? productId;
  final String productName;
  final int quantity;
  final String price;
  final String subtotal;
  final int? status;

  const OrderDetailModel({
    this.id,
    this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.status,
  });

  factory OrderDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderDetailModel(
      id: _toInt(json['id']),
      productId: _toInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      quantity: _toInt(json['quantity']) ?? 0,
      price: json['price']?.toString() ?? '0.00',
      subtotal: json['subtotal']?.toString() ?? '0.00',
      status: _toInt(json['status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'status': status,
    };
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}