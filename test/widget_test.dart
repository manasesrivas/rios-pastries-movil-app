import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rios_pastries/main.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Unauthenticated users can browse products and see navigation', (
    WidgetTester tester,
  ) async {
    final authController = AuthController();
    await tester.pumpWidget(RiosPastriesApp(authController: authController));
    await tester.pumpAndSettle();

    expect(find.text('Ríos Pastries'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Órdenes'), findsOneWidget);
  });
}
