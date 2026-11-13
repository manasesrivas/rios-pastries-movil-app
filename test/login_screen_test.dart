import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('login does not offer demo autofill and accepts manual input', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = _TestAuthController();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authController: auth)),
    );
    await tester.pumpAndSettle();
    expect(auth.isDemoMode, isTrue);
    expect(find.text('Rellenar credenciales de prueba'), findsNothing);

    final fields = find.byType(TextFormField);
    expect(
      tester.widget<TextFormField>(fields.at(0)).controller!.text,
      isEmpty,
    );
    expect(
      tester.widget<TextFormField>(fields.at(1)).controller!.text,
      isEmpty,
    );
    await tester.enterText(fields.at(0), 'usuario@example.com');
    await tester.enterText(fields.at(1), 'contraseña');
    await tester.ensureVisible(find.text('Iniciar Sesión'));
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pumpAndSettle();
    expect(auth.email, 'usuario@example.com');
    expect(auth.password, 'contraseña');
  });
}

class _TestAuthController extends AuthController {
  String? email;
  String? password;

  @override
  Future<bool> login({required String email, required String password}) async {
    this.email = email;
    this.password = password;
    return false;
  }
}
