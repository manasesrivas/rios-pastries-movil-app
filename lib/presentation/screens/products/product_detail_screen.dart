import 'package:flutter/material.dart';

import '../../../core/utils/product_image_url.dart';
import '../../controllers/auth_controller.dart';
import '../../providers/cart_provider.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/product_service.dart';
import '../../widgets/back_button.dart';
import '../login_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final AuthController authController;
  final CartProvider cartProvider;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.authController,
    required this.cartProvider,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productService = ProductService();
  late Future<ProductModel> _futureProduct;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _futureProduct = _productService.getProduct(widget.productId);
  }

  void _reload() {
    setState(() {
      _futureProduct = _productService.getProduct(widget.productId);
    });
  }

  Future<void> _addToCart(ProductModel product) async {
    if (!widget.authController.isAuthenticated) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              LoginScreen(authController: widget.authController),
        ),
      );
      if (!mounted || !widget.authController.isAuthenticated) return;
    }

    try {
      await widget.cartProvider.addProduct(product, quantity: _quantity);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} agregado al carrito.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FutureBuilder<ProductModel>(
            future: _futureProduct,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _ProductSkeleton();
              }
              if (snapshot.hasError) {
                return _ErrorView(onRetry: _reload);
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('Producto no encontrado'));
              }
              return _ProductContent(
                product: snapshot.data!,
                quantity: _quantity,
                onQuantityChanged: (q) => setState(() => _quantity = q),
                onAdd: () => _addToCart(snapshot.data!),
              );
            },
          ),
          const Align(
            alignment: Alignment.topLeft,
            child: BackButtonOverlay(),
          ),

        ],
      )
    );
  }
}

class _ProductContent extends StatelessWidget {
  final ProductModel product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final Future<void> Function() onAdd;

  const _ProductContent({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: scheme.surface,
              automaticallyImplyLeading: false, 
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  child: _ProductImage(url: product.image),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Chip(
                          label: product.category,
                          color: scheme.primaryContainer,
                          textColor: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          label: product.available ? 'Disponible' : 'Agotado',
                          color: product.available
                              ? Colors.green.withOpacity(0.12)
                              : Colors.red.withOpacity(0.12),
                          textColor: product.available
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                              : (isDark ? Colors.red.shade300 : Colors.red.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '\$${product.price}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Descripción',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            enabled: product.available,
            quantity: quantity,
            onQuantityChanged: onQuantityChanged,
            onAdd: onAdd,
          ),
        ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({this.url});

  @override
  Widget build(BuildContext context) {
    final imageUrl = productImageUrl(url);
    final placeholder = Container(
      color: Theme.of(context).colorScheme.outlineVariant,
      child: Icon(
        Icons.fastfood,
        size: 72,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (imageUrl == null) return placeholder;

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('No se pudo cargar la imagen del producto: $error');
        return placeholder;
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final Future<void> Function() onAdd;

  const _BottomBar({
    required this.enabled,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: enabled && quantity > 1
                      ? () => onQuantityChanged(quantity - 1)
                      : null,
                ),
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed:
                      enabled ? () => onQuantityChanged(quantity + 1) : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: enabled ? () => onAdd() : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                enabled ? 'Agregar al carrito' : 'No disponible',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  Widget _box(BuildContext context, double h, {double? w, double r = 12}) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.outlineVariant,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(32),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _box(context, 28, w: 90, r: 20),
                const SizedBox(width: 8),
                _box(context, 28, w: 90, r: 20),
              ]),
              const SizedBox(height: 16),
              _box(context, 28, w: 220),
              const SizedBox(height: 24),
              _box(context, 16),
              const SizedBox(height: 8),
              _box(context, 16),
              const SizedBox(height: 8),
              _box(context, 16, w: 200),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('No se pudo cargar el producto'),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}