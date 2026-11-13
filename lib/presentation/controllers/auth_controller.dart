import 'package:flutter/foundation.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/error_handler.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  String? _pendingEmail; // correo esperando verificación OTP
  String? get pendingEmail => _pendingEmail;

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;
  String? _currentToken;
  bool _isDemoMode = true; // Habilitado por defecto para probar inmediatamente
  bool _disposed = false;
  int _sessionGeneration = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  String? get currentToken => _currentToken;
  bool get isDemoMode => _isDemoMode;
  bool get isAuthenticated => _currentToken != null && _currentToken!.isNotEmpty;

  AuthController() {
    TokenStorage.sessionChanges.addListener(_syncSession);
    checkAuthStatus();
  }

  Future<void> _syncSession() async {
    final generation = ++_sessionGeneration;
    try {
      final token = await TokenStorage.getToken();
      final user = await TokenStorage.getUser();
      if (_disposed || generation != _sessionGeneration) return;
      _currentToken = token;
      _currentUser = user;
      notifyListeners();
    } catch (error) {
      logError(error, operation: 'No se pudo sincronizar la sesión');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    TokenStorage.sessionChanges.removeListener(_syncSession);
    super.dispose();
  }

  void toggleDemoMode(bool value) {
    _isDemoMode = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Crea el usuario (queda inactivo) y el backend envía el OTP al correo
Future<bool> register({
  required String username,
  required String email,
  required String password,
}) async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    await _authService.register(
      username: username,
      email: email,
      password: password,
      useMock: _isDemoMode,
    );
    _pendingEmail = email;
    _isLoading = false;
    notifyListeners();
    return true; // la UI navega a la pantalla del código
  } catch (e) {
    _isLoading = false;
    logError(e, operation: 'No se pudo crear la cuenta');
    _errorMessage = genericErrorMessage;
    notifyListeners();
    return false;
  }
}

/// Verifica el OTP; si es correcto, el backend devuelve los tokens y entramos directo
Future<bool> verifyOtp({required String code}) async {
  if (_pendingEmail == null) return false;

  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    final response = await _authService.verifyOtp(
      email: _pendingEmail!,
      code: code,
      useMock: _isDemoMode,
    );

    await TokenStorage.saveToken(response.token);
    await TokenStorage.saveRefreshToken(response.refreshToken);
    await TokenStorage.saveUser(response.user);

    _currentToken = response.token;
    _currentUser = response.user;
    _pendingEmail = null;
    _isLoading = false;
    notifyListeners();
    return true;
  } catch (e) {
    _isLoading = false;
    logError(e, operation: 'No se pudo verificar el código');
    _errorMessage = genericErrorMessage;
    notifyListeners();
    return false;
  }
}

/// Reenvía un código nuevo al correo pendiente
Future<bool> resendOtp() async {
  if (_pendingEmail == null) return false;

  try {
    await _authService.resendOtp(email: _pendingEmail!, useMock: _isDemoMode);
    return true;
  } catch (e) {
    logError(e, operation: 'No se pudo reenviar el código');
    _errorMessage = genericErrorMessage;
    notifyListeners();
    return false;
  }
}

  /// Verifica si ya hay una sesión guardada localmente
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await TokenStorage.getToken();
      final user = await TokenStorage.getUser();

      if (token != null && token.isNotEmpty) {
        _currentToken = token;
        _currentUser = user;
      } else {
        _currentToken = null;
        _currentUser = null;
      }
    } catch (e) {
      logError(e, operation: 'No se pudo restaurar la sesión');
      _currentToken = null;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ejecuta el proceso de inicio de sesión
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        email: email,
        password: password,
        useMock: _isDemoMode,
      );

      // Guardar token y datos del usuario en almacenamiento local
      await TokenStorage.saveToken(response.token);
      await TokenStorage.saveRefreshToken(response.refreshToken);
      await TokenStorage.saveUser(response.user);

      _currentToken = response.token;
      _currentUser = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      logError(e, operation: 'No se pudo iniciar sesión');
      _errorMessage = genericErrorMessage;
      notifyListeners();
      return false;
    }
  }

  /// Cierra sesión y borra credenciales locales
  Future<void> logout() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final refreshToken = await TokenStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('No se encontró refreshToken, cerrando sesión solo localmente.');
      } else {
        await _authService.logout(refreshToken);
      }

    } catch (e) {
      logError(e, operation: 'No se pudo cerrar sesión');
      _errorMessage = genericErrorMessage;
    } finally {
      try {
        await TokenStorage.clearAuth();
        _currentToken = null;
        _currentUser = null;
      } catch (error) {
        logError(error, operation: 'No se pudo limpiar la sesión');
        _errorMessage = genericErrorMessage;
      }
      _isLoading = false;
      notifyListeners();
    }
  }
}