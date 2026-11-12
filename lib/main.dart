import 'package:flutter/material.dart';

import 'core/network/dio_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenStorage.init();

  runApp(RiosPastriesApp(authController: AuthController()));
}

class RiosPastriesApp extends StatelessWidget {
  final AuthController authController;

  const RiosPastriesApp({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ríos Pastries',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: AuthGate(authController: authController),
    );
  }
}
