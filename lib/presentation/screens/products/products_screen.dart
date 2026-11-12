import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../providers/cart_provider.dart';
import '../../sections/products_section.dart';

class ProductsScreen extends StatelessWidget {
  final AuthController authController;
  final CartProvider cartProvider;
  final Widget? cartAction;

  const ProductsScreen({
    super.key,
    required this.authController,
    required this.cartProvider,
    this.cartAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ríos Pastries'),
        actions: [?cartAction],
      ),
      body: ProductsSection(
        authController: authController,
        cartProvider: cartProvider,
      ),
    );
  }
}
