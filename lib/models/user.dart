class User {
  final int? id;
  final String username;
  final DateTime createdAt;
  final String? settingsJson;

  User({
    this.id,
    required this.username,
    DateTime? createdAt,
    this.settingsJson,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'created_at': createdAt.toIso8601String(),
      'settings_json': settingsJson,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      createdAt: DateTime.parse(map['created_at']),
      settingsJson: map['settings_json'],
    );
  }
}