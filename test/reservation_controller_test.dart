import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/cart_item.dart';
import 'package:rios_pastries/data/services/reservation_service.dart';
import 'package:rios_pastries/presentation/controllers/reservation_controller.dart';

void main() {
  test('submits items using product IDs and quantities from the cart', () async {
    final adapter = _ApiAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.test/api/',
        validateStatus: (status) => status != null && status < 300,
      ),
    )..httpClientAdapter = adapter;
    final controller = ReservationController(
      reservationService: ReservationService(dio: dio),
    );

    controller.setMode(ReservationMode.conProductos);
    final saved = await controller.submit(
      fechaEvento: DateTime(2026, 12, 20),
      cantidadPersonas: 50,
      sala: 3,
      cartItems: [_cartItem(productId: 1, quantity: 2)],
    );

    expect(saved, isTrue);
    expect(adapter.postedData, {
      'fecha_evento': '2026-12-20',
      'cantidad_personas': 50,
      'sala': 3,
      'items': [
        {'product_id': 1, 'quantity': 2},
      ],
    });
    controller.dispose();
  });

  test('omits items in the simple reservation mode', () async {
    final adapter = _ApiAdapter();
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.example.test/api/',
        validateStatus: (status) => status != null && status < 300,
      ),
    )..httpClientAdapter = adapter;
    final controller = ReservationController(
      reservationService: ReservationService(dio: dio),
    );

    final saved = await controller.submit(
      fechaEvento: DateTime(2026, 12, 20),
      cantidadPersonas: 50,
      sala: 3,
      cartItems: [_cartItem(productId: 1, quantity: 2)],
    );

    expect(saved, isTrue);
    expect(adapter.postedData, {
      'fecha_evento': '2026-12-20',
      'cantidad_personas': 50,
      'sala': 3,
    });
    controller.dispose();
  });

  test('rejects an empty cart in product mode without sending a request', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/'));
    final controller = ReservationController(
      reservationService: ReservationService(dio: dio),
    );

    controller.setMode(ReservationMode.conProductos);
    final saved = await controller.submit(
      fechaEvento: DateTime(2026, 12, 20),
      cantidadPersonas: 2,
      sala: 3,
      cartItems: const [],
    );

    expect(saved, isFalse);
    expect(
      controller.cartError,
      "Agrega al menos un producto o elige 'Solo crear reservación'.",
    );
    controller.dispose();
  });
}

CartItem _cartItem({required int productId, required int quantity}) {
  return CartItem(
    id: productId,
    userId: 1,
    productId: productId,
    name: 'Pastel',
    price: '25.00',
    image: null,
    quantity: quantity,
    isAvailable: true,
    createdAt: DateTime(2026),
  );
}

class _ApiAdapter implements HttpClientAdapter {
  Map<String, dynamic>? postedData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    postedData = data is String
        ? jsonDecode(data) as Map<String, dynamic>
        : data as Map<String, dynamic>;
    return ResponseBody.fromString(
      jsonEncode({
        'id': 12,
        'fecha_evento': '2026-12-20',
        'cantidad_personas': 50,
        'sala': 3,
        'total_productos': '50.00',
        'items': [],
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
