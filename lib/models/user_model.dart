class User {
  final String id;
  final String username;
  final String token;
  final String role;
  final String? name;

  User({
    required this.id,
    required this.username,
    required this.token,
    required this.role,
    this.name,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      token: json['token'] ?? '',
      role: json['role'] ?? 'user',
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'token': token,
      'role': role,
      'name': name,
    };
  }
} 