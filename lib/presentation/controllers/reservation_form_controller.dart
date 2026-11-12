import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';
import '../../data/models/reservation_model.dart';
import '../../data/services/reservation_service.dart';

class ReservationFormController extends ChangeNotifier {
  ReservationFormController({ReservationService? reservationService})
    : _reservationService = reservationService ?? ReservationService();

  final ReservationService _reservationService;

  List<HallModel> _halls = [];
  String? _hallsError;
  String? _errorMessage;
  final Map<String, String> _fieldErrors = {};
  bool _isLoadingHalls = false;
  bool _isSaving = false;
  bool _isDisposed = false;

  List<HallModel> get halls => _halls;
  String? get hallsError => _hallsError;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);
  bool get isLoadingHalls => _isLoadingHalls;
  bool get isSaving => _isSaving;

  Future<void> loadHalls() async {
    _isLoadingHalls = true;
    _hallsError = null;
    _notifyListeners();

    try {
      _halls = await _reservationService.getHalls();
    } catch (error) {
      _hallsError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingHalls = false;
      _notifyListeners();
    }
  }

  Future<bool> save(Reservation reservation) async {
    _isSaving = true;
    _errorMessage = null;
    _fieldErrors.clear();
    _notifyListeners();

    try {
      final id = reservation.id;
      if (id == null) {
        await _reservationService.createReservation(reservation);
      } else {
        await _reservationService.updateReservation(
          id: id,
          reservation: reservation,
        );
      }
      return true;
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 400) {
        _mapBackendErrors(error.response?.data, error);
      } else {
        _errorMessage = error is DioException
            ? DioClient.handleDioError(error)
            : error.toString().replaceFirst('Exception: ', '');
      }
      return false;
    } finally {
      _isSaving = false;
      _notifyListeners();
    }
  }

  void clearFieldError(String field) {
    if (_fieldErrors.remove(field) != null) {
      _notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  void _mapBackendErrors(dynamic data, DioException error) {
    if (data is! Map) {
      _errorMessage = DioClient.handleDioError(error);
      return;
    }

    final otherErrors = <String>[];
    for (final entry in data.entries) {
      final field = entry.key.toString();
      final messages = _messages(entry.value);
      if (messages.isEmpty) continue;

      if (messages.any(_isReservationConflict)) {
        _fieldErrors['sala'] =
            'Esta sala ya tiene una reservación activa para esa fecha.';
        continue;
      }

      switch (field) {
        case 'fecha_evento':
        case 'cantidad_personas':
        case 'sala':
          _fieldErrors[field] = messages.join(' ');
          break;
        case 'non_field_errors':
          otherErrors.addAll(messages);
          break;
        default:
          otherErrors.addAll(messages);
          break;
      }
    }

    if (otherErrors.isNotEmpty) {
      _errorMessage = otherErrors.join(' ');
    } else if (_fieldErrors.isEmpty) {
      _errorMessage = DioClient.handleDioError(error);
    }
  }

  List<String> _messages(dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is Iterable) {
      return value.expand(_messages).toList();
    }
    if (value is Map) {
      return value.values.expand(_messages).toList();
    }
    return [value.toString()];
  }

  bool _isReservationConflict(String message) {
    final normalized = message
        .toLowerCase()
        .replaceAll('ó', 'o')
        .replaceAll('í', 'i')
        .replaceAll('á', 'a');
    return normalized.contains('unique') ||
        normalized.contains('already exists') ||
        (normalized.contains('reservacion') &&
            normalized.contains('activa')) ||
        (normalized.contains('sala') &&
            normalized.contains('fecha') &&
            (normalized.contains('existe') ||
                normalized.contains('unica')));
  }
}
