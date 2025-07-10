class User {
  final String id;
  final String username;
  final String? name;
  final String? role;
  final String token;
  final String? guruId; // ID guru untuk keperluan absensi

  User({
    required this.id,
    required this.username,
    this.name,
    this.role,
    required this.token,
    this.guruId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      name: json['name'],
      role: json['role'],
      token: json['token'] ?? '',
      guruId: json['guruId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
      'token': token,
      'guruId': guruId,
    };
  }
} 