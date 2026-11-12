import 'package:flutter/material.dart';

import '../../../data/models/order_model.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Orden #${order.id ?? '-'}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _OrderStatusCard(status: order.status),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Información de la orden',
            children: [
              _DetailRow(label: 'Cliente ID', value: order.user?.toString()),
              _DetailRow(label: 'Fecha', value: _formatDate(order.fecha)),
              _DetailRow(label: 'Hora', value: _formatTime(order.hora)),
              _DetailRow(label: 'Tipo de entrega', value: order.tipoEntrega),
              _DetailRow(
                label: 'Dirección',
                value: order.direccion.isEmpty
                    ? 'No especificada'
                    : order.direccion,
              ),
              _DetailRow(label: 'Método de pago', value: order.metodoPago),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Productos (${order.details.length})',
            children: order.details.isEmpty
                ? const [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Esta orden no contiene detalles de productos.',
                      ),
                    ),
                  ]
                : [
                    for (
                      var index = 0;
                      index < order.details.length;
                      index++
                    ) ...[
                      if (index > 0) const Divider(height: 24),
                      _OrderItemTile(detail: order.details[index]),
                    ],
                  ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Resumen',
            children: [
              _DetailRow(label: 'Subtotal', value: '\$${order.subtotal}'),
              const Divider(height: 20),
              _DetailRow(
                label: 'Total',
                value: '\$${order.total}',
                emphasize: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OrderStatusCard extends StatelessWidget {
  final String status;

  const _OrderStatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(Icons.receipt_long, color: color),
        ),
        title: const Text('Estado de la orden'),
        subtitle: Text(
          status.isEmpty ? 'No especificado' : status.toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool emphasize;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedValue = value?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              resolvedValue == null || resolvedValue.isEmpty
                  ? 'No disponible'
                  : resolvedValue,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.bold : FontWeight.w500,
                fontSize: emphasize ? 17 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderDetailModel detail;

  const _OrderItemTile({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.local_cafe_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.productName.isEmpty
                    ? 'Producto ${detail.productId ?? ''}'
                    : detail.productName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text('${detail.quantity} × \$${detail.price}'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '\$${detail.subtotal}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pendiente':
      return Colors.orange;
    case 'completado':
    case 'entregado':
      return Colors.green;
    case 'cancelado':
      return Colors.red;
    default:
      return Colors.blueGrey;
  }
}

String _formatDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;

  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatTime(String value) {
  final time = DateTime.tryParse('2000-01-01T$value');
  if (time == null) return value;

  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
