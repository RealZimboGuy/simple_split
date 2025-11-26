class Group {
  final String groupId;
  final String name;
  final String createdAt;

  Group({
    required this.groupId,
    required this.name,
    required this.createdAt,
  });

  // Create Group from JSON map (API response)
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupId: json['group_id'],
      name: json['name'],
      createdAt: json['created_at'],
    );
  }

  // Convert Group to JSON map (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'name': name,
      'created_at': createdAt,
    };
  }

  // Create Group from database map
  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      groupId: map['group_id'],
      name: map['name'],
      createdAt: map['created_at'],
    );
  }

  // Convert Group to database map
  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'name': name,
      'created_at': createdAt,
    };
  }

  // Copy with method for creating a copy of this Group with some properties changed
  Group copyWith({
    String? groupId,
    String? name,
    String? createdAt,
  }) {
    return Group(
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
