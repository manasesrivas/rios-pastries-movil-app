import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/order_model.dart';
import 'package:rios_pastries/data/services/order_service.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/screens/orders/orders_screen.dart';

void main() {
  testWidgets('filters orders by status and initially shows pending only', (
    tester,
  ) async {
    final authController = _AuthenticatedAuthController();
    addTearDown(authController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: OrdersSection(
          authController: authController,
          orderService: _TestOrderService([
            _order(1, 'pendiente'),
            _order(2, 'entregado'),
            _order(3, 'apartado'),
            _order(4, 'cancelado'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orden #1 - \$1.00'), findsOneWidget);
    expect(find.text('Orden #2 - \$1.00'), findsNothing);
    expect(find.text('Orden #3 - \$1.00'), findsNothing);
    expect(find.text('Orden #4 - \$1.00'), findsNothing);

    for (final status in ['Entregadas', 'Apartadas', 'Canceladas']) {
      await tester.tap(find.text(status));
      await tester.pumpAndSettle();
    }

    for (var id = 1; id <= 4; id++) {
      expect(find.text('Orden #$id - \$1.00'), findsOneWidget);
    }

    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('Orden #1 - \$1.00'), findsNothing);
    for (var id = 2; id <= 4; id++) {
      expect(find.text('Orden #$id - \$1.00'), findsOneWidget);
    }
  });
}

OrderModel _order(int id, String status) {
  return OrderModel(
    id: id,
    subtotal: '1.00',
    total: '1.00',
    fecha: '2026-11-12',
    hora: '12:00:00',
    direccion: '',
    metodoPago: 'efectivo',
    tipoEntrega: 'recoger',
    status: status,
  );
}

class _AuthenticatedAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;
}

class _TestOrderService extends OrderService {
  _TestOrderService(this.orders);

  final List<OrderModel> orders;

  @override
  Future<List<OrderModel>> getOrders() async => orders;
}
