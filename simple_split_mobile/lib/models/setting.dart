class Setting {
  final String settingKey;
  final String settingValue;

  Setting({
    required this.settingKey,
    required this.settingValue,
  });

  // Create User from JSON map (API response)
  factory Setting.fromJson(Map<String, dynamic> json) {
    return Setting(
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
  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
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
  Setting copyWith({
    String? settingKey,
    String? settingValue,
  }) {
    return Setting(
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
    );
  }

  // Event types constants
  static const String userId = 'USER_ID';
}
