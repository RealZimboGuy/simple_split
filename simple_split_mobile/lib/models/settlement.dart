import '../models/user.dart';

class Settlement {
  final User fromUser;
  final User toUser;
  final double amount;
  
  Settlement({
    required this.fromUser, 
    required this.toUser, 
    required this.amount
  });
}
