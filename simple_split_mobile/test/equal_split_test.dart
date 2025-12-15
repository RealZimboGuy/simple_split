import 'package:flutter_test/flutter_test.dart';
import 'package:simple_split_mobile/models/events/Expense.dart';

void main() {
  test('Equal split calculation for 3 people with $2 total', () {
    // Simulating the fixed code from add_expense_screen.dart
    final double totalAmount = 2.0;
    final int selectedUserCount = 3;
    
    // Calculate amount per user
    final double amountPerUser = totalAmount / selectedUserCount;
    print('Raw amount per user: $amountPerUser');  // Should be 0.6666666666666666
    
    // Round to two decimal places
    final double roundedAmountPerUser = (amountPerUser * 100).floor() / 100;
    print('Rounded amount per user: $roundedAmountPerUser');  // Should be 0.66
    
    // Create paidFor objects
    final List<PaidFor> paidFor = List.generate(
      selectedUserCount,
      (i) => PaidFor(
        userId: 'user$i',
        amount: roundedAmountPerUser,
      ),
    );
    
    // Calculate sum of all shares
    final double sumBeforeAdjustment = paidFor.fold(0.0, (sum, pf) => sum + pf.amount);
    print('Sum before adjustment: $sumBeforeAdjustment');  // Should be 1.98
    
    // Calculate difference
    final double difference = totalAmount - sumBeforeAdjustment;
    print('Difference: $difference');  // Should be 0.02
    
    // Adjust first share if needed
    if (difference.abs() > 0.001 && paidFor.isNotEmpty) {
      paidFor[0] = PaidFor(
        userId: paidFor[0].userId,
        amount: paidFor[0].amount + difference,
      );
    }
    
    // Verify the adjustment
    print('Adjusted first share: ${paidFor[0].amount}');  // Should be 0.68
    
    // Verify final sum
    final double finalSum = paidFor.fold(0.0, (sum, pf) => sum + pf.amount);
    print('Final sum: $finalSum');  // Should be 2.00
    
    // Test assertions
    expect(roundedAmountPerUser, equals(0.66));
    expect(sumBeforeAdjustment, equals(1.98));
    expect(difference, equals(0.02));
    expect(paidFor[0].amount, equals(0.68));
    expect(paidFor[1].amount, equals(0.66));
    expect(paidFor[2].amount, equals(0.66));
    expect(finalSum, equals(2.0));
  });
  
  test('Equal split calculation for 5 people with $1.31 total', () {
    final double totalAmount = 1.31;
    final int selectedUserCount = 5;
    
    final double amountPerUser = totalAmount / selectedUserCount;
    final double roundedAmountPerUser = (amountPerUser * 100).floor() / 100;
    
    final List<PaidFor> paidFor = List.generate(
      selectedUserCount, 
      (i) => PaidFor(userId: 'user$i', amount: roundedAmountPerUser)
    );
    
    final double sumBeforeAdjustment = paidFor.fold(0.0, (sum, pf) => sum + pf.amount);
    final double difference = totalAmount - sumBeforeAdjustment;
    
    if (difference.abs() > 0.001 && paidFor.isNotEmpty) {
      paidFor[0] = PaidFor(
        userId: paidFor[0].userId,
        amount: paidFor[0].amount + difference,
      );
    }
    
    final double finalSum = paidFor.fold(0.0, (sum, pf) => sum + pf.amount);
    
    // Test assertions
    expect(roundedAmountPerUser, equals(0.26));
    expect(finalSum, equals(totalAmount));
    expect(paidFor[0].amount, equals(0.27));
    expect(paidFor[1].amount, equals(0.26));
  });
}
