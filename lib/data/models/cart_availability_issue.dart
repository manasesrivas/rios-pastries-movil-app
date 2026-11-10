class CartAvailabilityIssue {
  final int productId;
  final String code;
  final String message;

  const CartAvailabilityIssue({
    required this.productId,
    required this.code,
    required this.message,
  });

  factory CartAvailabilityIssue.fromJson(Map<String, dynamic> json) {
    final productId = _parseInt(json['product_id']);
    final code = json['code'];
    final message = json['message'];
    if (productId == null || code is! String || message is! String) {
      throw const FormatException('Error de disponibilidad inválido.');
    }

    return CartAvailabilityIssue(
      productId: productId,
      code: code,
      message: message,
    );
  }
}

class CartAvailabilityException implements Exception {
  final String code;
  final String message;
  final List<CartAvailabilityIssue> errors;

  const CartAvailabilityException({
    required this.code,
    required this.message,
    required this.errors,
  });

  @override
  String toString() {
    if (errors.isEmpty) return message;
    return '$message\n${errors.map((error) => error.message).join('\n')}';
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}
