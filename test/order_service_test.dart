import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/cart_availability_issue.dart';
import 'package:rios_pastries/data/models/cart_item.dart';
import 'package:rios_pastries/data/services/order_service.dart';

void main() {
  test('sends confirmed validation and order payloads', () async {
    final adapter = _QueueAdapter([
      {
        'statusCode': 200,
        'data': {
          'code': 'CART_VALID',
          'message': 'Todos los productos están disponibles.',
          'valid': true,
        },
      },
      {
        'statusCode': 201,
        'data': {
          'id': 42,
          'subtotal': '3.00',
          'total': '3.00',
          'fecha': '2026-11-09',
          'hora': '10:00:00',
          'direccion': '',
          'metodo_pago': 'tarjeta',
          'tipo_entrega': 'recoger',
          'status': 'pendiente',
        },
      },
    ]);
    final service = OrderService(dio: _dio(adapter));
    final items = [_item(productId: 5, quantity: 2)];

    await service.validateAvailability(items);
    final order = await service.createOrder(
      items: items,
      paymentMethod: 'tarjeta',
      deliveryType: 'recoger',
    );

    expect(order.id, 42);
    expect(adapter.requests[0].uri.path, '/api/orders/validate/');
    expect(adapter.requests[0].data, {
      'items': [
        {'product_id': 5, 'quantity': 2},
      ],
    });
    expect(adapter.requests[1].uri.path, '/api/orders/');
    expect(adapter.requests[1].data, {
      'items': [
        {'product_id': 5, 'quantity': 2},
      ],
      'metodo_pago': 'tarjeta',
      'tipo_entrega': 'recoger',
    });
  });

  test('parses product errors from a 409 response', () async {
    final adapter = _QueueAdapter([
      {
        'statusCode': 409,
        'data': {
          'code': 'CART_UNAVAILABLE_PRODUCTS',
          'message': 'No se puede completar el pedido.',
          'errors': [
            {
              'product_id': 5,
              'code': 'PRODUCT_INACTIVE',
              'message': 'El producto ya no está disponible.',
            },
          ],
        },
      },
    ]);
    final service = OrderService(dio: _dio(adapter));

    await expectLater(
      service.validateAvailability([_item(productId: 5, quantity: 2)]),
      throwsA(
        isA<CartAvailabilityException>()
            .having((error) => error.code, 'code', 'CART_UNAVAILABLE_PRODUCTS')
            .having((error) => error.errors, 'errors', hasLength(1))
            .having(
              (error) => error.errors.single.code,
              'issue code',
              'PRODUCT_INACTIVE',
            ),
      ),
    );
  });
}

Dio _dio(_QueueAdapter adapter) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.example.test/api/',
      validateStatus: (status) => status != null && status < 500,
    ),
  )..httpClientAdapter = adapter;
}

CartItem _item({required int productId, required int quantity}) {
  return CartItem(
    id: productId,
    userId: 1,
    productId: productId,
    name: 'Producto $productId',
    price: '1.50',
    image: null,
    quantity: quantity,
    isAvailable: true,
    createdAt: DateTime.utc(2026),
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._responses);

  final List<Map<String, dynamic>> _responses;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(response['data']),
      response['statusCode'] as int,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
