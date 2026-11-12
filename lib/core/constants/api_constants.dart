class ApiConstants {
  // TODO: Reemplaza esta URL con la dirección base de tu API real
  // Para Android Emulator suele ser http://10.0.2.2:8000 o http://10.0.2.2:3000
  // Para dispositivo físico o producción usa https://tu-dominio.com/api
  static const String baseUrl = 'http://127.0.0.1:8000/api/';

  // Endpoints
  static const String loginEndpoint = 'authentication/token/';
  static const String refreshEndpoint = 'authentication/token/refresh/';
  static const String profileEndpoint = 'products/';
  static const String logoutEndpoint = 'authentication/logout/';
  static const String pastriesEndpoint = 'products/';

  static const String productsEndPoint = 'products/';
  static const String ordersEndPoint = 'orders/';
  static const String reservationsEndPoint = 'reservations/';
  static const String reservationsCreateEndPoint = 'reservations/create/';
  static const String hallsEndPoint = 'halls/';
  static const String validateOrderAvailabilityEndPoint = 'orders/validate/';

  static const String registerEndpoint = '/register/';
  static const String verifyOtpEndpoint = '/verify-otp/';
  static const String resendOtpEndpoint = '/resend-otp/';
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // Claves de SharedPreferences
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String userKey = 'auth_user';
}
