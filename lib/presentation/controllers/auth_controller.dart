import 'package:flutter/foundation.dart';
import '../../core/storage/token_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;
  String? _currentToken;
  bool _isDemoMode = true; // Habilitado por defecto para probar inmediatamente

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  String? get currentToken => _currentToken;
  bool get isDemoMode => _isDemoMode;
  bool get isAuthenticated => _currentToken != null && _currentToken!.isNotEmpty;

  AuthController() {
    checkAuthStatus();
  }

  void toggleDemoMode(bool value) {
    _isDemoMode = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
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
      await TokenStorage.saveUser(response.user);

      _currentToken = response.token;
      _currentUser = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // Remueve el prefijo "Exception: " si existe
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Cierra sesión y borra credenciales locales
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    await TokenStorage.clearAuth();

    _currentToken = null;
    _currentUser = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
