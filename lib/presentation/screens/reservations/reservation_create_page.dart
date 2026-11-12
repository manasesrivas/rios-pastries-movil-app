import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/reservation_model.dart';
import '../../../data/services/reservation_service.dart';
import '../../controllers/reservation_form_controller.dart';

class ReservationCreatePage extends StatefulWidget {
  final Reservation? reservation;
  final ReservationService? reservationService;

  const ReservationCreatePage({
    super.key,
    this.reservation,
    this.reservationService,
  });

  @override
  State<ReservationCreatePage> createState() => _ReservationCreatePageState();
}

class _ReservationCreatePageState extends State<ReservationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  late final ReservationFormController _controller;
  late final TextEditingController _dateController;
  late final TextEditingController _peopleController;
  late DateTime _selectedDate;
  late ReservationStatus _selectedStatus;
  int? _selectedHallId;

  bool get _isEditing => widget.reservation != null;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _controller = ReservationFormController(
      reservationService: widget.reservationService,
    );
    _selectedDate = reservation?.fechaEvento ?? _today;
    _selectedHallId = reservation?.sala;
    _selectedStatus = reservation?.estado ?? ReservationStatus.confirmada;
    _dateController = TextEditingController(text: _formatDate(_selectedDate));
    _peopleController = TextEditingController(
      text: reservation?.cantidadPersonas.toString() ?? '',
    );
    unawaited(_controller.loadHalls());
  }

  @override
  void dispose() {
    _controller.dispose();
    _dateController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate() async {
    final originalDate = widget.reservation?.fechaEvento;
    final firstDate = originalDate != null &&
            _dateOnly(originalDate).isBefore(_today)
        ? _dateOnly(originalDate)
        : _today;
    final initialDate = _dateOnly(_selectedDate);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha del evento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (pickedDate == null || !mounted) return;
    setState(() {
      _selectedDate = _dateOnly(pickedDate);
      _dateController.text = _formatDate(_selectedDate);
    });
    _controller.clearFieldError('fecha_evento');
  }

  String? _validateDate(String? _) {
    final backendError = _controller.fieldErrors['fecha_evento'];
    if (backendError != null) return backendError;

    final date = _dateOnly(_selectedDate);
    final originalDate = widget.reservation?.fechaEvento;
    final unchanged = originalDate != null &&
        date.isAtSameMomentAs(_dateOnly(originalDate));
    if (date.isBefore(_today) && (!_isEditing || !unchanged)) {
      return 'La fecha del evento debe ser hoy o una fecha futura.';
    }
    return null;
  }

  String? _validatePeople(String? value) {
    final backendError = _controller.fieldErrors['cantidad_personas'];
    if (backendError != null) return backendError;

    if (value == null || value.trim().isEmpty) {
      return 'Ingresa la cantidad de personas.';
    }
    final count = int.tryParse(value.trim());
    if (count == null) {
      return 'Ingresa un número entero válido.';
    }
    if (count <= 0) {
      return 'La cantidad debe ser mayor que cero.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final hallId = _selectedHallId;
    if (hallId == null) return;

    final reservation = Reservation(
      id: widget.reservation?.id,
      fechaEvento: _dateOnly(_selectedDate),
      cantidadPersonas: int.parse(_peopleController.text.trim()),
      sala: hallId,
      estado: _isEditing
          ? _selectedStatus
          : ReservationStatus.confirmada,
      totalProductos: widget.reservation?.totalProductos,
    );
    final saved = await _controller.save(reservation);
    if (!mounted) return;

    if (saved) {
      Navigator.pop(context, true);
      return;
    }

    _formKey.currentState?.validate();
    final message = _controller.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar reservación' : 'Nueva reservación'),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Fecha del evento',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: _validateDate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _peopleController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) =>
                      _controller.clearFieldError('cantidad_personas'),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad de personas',
                  ),
                  validator: _validatePeople,
                ),
                const SizedBox(height: 16),
                _buildHallField(),
                if (_isEditing) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ReservationStatus>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: ReservationStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (status) {
                      if (status != null) {
                        setState(() => _selectedStatus = status);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Total de productos',
                    ),
                    child: Text(
                      widget.reservation?.totalProductos == null
                          ? 'No disponible'
                          : '\$${widget.reservation!.totalProductos!.toStringAsFixed(2)}',
                    ),
                  ),
                ],
                if (_controller.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _controller.errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _controller.isSaving ||
                          _controller.isLoadingHalls ||
                          _controller.halls.isEmpty
                      ? null
                      : _submit,
                  icon: _controller.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _controller.isSaving ? 'Guardando...' : 'Guardar reservación',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHallField() {
    if (_controller.isLoadingHalls) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Sala'),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Cargando salas...'),
          ],
        ),
      );
    }

    final hallsError = _controller.hallsError;
    if (hallsError != null) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Sala'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No se pudieron cargar las salas: $hallsError'),
            TextButton(
              onPressed: _controller.loadHalls,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_controller.halls.isEmpty) {
      return const InputDecorator(
        decoration: InputDecoration(labelText: 'Sala'),
        child: Text('No hay salas disponibles.'),
      );
    }

    final availableHallIds = _controller.halls.map((hall) => hall.id).toSet();
    final selectedHallId = availableHallIds.contains(_selectedHallId)
        ? _selectedHallId
        : null;

    return DropdownButtonFormField<int>(
      key: ValueKey(selectedHallId),
      initialValue: selectedHallId,
      decoration: const InputDecoration(labelText: 'Sala'),
      items: _controller.halls
          .map(
            (hall) => DropdownMenuItem(
              value: hall.id,
              child: Text(hall.hallName),
            ),
          )
          .toList(),
      onChanged: (hallId) {
        setState(() => _selectedHallId = hallId);
        _controller.clearFieldError('sala');
      },
      validator: (value) {
        final backendError = _controller.fieldErrors['sala'];
        if (backendError != null) return backendError;
        return value == null ? 'Selecciona una sala.' : null;
      },
    );
  }

  String _statusLabel(ReservationStatus status) {
    return switch (status) {
      ReservationStatus.pendiente => 'Pendiente',
      ReservationStatus.confirmada => 'Confirmada',
      ReservationStatus.cancelada => 'Cancelada',
      ReservationStatus.finalizada => 'Finalizada',
      ReservationStatus.eliminada => 'Eliminada',
    };
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
