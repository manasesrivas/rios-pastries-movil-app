import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/cart_availability_issue.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/order_model.dart';
import '../controllers/auth_controller.dart';
import '../providers/cart_provider.dart';
import 'login_screen.dart';

class CartPage extends StatelessWidget {
  final AuthController authController;
  final CartProvider cartProvider;

  const CartPage({
    super.key,
    required this.authController,
    required this.cartProvider,
  });

  Future<void> _clearCart(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vaciar carrito'),
        content: const Text('¿Quieres eliminar todos los productos del carrito?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await _runAction(context, cartProvider.clearCart);
  }

  Future<void> _runAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _refreshCart(BuildContext context) async {
    await _runAction(context, cartProvider.refresh);
  }

  Future<void> _openCheckout(BuildContext context) async {
    final order = await showDialog<OrderModel>(
      context: context,
      builder: (_) => _CheckoutDialog(cartProvider: cartProvider),
    );
    if (order == null || !context.mounted) return;

    final successMessage = order.id == null
        ? 'Pedido realizado correctamente.'
        : 'Pedido #${order.id} realizado correctamente.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cartProvider,
      builder: (context, _) {
        final items = cartProvider.items;
        final canClear = cartProvider.isAuthenticated && items.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi carrito'),
            actions: [
              if (canClear)
                IconButton(
                  tooltip: 'Vaciar carrito',
                  onPressed: () => _clearCart(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: !authController.isAuthenticated
              ? _SignInPrompt(authController: authController)
              : _buildCartBody(context, items),
        );
      },
    );
  }

  Widget _buildCartBody(BuildContext context, List<CartItem> items) {
    if (cartProvider.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty && cartProvider.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(cartProvider.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _runAction(context, cartProvider.refresh),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 160),
          Icon(Icons.shopping_cart_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 16),
          Center(child: Text('Tu carrito está vacío.')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshCart(context),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          if (cartProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                cartProvider.errorMessage!,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
          if (cartProvider.hasUnavailableItems)
            Card(
              color: AppTheme.errorColor.withValues(alpha: 0.08),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No puedes continuar con la compra porque tienes productos '
                  'no disponibles en tu carrito. Elimínalos para continuar.',
                  style: TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          for (final item in items)
            _CartItemCard(
              item: item,
              isBusy: cartProvider.isCheckingOut,
              onDecrease: () => _runAction(
                context,
                () => cartProvider.updateQuantity(item.productId, item.quantity - 1),
              ),
              onIncrease: () => _runAction(
                context,
                () => cartProvider.updateQuantity(item.productId, item.quantity + 1),
              ),
              onRemove: () => _runAction(
                context,
                () => cartProvider.removeProduct(item.productId),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PriceRow(
                    label: 'Subtotal disponible',
                    value: _formatMoney(cartProvider.subtotalCents),
                  ),
                  const Divider(height: 24),
                  _PriceRow(
                    label: 'Total',
                    value: _formatMoney(cartProvider.subtotalCents),
                    emphasize: true,
                  ),
                  if (items.any((item) => !item.isAvailable)) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Los productos no disponibles se muestran en el carrito, '
                      'pero no se incluyen en el total.',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: cartProvider.canCheckout
                ? () => _openCheckout(context)
                : null,
            icon: cartProvider.isCheckingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.shopping_bag_outlined),
            label: Text(
              cartProvider.isCheckingOut
                  ? 'Validando y realizando pedido...'
                  : 'Realizar pedido',
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final AuthController authController;

  const _SignInPrompt({required this.authController});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Inicia sesión para ver y guardar tu carrito.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => LoginScreen(authController: authController),
                  ),
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool isBusy;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.isBusy,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CartProductImage(image: item.image),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text('\$${item.price} c/u'),
                      if (!item.isAvailable) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'No disponible',
                          style: TextStyle(
                            color: AppTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.availabilityCode != null)
                          Text(
                            _availabilityMessage(item.availabilityCode),
                            style: const TextStyle(
                              color: AppTheme.errorColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar producto',
                  onPressed: isBusy ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  tooltip: 'Disminuir cantidad',
                  onPressed:
                      !isBusy && item.quantity > 1 ? onDecrease : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('${item.quantity}'),
                IconButton(
                  tooltip: 'Aumentar cantidad',
                  onPressed: isBusy ? null : onIncrease,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 12),
                Text(
                  item.isAvailable
                      ? _formatMoney(item.unitPriceCents * item.quantity)
                      : 'No incluido',
                  style: TextStyle(
                    color: item.isAvailable ? null : AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartProductImage extends StatelessWidget {
  final String? image;

  const _CartProductImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.fastfood, color: AppTheme.primaryColor),
    );

    if (image == null || image!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        image!,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _PriceRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
      fontSize: emphasize ? 18 : null,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _CheckoutDialog extends StatefulWidget {
  final CartProvider cartProvider;

  const _CheckoutDialog({required this.cartProvider});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  String _paymentMethod = 'efectivo';
  String _deliveryType = 'recoger';
  String? _errorMessage;
  List<String> _productErrors = [];
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _productErrors = [];
    });

    try {
      final order = await widget.cartProvider.placeOrder(
        paymentMethod: _paymentMethod,
        deliveryType: _deliveryType,
      );
      if (mounted) Navigator.pop(context, order);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is CartAvailabilityException) {
          _errorMessage = error.message;
          _productErrors = error.errors
              .map((issue) => 'Producto #${issue.productId}: ${issue.message}')
              .toList();
        } else {
          _errorMessage = error.toString().replaceFirst('Bad state: ', '');
        }
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = _isSubmitting;

    return AlertDialog(
      title: const Text('Confirmar pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: const [
                DropdownMenuItem(value: 'tarjeta', child: Text('Tarjeta')),
                DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
              ],
              onChanged: isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _paymentMethod = value);
                      }
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _deliveryType,
              decoration: const InputDecoration(labelText: 'Tipo de entrega'),
              items: const [
                DropdownMenuItem(
                  value: 'recoger',
                  child: Text('Recoger en tienda'),
                ),
                DropdownMenuItem(
                  value: 'domicilio',
                  child: Text('Domicilio'),
                ),
              ],
              onChanged: isSubmitting
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _deliveryType = value);
                      }
                    },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final productError in _productErrors)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    productError,
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              if (_productErrors.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Cierra esta ventana, elimina los productos afectados del '
                    'carrito y vuelve a intentar.',
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isSubmitting ? null : _submit,
          child: isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Validar y realizar pedido'),
        ),
      ],
    );
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

String _formatMoney(int cents) {
  return '\$${(cents / 100).toStringAsFixed(2)}';
}
