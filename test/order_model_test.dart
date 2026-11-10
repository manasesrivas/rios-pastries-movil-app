import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/order_model.dart';

void main() {
  test('parses order fields and nested product details', () {
    final order = OrderModel.fromJson({
      'id': 11,
      'user': 6,
      'subtotal': '8.25',
      'total': '8.25',
      'fecha': '2026-11-08',
      'hora': '13:54:38.431512',
      'direccion': '',
      'metodo_pago': 'efectivo',
      'tipo_entrega': 'recoger',
      'status': 'pendiente',
      'details': [
        {
          'id': 20,
          'product_id': 7,
          'product_name': 'Horchata',
          'quantity': 1,
          'price': '1.50',
          'subtotal': '1.50',
          'status': 1,
        },
      ],
    });

    expect(order.id, 11);
    expect(order.user, 6);
    expect(order.details, hasLength(1));
    expect(order.details.first.productName, 'Horchata');
    expect(order.details.first.subtotal, '1.50');
  });
}
