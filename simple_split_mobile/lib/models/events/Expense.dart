class Expense {
  final String description;
  final DateTime dateTime;
  final String splitType;
  final String currency;
  final double total;
  final List<PaidBy> paidBy;
  final List<PaidFor> paidFor;

  Expense({
    required this.description,
    required this.dateTime,
    required this.splitType,
    required this.currency,
    required this.total,
    required this.paidBy,
    required this.paidFor,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      description: json['description'],
      dateTime: DateTime.parse(json['date_time']),
      splitType: json['split_type'],
      currency: json['currency'],
      total: (json['total'] as num).toDouble(),
      paidBy: (json['paid_by'] as List)
          .map((e) => PaidBy.fromJson(e))
          .toList(),
      paidFor: (json['paid_for'] as List)
          .map((e) => PaidFor.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'date_time': dateTime.toIso8601String(),
      'split_type': splitType,
      'currency': currency,
      'total': total,
      'paid_by': paidBy.map((e) => e.toJson()).toList(),
      'paid_for': paidFor.map((e) => e.toJson()).toList(),
    };
  }
}

class PaidBy {
  final String userId;
  final double amount;

  PaidBy({
    required this.userId,
    required this.amount,
  });

  factory PaidBy.fromJson(Map<String, dynamic> json) {
    return PaidBy(
      userId: json['user_id'],
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': amount,
    };
  }
}

class PaidFor {
  final String userId;
  final double amount;

  PaidFor({
    required this.userId,
    required this.amount,
  });

  factory PaidFor.fromJson(Map<String, dynamic> json) {
    return PaidFor(
      userId: json['user_id'],
      amount: (json['amount'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': amount,
    };
  }
}
