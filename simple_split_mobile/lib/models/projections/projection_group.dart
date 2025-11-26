import 'dart:ffi';

import 'package:simple_split_mobile/models/user.dart';

class ProjectionGroup {
  final List<User> users;
  final List<String> currencies;
  final Map<String, double> debts;

  ProjectionGroup({
    required this.users,
    required this.currencies,
    Map<String, double>? debts,
  }) : debts = debts ?? {};
  
  /// Calculate net positions for each user by currency
  /// Returns a map where keys are "userId->currency" and values are net amounts
  /// Positive value means the user is owed money, negative means they owe money
  Map<String, double> calculateNetPositions() {
    Map<String, double> netPositions = {};
    
    // Process each debt entry
    for (var entry in debts.entries) {
      final parts = entry.key.split('->');
      if (parts.length < 3) continue;
      
      final fromId = parts[0];
      final currency = parts[1]; 
      final toId = parts[2];
      final amount = entry.value;
      
      // Skip very small amounts
      if (amount.abs() < 0.01) continue;
      
      // Update the debtor's (fromId) position (negative as they owe money)
      final fromKey = "$fromId->$currency";
      netPositions[fromKey] = (netPositions[fromKey] ?? 0) - amount;
      
      // Update the creditor's (toId) position (positive as they are owed money)
      final toKey = "$toId->$currency";
      netPositions[toKey] = (netPositions[toKey] ?? 0) + amount;
    }
    
    return netPositions;
  }


  /// Add amount to the debt map using key "fromUser -> toUser"
  void addDebt(String fromUser, String currency, String toUser, double amount) {
    final key = "$fromUser->$currency->$toUser";
    debts[key] = (debts[key] ?? 0) + amount;
  }

  // Create User from JSON map (API response)
// dart
factory ProjectionGroup.fromJson(Map<String, dynamic> json) {
  return ProjectionGroup(
    users: (json['users'] as List<dynamic>)
        .map((u) => User.fromJson(u as Map<String, dynamic>))
        .toList(),
    currencies: List<String>.from(json['currencies'] as List<dynamic>),
    debts: json['debts'] != null 
        ? Map<String, double>.from(json['debts'] as Map<dynamic, dynamic>)
        : null,
  );
}

  // Convert User to JSON map (for API requests)
  // Returns a JSON-serializable Map
  Map<String, dynamic> toJson() {
    return {
      'users': users.map((u) => u.toJson()).toList(),
      'currencies': currencies,
      'debts': debts,
    };
  }

  // Create User from database map
// dart
factory ProjectionGroup.fromMap(Map<String, dynamic> map) {
  return ProjectionGroup(
    users: (map['users'] as List<dynamic>)
        .map((u) => User.fromJson(u as Map<String, dynamic>))
        .toList(),
    currencies: List<String>.from(map['currencies'] as List<dynamic>),
    debts: map['debts'] != null 
        ? Map<String, double>.from(map['debts'] as Map<dynamic, dynamic>)
        : null,
  );
}

  // Convert User to database map
  Map<String, dynamic> toMap() {
    return {
      'users': users.map((u) => u.toJson()).toList(),
      'currencies': currencies,
      'debts': debts,
    };
  }


}
