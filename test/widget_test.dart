import 'package:flutter/material.dart';
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

  testWidgets('cart is available in each app bar and returns to the section', (
    tester,
  ) async {
    final authController = AuthController();
    addTearDown(authController.dispose);
    await tester.pumpWidget(RiosPastriesApp(authController: authController));
    await tester.pumpAndSettle();

    final navigation = find.byType(NavigationBar);
    expect(
      find.descendant(of: navigation, matching: find.text('Carrito')),
      findsNothing,
    );

    for (final section in [
      'Inicio',
      'Órdenes',
      'Reservas',
      'Salas',
      'Perfil',
    ]) {
      await tester.tap(find.text(section));
      await tester.pumpAndSettle();

      final cartButton = find.byTooltip('Carrito');
      expect(
        find.descendant(of: find.byType(AppBar), matching: cartButton),
        findsOneWidget,
      );
      await tester.tap(cartButton);
      await tester.pumpAndSettle();
      expect(find.text('Mi carrito'), findsOneWidget);
      expect(
        find.text('Inicia sesión para ver y guardar tu carrito.'),
        findsOneWidget,
      );

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Carrito'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(navigation).selectedIndex,
        ['Inicio', 'Órdenes', 'Reservas', 'Salas', 'Perfil'].indexOf(section),
      );
    }

    await tester.tap(find.byTooltip('Carrito'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Mi carrito'), findsNothing);
    expect(find.text('Perfil'), findsWidgets);
  });

  testWidgets('follows the system light and dark palettes', (tester) async {
    final authController = AuthController();
    addTearDown(authController.dispose);
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pumpWidget(RiosPastriesApp(authController: authController));
    await tester.pumpAndSettle();

    void expectPalette({
      required Brightness brightness,
      required Color background,
      required Color surface,
      required Color text,
      required Color secondary,
      required Color border,
      required Color primary,
    }) {
      final theme = Theme.of(tester.element(find.text('Ríos Pastries').first));
      expect(theme.brightness, brightness);
      expect(theme.scaffoldBackgroundColor, background);
      expect(theme.colorScheme.surface, surface);
      expect(theme.appBarTheme.backgroundColor, surface);
      expect(theme.cardTheme.color, surface);
      expect(theme.colorScheme.onSurface, text);
      expect(theme.colorScheme.onSurfaceVariant, secondary);
      expect(theme.colorScheme.outline, border);
      expect(theme.colorScheme.primary, primary);
    }

    expectPalette(
      brightness: Brightness.light,
      background: const Color(0xFFF3F4F6),
      surface: Colors.white,
      text: const Color(0xFF111827),
      secondary: const Color(0xFF4B5563),
      border: const Color(0xFFE5E7EB),
      primary: const Color(0xFF4F46E5),
    );

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    await tester.pumpAndSettle();
    expectPalette(
      brightness: Brightness.dark,
      background: const Color(0xFF020617),
      surface: const Color(0xFF111827),
      text: Colors.white,
      secondary: const Color(0xFFD1D5DB),
      border: const Color(0xFF374151),
      primary: const Color(0xFF818CF8),
    );

    await tester.tap(find.byTooltip('Carrito'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Ríos Pastries').last).style?.color,
      Colors.white,
    );
    expect(
      tester
          .widget<Text>(find.text('Inicia sesión para gestionar tu repostería'))
          .style
          ?.color,
      const Color(0xFFD1D5DB),
    );
    expect(
      tester.widget<Text>(find.text('Correo Electrónico')).style?.color,
      Colors.white,
    );
  });
}
