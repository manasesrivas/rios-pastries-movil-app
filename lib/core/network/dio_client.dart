import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/token_storage.dart';

class DioClient {
  static DioClient? _instance;
  late final Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Interceptor para inyectar automáticamente el token Bearer en cada petición
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await TokenStorage.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Token expirado o no autorizado: limpiar sesión
            await TokenStorage.clearAuth();
          }
          return handler.next(error);
        },
      ),
    );
  }

  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  /// Traduce excepciones de Dio a mensajes claros en español
  static String handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Tiempo de espera agotado. Verifica tu conexión a internet.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;

        // Si la API devuelve un mensaje de error personalizado
        if (responseData is Map && responseData['message'] != null) {
          return responseData['message'].toString();
        }

        print(responseData);

        if (statusCode == 400) return 'Solicitud inválida. Revisa los datos enviados.';
        if (statusCode == 401) return 'Credenciales incorrectas o sesión expirada.';
        if (statusCode == 403) return 'Acceso denegado.';
        if (statusCode == 404) return 'Recurso no encontrado en el servidor.';
        if (statusCode != null && statusCode >= 500) {
          return 'Error en el servidor ($statusCode). Intenta de nuevo más tarde.';
        }
        return 'Error en la respuesta del servidor ($statusCode).';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Revisa tu conexión o la URL base.';
      case DioExceptionType.cancel:
        return 'La solicitud fue cancelada.';
      default:
        return 'Ocurrió un error inesperado al comunicarse con el servidor.';
    }
  }
}
