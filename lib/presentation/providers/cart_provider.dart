import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/cart_availability_issue.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/order_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/services/order_service.dart';
import '../controllers/auth_controller.dart';

class CartProvider extends ChangeNotifier {
  CartProvider({
    required AuthController authController,
    CartRepository? repository,
    OrderService? orderService,
  }) : _authController = authController,
       _repository = repository ?? CartRepository(),
       _orderService = orderService ?? OrderService() {
    _authController.addListener(_handleAuthChange);
    _handleAuthChange();
  }

  final AuthController _authController;
  final CartRepository _repository;
  final OrderService _orderService;

  int? _userId;
  int _loadGeneration = 0;
  List<CartItem> _items = [];
  bool _isLoading = false;
  bool _isCheckingOut = false;
  String? _errorMessage;
  bool _disposed = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get isCheckingOut => _isCheckingOut;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _userId != null;
  int get itemCount => _items.fold(0, (total, item) => total + item.quantity);

  int get subtotalCents => _items.fold(
    0,
    (total, item) => item.isAvailable
        ? total + item.unitPriceCents * item.quantity
        : total,
  );

  double get subtotal => subtotalCents / 100;
  double get total => subtotal;
  bool get hasUnavailableItems => _items.any((item) => !item.isAvailable);
  bool get canCheckout =>
      isAuthenticated &&
      _items.isNotEmpty &&
      !hasUnavailableItems &&
      !_isLoading &&
      !_isCheckingOut;

  void _handleAuthChange() {
    if (_disposed) return;

    if (!_authController.isAuthenticated) {
      if (_userId == null && _items.isEmpty && _errorMessage == null) return;
      _userId = null;
      _loadGeneration++;
      _items = [];
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    final userId = int.tryParse(_authController.currentUser?.id ?? '');
    if (userId == null) {
      _userId = null;
      _loadGeneration++;
      _items = [];
      _isLoading = false;
      _errorMessage = 'No se pudo identificar al usuario autenticado.';
      notifyListeners();
      return;
    }

    if (_userId == userId) return;

    _userId = userId;
    _items = [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    unawaited(_loadForUser(userId));
  }

  Future<void> _loadForUser(int userId) async {
    final loadGeneration = ++_loadGeneration;
    try {
      final items = await _repository.getItems(userId);
      if (_disposed ||
          _userId != userId ||
          _loadGeneration != loadGeneration) {
        return;
      }
      _items = items;
      _errorMessage = null;
    } catch (error) {
      if (_disposed ||
          _userId != userId ||
          _loadGeneration != loadGeneration) {
        return;
      }
      _errorMessage = 'No se pudo cargar el carrito: $error';
    } finally {
      if (!_disposed &&
          _userId == userId &&
          _loadGeneration == loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    final userId = _requireUserId();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _loadForUser(userId);
    if (_errorMessage != null) {
      throw StateError(_errorMessage!);
    }
  }

  Future<void> addProduct(ProductModel product, {int quantity = 1}) async {
    final userId = _requireUserId();
    await _repository.addProduct(userId, product, quantity: quantity);
    await refresh();
  }

  Future<void> updateQuantity(int productId, int quantity) async {
    final userId = _requireUserId();
    await _repository.updateQuantity(userId, productId, quantity);
    await refresh();
  }

  Future<void> removeProduct(int productId) async {
    final userId = _requireUserId();
    await _repository.removeProduct(userId, productId);
    await refresh();
  }

  Future<void> clearCart() async {
    final userId = _requireUserId();
    await _repository.clearCart(userId);
    await refresh();
  }

  Future<OrderModel> placeOrder({
    required String paymentMethod,
    required String deliveryType,
  }) async {
    final userId = _requireUserId();
    if (_isCheckingOut) {
      throw StateError('Ya se está procesando el pedido.');
    }

    _isCheckingOut = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await refresh();
      if (_userId != userId) {
        throw StateError('La sesión cambió. Vuelve a intentarlo.');
      }

      final items = List<CartItem>.of(_items);
      if (items.isEmpty) {
        throw StateError('Tu carrito está vacío.');
      }
      if (items.any((item) => !item.isAvailable)) {
        throw CartAvailabilityException(
          code: 'CART_UNAVAILABLE_PRODUCTS',
          message:
              'No puedes continuar con la compra porque tienes productos no disponibles en tu carrito.',
          errors: items
              .where((item) => !item.isAvailable)
              .map(
                (item) => CartAvailabilityIssue(
                  productId: item.productId,
                  code: item.availabilityCode ?? 'PRODUCT_INACTIVE',
                  message: _availabilityMessage(item.availabilityCode),
                ),
              )
              .toList(),
        );
      }

      await _orderService.validateAvailability(items);
      if (_userId != userId) {
        throw StateError('La sesión cambió. Vuelve a intentarlo.');
      }

      final order = await _orderService.createOrder(
        items: items,
        paymentMethod: paymentMethod,
        deliveryType: deliveryType,
      );

      await _repository.clearCart(userId);
      if (_userId == userId) {
        _items = [];
        _errorMessage = null;
        notifyListeners();
      }
      return order;
    } on CartAvailabilityException catch (error) {
      await _repository.applyAvailabilityIssues(userId, error.errors);
      if (_userId == userId) {
        await _loadForUser(userId);
        _errorMessage = error.message;
        notifyListeners();
      }
      rethrow;
    } finally {
      _isCheckingOut = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> syncAvailability(List<ProductModel> backendProducts) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _repository.syncAvailability(userId, backendProducts);
      await _loadForUser(userId);
      if (_errorMessage != null) throw StateError(_errorMessage!);
    } catch (error) {
      if (_disposed || _userId != userId) return;
      _errorMessage = 'No se pudo actualizar la disponibilidad del carrito: $error';
      notifyListeners();
    }
  }

  String _availabilityMessage(String? code) {
    switch (code) {
      case 'PRODUCT_NOT_FOUND':
        return 'Este producto fue eliminado de nuestra tienda.';
      case 'PRODUCT_INACTIVE':
        return 'Este producto ya no está disponible.';
      default:
        return 'Este producto ya no está disponible.';
    }
  }

  int _requireUserId() {
    final userId = _userId;
    if (userId == null) {
      throw StateError('Inicia sesión para utilizar tu carrito.');
    }
    return userId;
  }

  @override
  void dispose() {
    _disposed = true;
    _authController.removeListener(_handleAuthChange);
    super.dispose();
  }
}
