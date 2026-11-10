import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../constants/api_constants.dart';

class TokenStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Guarda el token JWT o Bearer
  static Future<bool> saveToken(String token) async {
    await init();
    return await _prefs!.setString(ApiConstants.tokenKey, token);
  }

  /// Obtiene el token guardado
  static Future<String?> getToken() async {
    await init();
    return _prefs!.getString(ApiConstants.tokenKey);
  }

  /// Guarda la información del usuario logueado
  static Future<bool> saveUser(UserModel user) async {
    await init();
    final userJson = jsonEncode(user.toJson());
    return await _prefs!.setString(ApiConstants.userKey, userJson);
  }

  /// Obtiene la información del usuario guardado
  static Future<UserModel?> getUser() async {
    await init();
    final userJson = _prefs!.getString(ApiConstants.userKey);
    if (userJson == null) return null;
    try {
      final Map<String, dynamic> map = jsonDecode(userJson);
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Borra el token y los datos de sesión (Logout)
  static Future<void> clearAuth() async {
    await init();
    await _prefs!.remove(ApiConstants.tokenKey);
    await _prefs!.remove(ApiConstants.userKey);
  }

  /// Verifica si existe un token guardado
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
