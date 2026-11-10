class CartItem {
  final int id;
  final int userId;
  final int productId;
  final String name;
  final String price;
  final String? image;
  final int quantity;
  final bool isAvailable;
  final String? availabilityCode;
  final DateTime createdAt;

  const CartItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    required this.quantity,
    required this.isAvailable,
    this.availabilityCode,
    required this.createdAt,
  });

  factory CartItem.fromMap(Map<String, Object?> map) {
    return CartItem(
      id: map['id'] as int,
      userId: map['user_id'] as int,
      productId: map['product_id'] as int,
      name: map['name'] as String,
      price: map['price'] as String,
      image: map['image'] as String?,
      quantity: map['quantity'] as int,
      isAvailable: (map['is_available'] as int) == 1,
      availabilityCode: map['availability_code'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  int get unitPriceCents {
    final amount = double.tryParse(price);
    if (amount == null || !amount.isFinite || amount < 0) {
      throw FormatException('Precio inválido para $name: $price');
    }
    return (amount * 100).round();
  }

  CartItem copyWith({
    int? quantity,
    bool? isAvailable,
    String? availabilityCode,
    bool clearAvailabilityCode = false,
  }) {
    return CartItem(
      id: id,
      userId: userId,
      productId: productId,
      name: name,
      price: price,
      image: image,
      quantity: quantity ?? this.quantity,
      isAvailable: isAvailable ?? this.isAvailable,
      availabilityCode: clearAvailabilityCode
          ? null
          : availabilityCode ?? this.availabilityCode,
      createdAt: createdAt,
    );
  }
}
