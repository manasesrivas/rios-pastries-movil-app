import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rios_pastries/core/constants/api_constants.dart';
import 'package:rios_pastries/core/storage/token_storage.dart';
import 'package:rios_pastries/data/database/cart_database.dart';
import 'package:rios_pastries/data/models/cart_availability_issue.dart';
import 'package:rios_pastries/data/models/cart_item.dart';
import 'package:rios_pastries/data/models/order_model.dart';
import 'package:rios_pastries/data/models/product_model.dart';
import 'package:rios_pastries/data/repositories/cart_repository.dart';
import 'package:rios_pastries/data/services/order_service.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/providers/cart_provider.dart';

void main() {
  late CartDatabase database;
  late CartRepository repository;
  late AuthController authController;

  setUpAll(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({
      ApiConstants.tokenKey: 'test-token',
      ApiConstants.userKey: jsonEncode({
        'id': '4',
        'email': 'test@example.com',
        'nombres': 'Test User',
        'grupo': 'customer',
      }),
    });
    await TokenStorage.init();
  });

  setUp(() async {
    authController = AuthController();
    await authController.checkAuthStatus();
    database = CartDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = CartRepository(cartDatabase: database);
  });

  tearDown(() async {
    authController.dispose();
    await database.close();
  });

  test('keeps cart and applies 409 errors when order creation is rejected', () async {
    final service = _FakeOrderService(
      createError: const CartAvailabilityException(
        code: 'CART_UNAVAILABLE_PRODUCTS',
        message: 'No se puede completar el pedido.',
        errors: [
          CartAvailabilityIssue(
            productId: 5,
            code: 'PRODUCT_INACTIVE',
            message: 'El producto ya no está disponible.',
          ),
        ],
      ),
    );
    final provider = CartProvider(
      authController: authController,
      repository: repository,
      orderService: service,
    );
    addTearDown(provider.dispose);

    await provider.refresh();
    await provider.addProduct(_product);

    await expectLater(
      provider.placeOrder(paymentMethod: 'efectivo', deliveryType: 'recoger'),
      throwsA(isA<CartAvailabilityException>()),
    );

    expect(service.validationCalls, 1);
    expect(service.createCalls, 1);
    expect(provider.items, hasLength(1));
    expect(provider.items.single.isAvailable, isFalse);
    expect(provider.items.single.availabilityCode, 'PRODUCT_INACTIVE');
  });

  test('clears only after successful order creation', () async {
    final service = _FakeOrderService();
    final provider = CartProvider(
      authController: authController,
      repository: repository,
      orderService: service,
    );
    addTearDown(provider.dispose);

    await provider.refresh();
    await provider.addProduct(_product, quantity: 2);

    final order = await provider.placeOrder(
      paymentMethod: 'tarjeta',
      deliveryType: 'domicilio',
    );

    expect(order.id, 12);
    expect(service.validationCalls, 1);
    expect(service.createCalls, 1);
    expect(service.lastPaymentMethod, 'tarjeta');
    expect(service.lastDeliveryType, 'domicilio');
    expect(service.lastItems, [
      {'product_id': 5, 'quantity': 2},
    ]);
    expect(provider.items, isEmpty);
    expect(await repository.getItems(4), isEmpty);
  });
}

final _product = ProductModel(
  id: 5,
  name: 'Horchata',
  image: null,
  description: '',
  price: '1.50',
  category: 'Bebidas',
  available: true,
  status: 'disponible',
);

class _FakeOrderService extends OrderService {
  _FakeOrderService({this.createError}) : super(dio: Dio());

  final CartAvailabilityException? createError;
  int validationCalls = 0;
  int createCalls = 0;
  String? lastPaymentMethod;
  String? lastDeliveryType;
  List<Map<String, int>> lastItems = [];

  @override
  Future<void> validateAvailability(List<CartItem> items) async {
    validationCalls++;
  }

  @override
  Future<OrderModel> createOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required String deliveryType,
  }) async {
    createCalls++;
    lastPaymentMethod = paymentMethod;
    lastDeliveryType = deliveryType;
    lastItems = items
        .map<Map<String, int>>(
          (item) => {
            'product_id': item.productId,
            'quantity': item.quantity,
          },
        )
        .toList();

    if (createError != null) throw createError!;
    return OrderModel(
      id: 12,
      subtotal: '3.00',
      total: '3.00',
      fecha: '2026-11-09',
      hora: '11:00:00',
      direccion: '',
      metodoPago: paymentMethod,
      tipoEntrega: deliveryType,
      status: 'pendiente',
    );
  }
}
