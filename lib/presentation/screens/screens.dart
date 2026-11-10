import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../providers/cart_provider.dart';
import 'users/user_profile.dart';
import 'products/products_screen.dart';
import 'orders/orders_screen.dart';
import 'cart_page.dart';

List<Widget> buildNavigationScreens(
  AuthController authController,
  CartProvider cartProvider,
) {
  return [
    ProductsScreen(
      authController: authController,
      cartProvider: cartProvider,
    ),
    OrdersSection(authController: authController),
    CartPage(
      authController: authController,
      cartProvider: cartProvider,
    ),
    ProfileScreen(authController: authController),
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
  late final CartProvider _cartProvider;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _cartProvider = CartProvider(authController: widget.authController);
    _screens = buildNavigationScreens(widget.authController, _cartProvider);
  }

  @override
  void dispose() {
    _cartProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Órdenes',
          ),
          NavigationDestination(
            icon: _CartNavigationIcon(cartProvider: _cartProvider),
            selectedIcon: _CartNavigationIcon(
              cartProvider: _cartProvider,
              selected: true,
            ),
            label: 'Carrito',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _CartNavigationIcon extends StatelessWidget {
  final CartProvider cartProvider;
  final bool selected;

  const _CartNavigationIcon({
    required this.cartProvider,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartProvider,
      builder: (context, _) {
        return Badge(
          isLabelVisible: cartProvider.itemCount > 0,
          label: Text('${cartProvider.itemCount}'),
          child: Icon(
            selected ? Icons.shopping_bag : Icons.shopping_bag_outlined,
          ),
        );
      },
    );
  }
}
