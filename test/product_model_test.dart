import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/product_model.dart';

void main() {
  test('parses a numeric category as a string', () {
    final product = ProductModel.fromJson({
      'id': 1,
      'name': 'Pastel',
      'image': null,
      'description': 'Descripción',
      'price': '12.50',
      'category': 3,
      'available': true,
      'status': 'activo',
    });

    expect(product.category, '3');
  });
}
