import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/reservation_api_error.dart';
import '../../data/models/reservation_create_request.dart';
import '../../data/models/reservation_model.dart';
import '../../data/services/reservation_service.dart';
import 'auth_controller.dart';

enum ReservationMode { soloReservacion, conProductos }

enum ReservationControllerState { idle, loading, success, error }

class ReservationController extends ChangeNotifier {
  ReservationController({
    required this.reservationService,
    this.authController,
  });

  final ReservationService reservationService;
  final AuthController? authController;

  ReservationMode _mode = ReservationMode.soloReservacion;
  ReservationControllerState _state = ReservationControllerState.idle;
  List<HallModel> _halls = [];
  Map<String, List<String>> _fieldErrors = {};
  List<String> _nonFieldErrors = [];
  List<ReservationApiItemError> _itemErrors = [];
  Reservation? _createdReservation;
  String? _hallsError;
  String? _errorMessage;
  String? _cartError;
  bool _isLoadingHalls = false;
  bool _isRetryableError = false;
  bool _sessionExpired = false;
  bool _disposed = false;

  ReservationMode get mode => _mode;
  ReservationControllerState get state => _state;
  List<HallModel> get halls => List.unmodifiable(_halls);
  Map<String, List<String>> get fieldErrors => Map.unmodifiable(_fieldErrors);
  List<String> get nonFieldErrors => List.unmodifiable(_nonFieldErrors);
  List<ReservationApiItemError> get itemErrors =>
      List.unmodifiable(_itemErrors);
  Reservation? get createdReservation => _createdReservation;
  String? get hallsError => _hallsError;
  String? get errorMessage => _errorMessage;
  String? get cartError => _cartError;
  bool get isLoadingHalls => _isLoadingHalls;
  bool get isSaving => _state == ReservationControllerState.loading;
  bool get isRetryableError => _isRetryableError;
  bool get sessionExpired => _sessionExpired;

  Future<void> loadHalls() async {
    _isLoadingHalls = true;
    _hallsError = null;
    _notifyListeners();
    try {
      _halls = await reservationService.getHalls();
    } catch (error) {
      _hallsError = _errorText(error);
    } finally {
      _isLoadingHalls = false;
      _notifyListeners();
    }
  }

  void setMode(ReservationMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    _cartError = null;
    _notifyListeners();
  }

  void clearItemErrorFor(int productId) {
    _itemErrors = _itemErrors
        .where((error) => error.productId != productId)
        .toList();
    _notifyListeners();
  }

  void clearItemErrors() {
    _itemErrors = [];
    _notifyListeners();
  }

  String? itemErrorFor(int productId) {
    final messages = _itemErrors
        .where((error) => error.productId == productId)
        .map((error) => error.error)
        .where((message) => message.isNotEmpty);
    return messages.isEmpty ? null : messages.join('\n');
  }

  void clearFieldError(String field) {
    if (_fieldErrors.remove(field) != null) _notifyListeners();
  }

  Future<bool> submit({
    required DateTime fechaEvento,
    required int cantidadPersonas,
    required int sala,
    required List<CartItem> cartItems,
    int? reservationId,
  }) async {
    if (_state == ReservationControllerState.loading) return false;
    _clearErrors();

    if (_mode == ReservationMode.conProductos && cartItems.isEmpty) {
      _cartError =
          "Agrega al menos un producto o elige 'Solo crear reservación'.";
      _state = ReservationControllerState.error;
      _notifyListeners();
      return false;
    }

    final request = ReservationCreateRequest(
      fechaEvento: fechaEvento,
      cantidadPersonas: cantidadPersonas,
      sala: sala,
      items: _mode == ReservationMode.conProductos
          ? cartItems
                .map(
                  (item) => ReservationItemInput(
                    productId: item.productId,
                    quantity: item.quantity,
                  ),
                )
                .toList()
          : const [],
    );

    _state = ReservationControllerState.loading;
    _notifyListeners();
    try {
      if (reservationId == null) {
        _createdReservation = await reservationService.createReservation(
          request,
        );
      } else {
        await reservationService.updateReservation(
          id: reservationId,
          request: request,
        );
      }
      _state = ReservationControllerState.success;
      _notifyListeners();
      return true;
    } on ReservationApiException catch (error) {
      _fieldErrors = error.error.fieldErrors;
      _nonFieldErrors = error.error.nonFieldErrors;
      _itemErrors = error.error.itemErrors;
      _errorMessage = _nonFieldErrors.isEmpty
          ? null
          : _nonFieldErrors.join('\n');
      _state = ReservationControllerState.error;
      _notifyListeners();
      return false;
    } on DioException catch (error) {
      _state = ReservationControllerState.error;
      _isRetryableError = _isRetryable(error);
      if (error.response?.statusCode == 401) {
        _sessionExpired = true;
        _errorMessage = 'Tu sesión expiró. Inicia sesión para continuar.';
        await authController?.logout();
      } else {
        _errorMessage = DioClient.handleDioError(error);
      }
      _notifyListeners();
      return false;
    } catch (error) {
      _state = ReservationControllerState.error;
      _errorMessage = _errorText(error);
      _notifyListeners();
      return false;
    }
  }

  void _clearErrors() {
    _fieldErrors = {};
    _nonFieldErrors = [];
    _itemErrors = [];
    _errorMessage = null;
    _cartError = null;
    _isRetryableError = false;
    _sessionExpired = false;
  }

  bool _isRetryable(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse =>
        error.response?.statusCode != null &&
            error.response!.statusCode! >= 500,
      _ => false,
    };
  }

  String _errorText(Object error) {
    if (error is DioException) return DioClient.handleDioError(error);
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
