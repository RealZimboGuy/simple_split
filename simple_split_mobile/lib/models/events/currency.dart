class Currency {
  final String currency;
  final String dateTime;

  Currency({required this.currency, required this.dateTime});


  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      currency: json['currency'],
      dateTime: json['date_time'],
    );
  }

}
