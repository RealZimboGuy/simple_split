class User {
  final String userId;
  final String name;
  final String createdAt;

  User({
    required this.userId,
    required this.name,
    required this.createdAt,
  });

  // Create User from JSON map (API response)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      name: json['name'],
      createdAt: json['created_at'],
    );
  }

  // Convert User to JSON map (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
      'created_at': createdAt,
    };
  }

  // Create User from database map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['user_id'],
      name: map['name'],
      createdAt: map['created_at'],
    );
  }

  // Convert User to database map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'created_at': createdAt,
    };
  }

  // Copy with method for creating a copy of this User with some properties changed
  User copyWith({
    String? userId,
    String? name,
    String? createdAt,
  }) {
    return User(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
