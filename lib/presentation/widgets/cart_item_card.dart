import 'package:flutter/material.dart';

import '../../data/models/cart_item.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final bool isBusy;
  final bool showQuantityControls;
  final String? errorMessage;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    this.isBusy = false,
    this.showQuantityControls = true,
    this.errorMessage,
    this.onDecrease,
    this.onIncrease,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = item.isAvailable
        ? _formatMoney(item.unitPriceCents * item.quantity)
        : 'No incluido';

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
                        Text(
                          'No disponible',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.availabilityCode != null)
                          Text(
                            _availabilityMessage(item.availabilityCode),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                      ],
                      if (errorMessage != null)
                        Text(
                          errorMessage!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Eliminar producto',
                    onPressed: isBusy ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (showQuantityControls)
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    tooltip: 'Disminuir cantidad',
                    onPressed: !isBusy && item.quantity > 1 ? onDecrease : null,
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
                    subtotal,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Subtotal: $subtotal',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.fastfood,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
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

String _formatMoney(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
