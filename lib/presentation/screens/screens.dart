import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../providers/cart_provider.dart';
import 'users/user_profile.dart';
import 'products/products_screen.dart';
import 'orders/orders_screen.dart';
import 'reservations/reservations_page.dart';
import 'cart_page.dart';

List<Widget> buildNavigationScreens(
  AuthController authController,
  CartProvider cartProvider,
  VoidCallback onOpenCart,
  VoidCallback onCloseCart,
) {
  final cartAction = _CartButton(
    cartProvider: cartProvider,
    onPressed: onOpenCart,
  );
  return [
    ProductsScreen(
      authController: authController,
      cartProvider: cartProvider,
      cartAction: cartAction,
    ),
    OrdersSection(authController: authController, cartAction: cartAction),
    ReservationsPage(
      authController: authController,
      cartProvider: cartProvider,
      cartAction: cartAction,
    ),
    ProfileScreen(authController: authController, cartAction: cartAction),
    CartPage(
      authController: authController,
      cartProvider: cartProvider,
      onBack: onCloseCart,
    ),
  ];
}

class BaseScreen extends StatefulWidget {
  final AuthController authController;

  const BaseScreen({super.key, required this.authController});

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  int _currentIndex = 0;
  bool _showCart = false;
  late final CartProvider _cartProvider;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _cartProvider = CartProvider(authController: widget.authController);
    _screens = buildNavigationScreens(
      widget.authController,
      _cartProvider,
      () => setState(() => _showCart = true),
      () => setState(() => _showCart = false),
    );
  }

  @override
  void dispose() {
    _cartProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showCart,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showCart) setState(() => _showCart = false);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _showCart ? _screens.length - 1 : _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
              _showCart = false;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Órdenes',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Reservas',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final CartProvider cartProvider;
  final VoidCallback onPressed;

  const _CartButton({required this.cartProvider, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartProvider,
      builder: (context, _) {
        return IconButton(
          tooltip: 'Carrito',
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible: cartProvider.itemCount > 0,
            label: Text('${cartProvider.itemCount}'),
            child: const Icon(Icons.shopping_bag_outlined),
          ),
        );
      },
    );
  }
}
