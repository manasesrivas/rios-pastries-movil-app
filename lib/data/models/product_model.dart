
class ProductModel {
  final int id;
  final String name;
  final String? image;
  final String description;
  final String price;
  final String category;
  final bool available;
  final String status;

  ProductModel({
    required this.id,
    required this.name,
    required this.image,
    required this.description,
    required this.price,
    required this.category,
    required this.available,
    required this.status,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final id = _productId(json['id']);
    if (id == null) {
      throw const FormatException('El producto recibido no tiene un ID válido.');
    }

    return ProductModel(
      id: id,
      name: json['name']?.toString() ?? '',
      image: json['image']?.toString(),
      description: json['description']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      available: _productAvailability(json['available']),
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'image': image,
      'description': description,
      'price': price,
      'category': category,
      'available': available,
      'status': status,
    };
  }
}

int? _productId(dynamic value) {
  if (value is int) return value;
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool _productAvailability(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  return value?.toString().toLowerCase() == 'true';
}
