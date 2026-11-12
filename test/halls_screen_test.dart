import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/reservation_model.dart';
import 'package:rios_pastries/data/services/halls_service.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/screens/halls/halls_screen.dart';

void main() {
  testWidgets('requires sign-in without requesting halls', (tester) async {
    final service = _FakeHallsService([]);
    final auth = AuthController();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HallsScreen(authController: auth, hallsService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Inicia sesión para consultar las salas.'),
      findsOneWidget,
    );
    expect(service.calls, 0);
  });

  testWidgets('loads halls after sign-in and clears them after sign-out', (
    tester,
  ) async {
    final service = _FakeHallsService([
      const HallModel(id: 1, hallName: 'Sala privada'),
    ]);
    final auth = _MutableAuthController();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HallsScreen(authController: auth, hallsService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.calls, 0);

    auth.setAuthenticated(true);
    await tester.pumpAndSettle();
    expect(find.text('Sala privada'), findsOneWidget);
    expect(service.calls, 1);

    auth.setAuthenticated(false);
    await tester.pumpAndSettle();
    expect(find.text('Sala privada'), findsNothing);
    expect(
      find.text('Inicia sesión para consultar las salas.'),
      findsOneWidget,
    );
  });

  testWidgets('shows hall and nested venue details without another request', (
    tester,
  ) async {
    final service = _FakeHallsService([
      HallModel.fromJson({
        'id': 1,
        'venueName': 'Local #1',
        'venue': {
          'id': 1,
          'name': 'Local #1',
          'address': 'San Miguel Centro, San Miguel',
          'descripcion': 'Un local para eventos',
          'status': 'activo',
        },
        'name': 'Sala #1',
        'image': null,
        'capacity': 100,
        'price': '100.00',
        'status': 'DISPONIBLE',
      }),
    ]);
    final auth = _AuthenticatedAuthController();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HallsScreen(authController: auth, hallsService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sala #1'), findsOneWidget);
    expect(find.text('Local #1'), findsOneWidget);

    await tester.tap(find.text('Sala #1'));
    await tester.pumpAndSettle();
    expect(find.text('100 personas'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
    expect(find.text('San Miguel Centro, San Miguel'), findsOneWidget);
    expect(find.text('Un local para eventos'), findsOneWidget);
    expect(find.text('activo'), findsOneWidget);
    expect(service.calls, 1);
  });

  testWidgets('shows errors and retries to an empty list', (tester) async {
    final service = _FakeHallsService([], failFirst: true);
    final auth = _AuthenticatedAuthController();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HallsScreen(authController: auth, hallsService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudieron cargar las salas'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('No hay salas registradas.'), findsOneWidget);
    expect(service.calls, 2);
  });

  testWidgets('handles a hall without venue information', (tester) async {
    final service = _FakeHallsService([
      const HallModel(id: 1, hallName: 'Sala sin local'),
    ]);
    final auth = _AuthenticatedAuthController();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: HallsScreen(authController: auth, hallsService: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Local no disponible'), findsOneWidget);
    await tester.tap(find.text('Sala sin local'));
    await tester.pumpAndSettle();
    expect(find.text('No disponible'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _AuthenticatedAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;
}

class _MutableAuthController extends AuthController {
  bool _authenticated = false;

  @override
  bool get isAuthenticated => _authenticated;

  void setAuthenticated(bool value) {
    _authenticated = value;
    notifyListeners();
  }
}

class _FakeHallsService extends HallsService {
  _FakeHallsService(this.halls, {this.failFirst = false});

  final List<HallModel> halls;
  final bool failFirst;
  int calls = 0;

  @override
  Future<List<HallModel>> getHalls() async {
    calls++;
    if (failFirst && calls == 1) throw Exception('Error de prueba');
    return halls;
  }
}
