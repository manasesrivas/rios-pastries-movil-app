import 'package:flutter/material.dart';

import '../../controllers/auth_controller.dart';
import '../../../data/models/order_model.dart';
import '../../../data/services/order_service.dart';
import '../login_screen.dart';
import 'order_detail_screen.dart';

import '../../../core/utils/utils.dart';

class OrdersSection extends StatefulWidget {
  final AuthController authController;
  final OrderService? orderService;
  final Widget? cartAction;

  const OrdersSection({
    super.key,
    required this.authController,
    this.orderService,
    this.cartAction,
  });

  @override
  State<OrdersSection> createState() => _OrdersSectionState();
}

class _OrdersSectionState extends State<OrdersSection> {
  late final OrderService _orderService;
  Future<List<OrderModel>>? _ordersFuture;
  final Set<String> _selectedStatuses = {'PENDIENTE'};

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    if (widget.authController.isAuthenticated) {
      _ordersFuture = _orderService.getOrders();
    }
    widget.authController.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    if (!mounted) return;

    if (widget.authController.isAuthenticated && _ordersFuture == null) {
      setState(() {
        _ordersFuture = _orderService.getOrders();
      });
    } else if (!widget.authController.isAuthenticated &&
        _ordersFuture != null) {
      setState(() {
        _ordersFuture = null;
      });
    }
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _orderService.getOrders();
    });
  }

  Widget _buildStatusFilters() {
    const statuses = {
      'PENDIENTE': 'Pendientes',
      'ENTREGADO': 'Entregadas',
      'APARTADO': 'Apartadas',
      'CANCELADO': 'Canceladas',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              'Mostrar:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ...statuses.entries.map(
            (entry) => FilterChip(
              label: Text(entry.value),
              selected: _selectedStatuses.contains(entry.key),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedStatuses.add(entry.key);
                  } else {
                    _selectedStatuses.remove(entry.key);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Órdenes'),
        actions: [?widget.cartAction],
      ),
      body: ListenableBuilder(
        listenable: widget.authController,
        builder: (context, _) {
          if (!widget.authController.isAuthenticated) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Inicia sesión para consultar tus órdenes.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => LoginScreen(
                              authController: widget.authController,
                            ),
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

          final ordersFuture = _ordersFuture;
          if (ordersFuture == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _refreshOrders,
            child: FutureBuilder<List<OrderModel>>(
              future: ordersFuture,
              builder: (context, snapshot) {
                // 1. Estado de Carga
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Estado de Error
                if (snapshot.hasError) {
                  return Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ocurrió un error', // --- print error 
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshOrders,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // 3. Estado Sin Datos / Lista Vacía
                final orders = snapshot.data ?? [];
                final filteredOrders = orders
                    .where(
                      (order) => _selectedStatuses.contains(
                        order.status.trim().toUpperCase(),
                      ),
                    )
                    .toList();

                // 4. Estado con Datos Cargados
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: filteredOrders.isEmpty
                      ? 2
                      : filteredOrders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildStatusFilters();
                    if (filteredOrders.isEmpty) {
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            orders.isEmpty
                                ? 'No hay órdenes registradas.'
                                : 'No hay órdenes con los estados seleccionados.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    final order = filteredOrders[index - 1];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 6.0,
                      ),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => OrderDetailScreen(order: order),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(order.status),
                          child: const Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Text(
                          'Orden #${order.id ?? index + 1} - \$${order.total}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Fecha: ${formatDate(order.fecha)} ${formatTime(order.hora)}\nEntrega: ${order.tipoEntrega} | Pago: ${order.metodoPago}',
                        ),
                        trailing: Chip(
                          label: Text(
                            order.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getStatusColor(order.status),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
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

}
