import 'package:flutter/material.dart';

import '../../../core/utils/utils.dart';
import '../../../data/models/reservation_model.dart';
import '../../../data/services/reservation_service.dart';
import '../../controllers/auth_controller.dart';
import '../../providers/cart_provider.dart';
import '../login_screen.dart';
import 'reservation_create_page.dart';

class ReservationsPage extends StatefulWidget {
  final AuthController authController;
  final CartProvider cartProvider;
  final ReservationService? reservationService;
  final Widget? cartAction;

  const ReservationsPage({
    super.key,
    required this.authController,
    required this.cartProvider,
    this.reservationService,
    this.cartAction,
  });

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  late final ReservationService _reservationService;
  Future<List<ReservationModel>>? _reservationsFuture;
  final Set<String> _selectedStatuses = {
    ReservationStatus.confirmada.apiValue,
  };

  @override
  void initState() {
    super.initState();
    _reservationService = widget.reservationService ?? ReservationService();
    if (widget.authController.isAuthenticated) {
      _reservationsFuture = _reservationService.getReservations();
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

    if (widget.authController.isAuthenticated && _reservationsFuture == null) {
      setState(() {
        _reservationsFuture = _reservationService.getReservations();
      });
    } else if (!widget.authController.isAuthenticated &&
        _reservationsFuture != null) {
      setState(() {
        _reservationsFuture = null;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _reservationsFuture = _reservationService.getReservations();
    });
  }

  Widget _buildStatusFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          FilterChip(
            label: const Text('Confirmadas'),
            selected: _selectedStatuses.contains(
              ReservationStatus.confirmada.apiValue,
            ),
            onSelected: (selected) =>
                _toggleStatus(ReservationStatus.confirmada.apiValue, selected),
          ),
          FilterChip(
            label: const Text('Finalizadas'),
            selected: _selectedStatuses.contains(
              ReservationStatus.finalizada.apiValue,
            ),
            onSelected: (selected) =>
                _toggleStatus(ReservationStatus.finalizada.apiValue, selected),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(String status, bool selected) {
    setState(() {
      if (selected) {
        _selectedStatuses.add(status);
      } else {
        _selectedStatuses.remove(status);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservaciones'),
        actions: [?widget.cartAction],
      ),
      floatingActionButton: widget.authController.isAuthenticated
          ? FloatingActionButton.extended(
              onPressed: _createReservation,
              icon: const Icon(Icons.event),
              label: Text('crear reservacion'),
            )
          : null,
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
                      'Inicia sesión para consultar tus reservaciones.',
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

          final future = _reservationsFuture;
          if (future == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _retry,
            child: FutureBuilder<List<ReservationModel>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ReservationsMessage(
                    icon: Icons.error_outline,
                    message: snapshot.error.toString(),
                    action: ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Reintentar'),
                    ),
                  );
                }

                final reservations = snapshot.data;
                if (reservations == null || reservations.isEmpty) {
                  return const _ReservationsMessage(
                    icon: Icons.event_busy_outlined,
                    message: 'No tienes reservaciones registradas',
                  );
                }

                final filteredReservations = reservations
                    .where(
                      (reservation) => _selectedStatuses.contains(
                        reservation.estado.trim().toUpperCase(),
                      ),
                    )
                    .toList();

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    _buildStatusFilters(),
                    if (filteredReservations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Text(
                          _selectedStatuses.isEmpty
                              ? 'Selecciona un estado para ver reservaciones.'
                              : 'No hay reservaciones confirmadas o finalizadas.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...filteredReservations.map(
                        (reservation) =>
                            _ReservationCard(reservation: reservation),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _createReservation() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => ReservationCreatePage(
          authController: widget.authController,
          cartProvider: widget.cartProvider,
          reservationService: _reservationService,
        ),
      ),
    );
    if (created == true && mounted) {
      await _retry();
    }
  }
}

class _ReservationCard extends StatelessWidget {
  final ReservationModel reservation;

  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = reservationStatusColor(reservation.estado);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Reservación ${formatDate(reservation.fechaEvento.toIso8601String())}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ReservationStatusBadge(
                  status: reservation.estado,
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ReservationInfoRow(
              icon: Icons.meeting_room_outlined,
              label: 'Sala',
              value: reservation.hall.hallName,
            ),
            _ReservationInfoRow(
              icon: Icons.store_outlined,
              label: 'Local',
              value: reservation.venue.name,
            ),
            if (reservation.venue.address.isNotEmpty)
              _ReservationInfoRow(
                icon: Icons.location_on_outlined,
                label: 'Dirección',
                value: reservation.venue.address,
              ),
            _ReservationInfoRow(
              icon: Icons.people_outline,
              label: 'Personas',
              value: '${reservation.cantidadPersonas}',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReservationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'No disponible' : value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationStatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _ReservationStatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        reservationStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ReservationsMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _ReservationsMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.35,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Color reservationStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'PENDIENTE':
      return Colors.orange;
    case 'CONFIRMADA':
      return Colors.green;
    case 'CANCELADA':
      return Colors.red;
    case 'FINALIZADA':
      return Colors.blue;
    case 'ELIMINADA':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

String reservationStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDIENTE':
      return 'Pendiente';
    case 'CONFIRMADA':
      return 'Confirmada';
    case 'CANCELADA':
      return 'Cancelada';
    case 'FINALIZADA':
      return 'Finalizada';
    case 'ELIMINADA':
      return 'Eliminada';
    default:
      return status;
  }
}
