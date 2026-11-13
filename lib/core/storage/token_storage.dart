import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../constants/api_constants.dart';

class TokenStorage {
  static SharedPreferences? _prefs;
  static final ValueNotifier<int> sessionChanges = ValueNotifier(0);

  static void notifySessionChanged() {
    sessionChanges.value++;
  }

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Guarda el token JWT o Bearer
  static Future<bool> saveToken(String token) async {
    return _saveString(ApiConstants.tokenKey, token);
  }

  /// Guarda el refresh token
  static Future<bool> saveRefreshToken(String refreshToken) async {
    return _saveString(ApiConstants.refreshTokenKey, refreshToken);
  }

  /// Obtiene el token guardado
  static Future<String?> getToken() async {
    await init();
    return _prefs!.getString(ApiConstants.tokenKey);
  }

  /// Obtiene el refresh token guardado
  static Future<String?> getRefreshToken() async {
    await init();
    return _prefs!.getString(ApiConstants.refreshTokenKey);
  }

  /// Guarda la información del usuario logueado
  static Future<bool> saveUser(UserModel user) async {
    await init();
    final userJson = jsonEncode(user.toJson());
    return _saveString(ApiConstants.userKey, userJson);
  }

  static Future<bool> _saveString(String key, String value) async {
    await init();
    try {
      final saved = await _prefs!.setString(key, value);
      if (!saved) await _prefs!.reload();
      return saved;
    } catch (error) {
      await _prefs!.reload();
      rethrow;
    }
  }

  /// Obtiene la información del usuario guardado
  static Future<UserModel?> getUser() async {
    await init();
    final userJson = _prefs!.getString(ApiConstants.userKey);
    if (userJson == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(userJson);
      return UserModel.fromJson(map);
    } catch (error) {
      debugPrint('No se pudo leer el usuario guardado: ${error.runtimeType}');
      return null;
    }
  }

  /// Borra el token y los datos de sesión (Logout)
  static Future<void> clearAuth() async {
    await init();
    try {
      for (final key in [
        ApiConstants.tokenKey,
        ApiConstants.refreshTokenKey,
        ApiConstants.userKey,
      ]) {
        if (!await _prefs!.remove(key)) {
          throw StateError('No se pudo borrar la sesión guardada.');
        }
      }
    } catch (error) {
      await _prefs!.reload();
      rethrow;
    } finally {
      notifySessionChanged();
    }
  }

  /// Verifica si existe un token guardado
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
