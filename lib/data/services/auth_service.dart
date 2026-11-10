import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/auth_response.dart';

class AuthService {
  final Dio _dio = DioClient.instance.dio;

  Future<AuthResponse> login({
    required String email,
    required String password,
    bool useMock = false,
  }) async {

    try {
      final response = await _dio.post(
        ApiConstants.loginEndpoint,
        data: {
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return AuthResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw Exception('Respuesta inesperada del servidor: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception(DioClient.handleDioError(e));
    } catch (e) {
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// Ejemplo de llamada autenticada usando el interceptor de Dio
  Future<Map<String, dynamic>> fetchProtectedData() async {
    try {
      final response = await _dio.get(ApiConstants.profileEndpoint);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(DioClient.handleDioError(e));
    }
  }

  /// Cierre de sesión en servidor (opcional)
  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logoutEndpoint);
    } catch (_) {
      // Ignora error si el backend no tiene endpoint de logout activo
    }
  }
}
