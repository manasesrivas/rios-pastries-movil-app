import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/error_handler.dart';
import '../models/auth_response.dart';

class AuthService {
  final Dio _dio = DioClient.instance.dio;

  /// Crea el usuario (queda inactivo) y el backend envía el OTP al correo
  Future<void> register({
    required String username,
    required String email,
    required String password,
    bool useMock = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.registerEndpoint,
        data: {
          'username': username,
          'email': email,
          'password': password,
        },
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Respuesta inesperada del servidor: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception(DioClient.handleDioError(e));
    } catch (e) {
      logError(e, operation: 'No se pudo crear la cuenta');
      throw Exception(genericErrorMessage);
    }
  }

  /// Verifica el código; si es correcto, el backend devuelve los tokens
  Future<AuthResponse> verifyOtp({
    required String email,
    required String code,
    bool useMock = false,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyOtpEndpoint,
        data: {
          'email': email,
          'code': code,
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
      logError(e, operation: 'No se pudo verificar el código');
      throw Exception(genericErrorMessage);
    }
  }

  /// Pide un código nuevo para el correo pendiente
  Future<void> resendOtp({
    required String email,
    bool useMock = false,
  }) async {
    try {
      await _dio.post(
        ApiConstants.resendOtpEndpoint,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw Exception(DioClient.handleDioError(e));
    } catch (e) {
      logError(e, operation: 'No se pudo reenviar el código');
      throw Exception(genericErrorMessage);
    }
  }

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
      logError(e, operation: 'No se pudo iniciar sesión');
      throw Exception(genericErrorMessage);
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
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post(
        ApiConstants.logoutEndpoint,
        data: {'refresh': refreshToken},
      );
    } on DioException catch (error) {
      throw Exception(DioClient.handleDioError(error));
    }
  }
}
