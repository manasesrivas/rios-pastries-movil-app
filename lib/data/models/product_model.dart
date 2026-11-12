
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
    return ProductModel(
      id: json['id'],
      name: json['name'] ?? '',
      image: json['image'] ?? '',
      description: json['description'] ?? '',
      price: json['price'],
      category: json['category']?.toString() ?? '',
      available: json['available'],
      status: json['status'] ?? '',
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
