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

  test('parses product fields used by the reservation selector', () {
    final product = ProductModel.fromJson({
      'id': 5.0,
      'name': 'Pastel',
      'price': 25,
      'available': false,
    });

    expect(product.id, 5);
    expect(product.name, 'Pastel');
    expect(product.price, '25');
    expect(product.available, isFalse);
  });
}
