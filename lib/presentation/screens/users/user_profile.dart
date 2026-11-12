import 'package:flutter/material.dart';
import 'package:rios_pastries/presentation/screens/login_screen.dart';

import '../../controllers/auth_controller.dart';

class ProfileScreen extends StatelessWidget {
  final AuthController authController;
  final Widget? cartAction;

  const ProfileScreen({super.key, required this.authController, this.cartAction});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await authController.logout();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cerrar sesión: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        final user = authController.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Perfil'),
            actions: [?cartAction],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 40,
                  child: Icon(Icons.person, size: 44),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  user?.name.isNotEmpty == true ? user!.name : 'Mi cuenta',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 24),
              if (user == null)
                Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Inicia sesión para ver los datos de tu perfil.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    SizedBox(height: 20,),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => LoginScreen(
                              authController: authController,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Iniciar sesión'),
                    ),
                  ],
                )
              else ...[
                Card(
                  child: Column(
                    children: [
                      _ProfileInfoTile(
                        label: 'ID',
                        value: user.id,
                        icon: Icons.badge_outlined,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _ProfileInfoTile(
                        label: 'Nombre',
                        value: user.name,
                        icon: Icons.person_outline,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _ProfileInfoTile(
                        label: 'Correo electrónico',
                        value: user.email,
                        icon: Icons.email_outlined,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _ProfileInfoTile(
                        label: 'Rol',
                        value: user.role,
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: authController.isLoading
                      ? null
                      : () => _confirmLogout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;

  const _ProfileInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value?.trim();

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        displayValue == null || displayValue.isEmpty
            ? 'No disponible'
            : displayValue,
      ),
    );
  }
}
