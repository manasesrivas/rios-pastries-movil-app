import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/error_handler.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/reservation_model.dart';
import '../../../data/services/reservation_service.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/reservation_controller.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart_item_card.dart';
import '../login_screen.dart';

class ReservationCreatePage extends StatefulWidget {
  final AuthController authController;
  final CartProvider cartProvider;
  final ReservationModel? reservation;
  final ReservationService? reservationService;

  const ReservationCreatePage({
    super.key,
    required this.authController,
    required this.cartProvider,
    this.reservation,
    this.reservationService,
  });

  @override
  State<ReservationCreatePage> createState() => _ReservationCreatePageState();
}

class _ReservationCreatePageState extends State<ReservationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  late final ReservationController _controller;
  late final TextEditingController _dateController;
  late final TextEditingController _peopleController;
  late DateTime _selectedDate;
  int? _selectedHallId;

  bool get _isEditing => widget.reservation != null;

  @override
  void initState() {
    super.initState();
    final reservation = widget.reservation;
    _controller = ReservationController(
      reservationService: widget.reservationService ?? ReservationService(),
      authController: widget.authController,
    );
    _selectedDate = reservation?.fechaEvento ?? _today;
    _selectedHallId = reservation?.salaId;
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

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<void> _pickDate() async {
    final originalDate = widget.reservation?.fechaEvento;
    final firstDate =
        originalDate != null && _dateOnly(originalDate).isBefore(_today)
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
    _formKey.currentState?.validate();
  }

  String? _validateDate(String? _) {
    final externalError = _controller.fieldErrors['fecha_evento'];
    if (externalError != null && externalError.isNotEmpty) {
      return externalError.first;
    }

    final selectedDate = _dateOnly(_selectedDate);
    final originalDate = widget.reservation?.fechaEvento;
    final unchanged =
        originalDate != null &&
        selectedDate.isAtSameMomentAs(_dateOnly(originalDate));
    if (selectedDate.isBefore(_today) && (!_isEditing || !unchanged)) {
      return 'No puedes elegir una fecha pasada.';
    }
    return null;
  }

  String? _validatePeople(String? value) {
    final externalError = _controller.fieldErrors['cantidad_personas'];
    if (externalError != null && externalError.isNotEmpty) {
      return externalError.first;
    }
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa la cantidad de personas.';
    }

    final count = int.tryParse(value.trim());
    if (count == null) return 'Ingresa un número entero válido.';
    if (count <= 0) return 'La cantidad debe ser mayor que cero.';

    final hall = _selectedHall;
    final capacity = hall?.capacity;
    if (hall != null && capacity != null && count > capacity) {
      return 'La sala "${hall.hallName}" tiene capacidad para $capacity personas.';
    }
    return null;
  }

  String? _validateHall(int? value) {
    final externalError = _controller.fieldErrors['sala'];
    if (externalError != null && externalError.isNotEmpty) {
      return externalError.first;
    }
    return value == null ? 'Selecciona una sala.' : null;
  }

  HallModel? get _selectedHall {
    for (final hall in _controller.halls) {
      if (hall.id == _selectedHallId) return hall;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final hallId = _selectedHallId;
    if (hallId == null) return;

    final submittedWithProducts =
        _controller.mode == ReservationMode.conProductos;
    final saved = await _controller.submit(
      fechaEvento: _dateOnly(_selectedDate),
      cantidadPersonas: int.parse(_peopleController.text.trim()),
      sala: hallId,
      cartItems: widget.cartProvider.items,
      reservationId: widget.reservation?.id,
    );
    if (!mounted) return;

    if (saved && _isEditing) {
      Navigator.pop(context, true);
    } else if (saved) {
      String? cartClearError;
      if (submittedWithProducts) {
        try {
          await widget.cartProvider.clearCart();
        } catch (error) {
          logError(error, operation: 'No se pudo vaciar el carrito');
          cartClearError = genericErrorMessage;
        }
      }
      if (!mounted) return;
      await _showConfirmation(cartClearError: cartClearError);
    } else if (!saved) {
      if (_controller.sessionExpired) {
        Navigator.of(context).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(
            builder: (_) => LoginScreen(authController: widget.authController),
          ),
          (_) => false,
        );
        return;
      }
    }
  }

  Future<void> _showConfirmation({String? cartClearError}) async {
    final reservation = _controller.createdReservation;
    if (reservation == null) return;
    final hallName = reservation.hallName.isNotEmpty
        ? reservation.hallName
        : _selectedHall?.hallName ?? 'No disponible';
    final venueName = reservation.venueName.isNotEmpty
        ? reservation.venueName
        : _selectedHall?.venueName ?? 'No disponible';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Reservación creada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Número: ${reservation.id}'),
              Text('Fecha: ${_formatDate(reservation.fechaEvento)}'),
              Text('Sala: $hallName'),
              Text('Sede: $venueName'),
              Text('Personas: ${reservation.cantidadPersonas}'),
              Text(
                'Total de productos: '
                '\$${reservation.totalProductos.toStringAsFixed(2)}',
              ),
              if (reservation.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Productos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final item in reservation.items)
                  Text(
                    '${item.name} × ${item.quantity}'
                    '${item.subtotal == null ? '' : ' — \$${item.subtotal!.toStringAsFixed(2)}'}',
                  ),
              ],
              if (cartClearError != null) ...[
                const SizedBox(height: 12),
                Text(
                  cartClearError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ir a reservaciones'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
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
                  forceErrorText: _fieldErrorText('fecha_evento'),
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
                  forceErrorText: _fieldErrorText('cantidad_personas'),
                  validator: _validatePeople,
                ),
                const SizedBox(height: 16),
                _buildHallField(),
                _buildServerErrors(),
                if (_isEditing && widget.reservation != null) ...[
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Total de productos',
                    ),
                    child: Text(
                      '\$${widget.reservation!.totalProductos?.toStringAsFixed(2) ?? '0.00'}',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildReservationOptions(),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed:
                      _controller.isSaving ||
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
                    _controller.isSaving
                        ? 'Guardando...'
                        : 'Guardar reservación',
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
            Text(hallsError),
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

    final hallError = _controller.fieldErrors['sala'];
    final availableIds = _controller.halls.map((hall) => hall.id).toSet();
    final value = availableIds.contains(_selectedHallId)
        ? _selectedHallId
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey(value),
          initialValue: value,
          decoration: InputDecoration(
            labelText: 'Sala',
            errorText: hallError == null || hallError.isEmpty
                ? null
                : hallError.first,
          ),
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
            _formKey.currentState?.validate();
          },
          validator: _validateHall,
        ),
        if (_selectedHall?.capacity != null) ...[
          const SizedBox(height: 6),
          Text('Capacidad: ${_selectedHall!.capacity} personas'),
        ],
      ],
    );
  }

  Widget _buildReservationOptions() {
    return RadioGroup<ReservationMode>(
      groupValue: _controller.mode,
      onChanged: (mode) {
        if (!_controller.isSaving && mode != null) _selectMode(mode);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opciones de reservación',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildModeCard(
            mode: ReservationMode.soloReservacion,
            title: 'Solo crear reservación',
            description: 'Crea la reservación sin adjuntar productos.',
          ),
          _buildModeCard(
            mode: ReservationMode.conProductos,
            title: 'Adjuntar los productos del carrito',
            description: 'Incluye productos y cantidades en la reservación.',
            child: _controller.mode == ReservationMode.conProductos
                ? _buildProductSelector()
                : null,
          ),
        ],
      ),
    );
  }

  void _selectMode(ReservationMode mode) {
    _controller.setMode(mode);
  }

  Widget _buildModeCard({
    required ReservationMode mode,
    required String title,
    required String description,
    Widget? child,
  }) {
    final selected = _controller.mode == mode;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _controller.isSaving ? null : () => _selectMode(mode),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<ReservationMode>(value: mode),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(description),
                      ],
                    ),
                  ),
                ],
              ),
              if (selected && child != null) ...[const Divider(), child],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSelector() {
    return ListenableBuilder(
      listenable: widget.cartProvider,
      builder: (context, _) {
        final items = widget.cartProvider.items;
        if (widget.cartProvider.isLoading && items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.cartProvider.errorMessage != null) ...[
              Text(
                widget.cartProvider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: () => _runCartAction(widget.cartProvider.refresh),
                child: const Text('Reintentar'),
              ),
            ],
            if (_controller.itemErrors.isNotEmpty) _buildProductErrors(),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Tu carrito está vacío. Agrega productos desde la tienda.',
                ),
              )
            else
              ...items.map(_buildCartItem),
            if (items.isNotEmpty) ...[
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ${_formatMoneyCents(widget.cartProvider.subtotalCents)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            if (_controller.cartError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _controller.cartError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProductErrors() {
    final rejectedProducts = _controller.itemErrors
        .map((error) {
          if (error.name.isNotEmpty) return error.name;
          if (error.productId != null) return 'producto #${error.productId}';
          return error.error;
        })
        .toSet()
        .join(', ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estos productos no están disponibles: $rejectedProducts'),
          TextButton(
            onPressed: _controller.isSaving
                ? null
                : () => _runCartAction(_removeUnavailableProducts),
            child: const Text('Quitar productos no disponibles'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    final itemError = _controller.itemErrorFor(item.productId);
    return CartItemCard(
      item: item,
      isBusy: _controller.isSaving,
      showQuantityControls: false,
      errorMessage: itemError,
      onRemove: () => _runCartAction(
        () => widget.cartProvider.removeProduct(item.productId),
        productId: item.productId,
      ),
    );
  }

  Future<void> _removeUnavailableProducts() async {
    final unavailableIds = _controller.itemErrors
        .map((error) => error.productId)
        .whereType<int>()
        .toSet();
    for (final productId in unavailableIds) {
      await widget.cartProvider.removeProduct(productId);
    }
    _controller.clearItemErrors();
  }

  Future<void> _runCartAction(
    Future<void> Function() action, {
    int? productId,
  }) async {
    try {
      await action();
      if (productId != null) _controller.clearItemErrorFor(productId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(cartErrorMessage(error))));
    }
  }

  String _formatMoneyCents(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  Widget _buildServerErrors() {
    final visibleFields = {'fecha_evento', 'cantidad_personas', 'sala'};
    final otherErrors = _controller.fieldErrors.entries
        .where((entry) => !visibleFields.contains(entry.key))
        .expand((entry) => entry.value);
    final messages = [..._controller.nonFieldErrors, ...otherErrors];
    final generalError = _controller.errorMessage;
    if (generalError != null &&
        generalError.isNotEmpty &&
        !messages.contains(generalError)) {
      messages.add(generalError);
    }
    if (messages.isEmpty && !_controller.isRetryableError) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final message in messages) Text(message),
          if (_controller.isRetryableError) ...[
            if (generalError == null || generalError.isEmpty)
              const Text(genericErrorMessage),
            TextButton(
              onPressed: _controller.isSaving ? null : _submit,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }

  String? _fieldErrorText(String field) {
    final errors = _controller.fieldErrors[field];
    return errors == null || errors.isEmpty ? null : errors.join('\n');
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
