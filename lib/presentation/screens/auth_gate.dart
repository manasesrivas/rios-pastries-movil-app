import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import 'screens.dart';

class AuthGate extends StatelessWidget {
  final AuthController authController;

  const AuthGate({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        // Mientras se verifica el token guardado en disco al iniciar la app
        if (authController.isLoading && authController.currentToken == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bakery_dining_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        return BaseScreen(authController: authController);
      },
    );
  }
}
