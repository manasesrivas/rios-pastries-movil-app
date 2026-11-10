import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/models/product_model.dart';
import '../../data/services/product_service.dart';
import '../controllers/auth_controller.dart';
import '../providers/cart_provider.dart';
import '../widgets/card_product.dart';

class ProductsSection extends StatefulWidget {
  final AuthController authController;
  final CartProvider cartProvider;

  const ProductsSection({
    super.key,
    required this.authController,
    required this.cartProvider,
  });

  @override
  State<ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<ProductsSection> {
  final ProductService _productService = ProductService();
  late Future<List<ProductModel>> _productsFuture;
  List<ProductModel> _cachedProducts = [];
  bool _productsLoaded = false;

  @override
  void initState() {
    super.initState();
    widget.authController.addListener(_handleAuthChange);
    _productsFuture = _loadProducts();
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthChange);
    super.dispose();
  }

  Future<List<ProductModel>> _loadProducts() async {
    final products = await _productService.getProducts();
    _cachedProducts = products;
    _productsLoaded = true;
    if (widget.authController.isAuthenticated) {
      await widget.cartProvider.syncAvailability(products);
    }
    return products;
  }

  void _handleAuthChange() {
    if (widget.authController.isAuthenticated && _productsLoaded) {
      unawaited(widget.cartProvider.syncAvailability(_cachedProducts));
    }
  }

  Future<void> _refreshProducts() async {
    final future = _loadProducts();
    setState(() => _productsFuture = future);
    try {
      await future;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron actualizar los productos: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductModel>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        return RefreshIndicator(
          onRefresh: _refreshProducts,
          child: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: 300,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Hubo un error',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshProducts,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final products = snapshot.data ?? [];
              if (products.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No hay productos disponibles.')),
                  ],
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return ProductCard(
                    product: products[index],
                    authController: widget.authController,
                    cartProvider: widget.cartProvider,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
