import 'package:flutter/material.dart';

import '../../../data/models/reservation_model.dart';
import '../../../data/services/halls_service.dart';
import '../../controllers/auth_controller.dart';
import '../login_screen.dart';
import 'hall_detail_screen.dart';
import 'hall_image.dart';

class HallsScreen extends StatefulWidget {
  final AuthController authController;
  final HallsService? hallsService;
  final Widget? cartAction;

  const HallsScreen({
    super.key,
    required this.authController,
    this.hallsService,
    this.cartAction,
  });

  @override
  State<HallsScreen> createState() => _HallsScreenState();
}

class _HallsScreenState extends State<HallsScreen> {
  late final HallsService _service;
  Future<List<HallModel>>? _halls;

  @override
  void initState() {
    super.initState();
    _service = widget.hallsService ?? HallsService();
    if (widget.authController.isAuthenticated) {
      _halls = _service.getHalls();
    }
    widget.authController.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    widget.authController.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    if (widget.authController.isAuthenticated && _halls == null) {
      setState(() {
        _halls = _service.getHalls();
      });
    } else if (!widget.authController.isAuthenticated && _halls != null) {
      setState(() {
        _halls = null;
      });
    }
  }

  Future<void> _refresh() async {
    final future = _service.getHalls();
    setState(() {
      _halls = future;
    });
    try {
      await future;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron actualizar las salas: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salas'), actions: [?widget.cartAction]),
      body: !widget.authController.isAuthenticated
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Inicia sesión para consultar las salas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => LoginScreen(
                            authController: widget.authController,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.login),
                      label: const Text('Iniciar sesión'),
                    ),
                  ],
                ),
              ),
            )
          : FutureBuilder<List<HallModel>>(
        future: _halls,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudieron cargar las salas: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final halls = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: halls.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No hay salas registradas.')),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: halls.length,
                    itemBuilder: (context, index) {
                      final hall = halls[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: HallImage(
                              image: hall.image,
                              width: 56,
                              height: 56,
                            ),
                          ),
                          title: Text(hall.hallName),
                          subtitle: Text(
                            hall.venueName.isEmpty
                                ? 'Local no disponible'
                                : hall.venueName,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => HallDetailScreen(hall: hall),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
