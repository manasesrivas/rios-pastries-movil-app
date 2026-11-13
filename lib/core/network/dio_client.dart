import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../storage/token_storage.dart';
import '../utils/error_handler.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DioClient {
  DioClient({Dio? dio, Dio? refreshDio})
    : dio = dio ?? Dio(_baseOptions()),
      _refreshDio = refreshDio ?? Dio(_baseOptions()) {
    this.dio.interceptors.add(_AuthInterceptor(_refreshDio));
  }

  static DioClient? _instance;
  final Dio dio;
  final Dio _refreshDio;

  static DioClient get instance => _instance ??= DioClient();

  static BaseOptions _baseOptions() => BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  );

  static String handleDioError(DioException error) {
    logError(error, operation: 'Error de red');
    return genericErrorMessage;
  }
}

class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._refreshDio);

  final Dio _refreshDio;
  String? _lastExpiredToken;
  String? _lastRefreshedToken;

  bool _isAuthenticationRequest(RequestOptions options) {
    final path = options.uri.path;
    return [
      ApiConstants.loginEndpoint,
      ApiConstants.refreshEndpoint,
      ApiConstants.logoutEndpoint,
      ApiConstants.registerEndpoint,
      ApiConstants.verifyOtpEndpoint,
      ApiConstants.resendOtpEndpoint,
    ].any((endpoint) => path.endsWith('/${endpoint.replaceFirst(RegExp(r'^/'), '')}'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      if (!_isAuthenticationRequest(options) ||
          options.uri.path.endsWith('/${ApiConstants.logoutEndpoint}')) {
        final token = await TokenStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    } catch (error) {
      logError(error, operation: 'No se pudo preparar la solicitud');
      handler.reject(DioException(requestOptions: options, error: error));
    }
  }

  @override
  Future<void> onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final authorization = error.requestOptions.headers['Authorization'];
    final responseData = error.response?.data;
    if (error.response?.statusCode != 401 ||
        responseData is! Map ||
        responseData['code'] != 'token_not_valid' ||
        _isAuthenticationRequest(error.requestOptions) ||
        authorization is! String ||
        !authorization.startsWith('Bearer ')) {
      handler.next(error);
      return;
    }

    final expiredToken = authorization.substring('Bearer '.length);
    try {
      final currentToken = await TokenStorage.getToken();
      if (currentToken != expiredToken) {
        if (expiredToken == _lastExpiredToken &&
            currentToken != null &&
            currentToken == _lastRefreshedToken) {
          await _retry(error, currentToken, handler);
        } else {
          handler.next(error);
        }
        return;
      }

      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('No se encontró un token de renovación.');
        handler.next(error);
        return;
      }

      Response<dynamic> response;
      try {
        response = await _refreshDio.post(
          ApiConstants.refreshEndpoint,
          data: {'refresh': refreshToken},
        );
      } on DioException catch (refreshError) {
        logError(refreshError, operation: 'No se pudo renovar la sesión');
        final data = refreshError.response?.data;
        final invalidRefresh = refreshError.response?.statusCode == 401 ||
            (refreshError.response?.statusCode == 400 &&
                data is Map &&
                data['code'] == 'token_not_valid');
        if (invalidRefresh &&
            await TokenStorage.getToken() == expiredToken &&
            await TokenStorage.getRefreshToken() == refreshToken) {
          await TokenStorage.clearAuth();
        }
        handler.reject(refreshError);
        return;
      }

      final data = response.data;
      final access = data is Map ? data['access'] : null;
      final rotatedRefresh = data is Map ? data['refresh'] : null;
      if (access is! String || access.isEmpty ||
          (rotatedRefresh != null && (rotatedRefresh is! String || rotatedRefresh.isEmpty))) {
        throw const FormatException('Respuesta de renovación inválida.');
      }
      if (await TokenStorage.getToken() != expiredToken ||
          await TokenStorage.getRefreshToken() != refreshToken) {
        handler.next(error);
        return;
      }

      if (rotatedRefresh is String &&
          !await TokenStorage.saveRefreshToken(rotatedRefresh)) {
        throw StateError('No se pudo guardar el refresh token.');
      }
      if (!await TokenStorage.saveToken(access)) {
        throw StateError('No se pudo guardar el token de acceso.');
      }
      _lastExpiredToken = expiredToken;
      _lastRefreshedToken = access;
      TokenStorage.notifySessionChanged();
      await _retry(error, access, handler);
    } catch (refreshError) {
      logError(refreshError, operation: 'No se pudo renovar la sesión');
      handler.reject(
        DioException(requestOptions: error.requestOptions, error: refreshError),
      );
    }
  }

  Future<void> _retry(
    DioException original,
    String token,
    ErrorInterceptorHandler handler,
  ) async {
    if (original.requestOptions.data is FormData ||
        original.requestOptions.data is Stream) {
      debugPrint('No se puede repetir automáticamente el cuerpo de la solicitud.');
      handler.next(original);
      return;
    }
    final options = original.requestOptions.copyWith(
      headers: {...original.requestOptions.headers, 'Authorization': 'Bearer $token'},
    );
    try {
      handler.resolve(await _refreshDio.fetch<dynamic>(options));
    } on DioException catch (error) {
      handler.reject(error);
    }
  }
}
