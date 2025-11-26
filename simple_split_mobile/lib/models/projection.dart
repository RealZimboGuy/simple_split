class Projection {
  final String settingKey;
  final String settingValue;

  Projection({
    required this.settingKey,
    required this.settingValue,
  });

  // Create User from JSON map (API response)
  factory Projection.fromJson(Map<String, dynamic> json) {
    return Projection(
      settingKey: json['setting_key'],
      settingValue: json['setting_value'],
    );
  }

  // Convert User to JSON map (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'setting_key': settingKey,
      'setting_value': settingValue,
    };
  }

  // Create User from database map
  factory Projection.fromMap(Map<String, dynamic> map) {
    return Projection(
      settingKey: map['setting_key'],
      settingValue: map['setting_value'],
    );
  }

  // Convert User to database map
  Map<String, dynamic> toMap() {
    return {
      'setting_key': settingKey,
      'setting_value': settingValue,
    };
  }

  // Copy with method for creating a copy of this User with some properties changed
  Projection copyWith({
    String? settingKey,
    String? settingValue,
  }) {
    return Projection(
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
    );
  }

  // projection types constants
  static const String suffixSummary = '_summary';
  static const String suffixUsers = '_group';
}
