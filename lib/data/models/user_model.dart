class UserModel {
  final String id;
  final String email;
  final String name;
  final String? role;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['nombres'] ?? '',
      role: json['grupo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
    };
  }
}
