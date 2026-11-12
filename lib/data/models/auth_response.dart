import 'user_model.dart';

class AuthResponse {
  final String token;
  final String refreshToken;
  final UserModel user;

  const AuthResponse({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    // Maneja respuestas donde el token viene en 'token', 'access_token', o 'jwt'
    final token = json['access'];
    final refreshToken = json['refresh'];

    // Maneja si el usuario viene dentro de un objeto 'user' o 'data', o en la raíz
    Map<String, dynamic> userMap = {};
    if (json['user'] is Map<String, dynamic>) {
      userMap = json['user'];
    } else if (json['data'] is Map<String, dynamic>) {
      userMap = json['data'];
    } else {
      userMap = json;
    }
    

    return AuthResponse(
      token: token,
      refreshToken: refreshToken,
      user: UserModel.fromJson(userMap),
    );
  }
}
