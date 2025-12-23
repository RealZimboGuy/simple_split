import 'package:flutter_test/flutter_test.dart';
import 'package:simple_split_mobile/models/user.dart';
import 'package:simple_split_mobile/models/projections/projection_group.dart';

void main() {
  group('User deduplication tests', () {
    test('User equality works correctly based on userId', () {
      final user1 = User(
        userId: '019b4aac-2eed-7238-a881-f2483543059d',
        name: 'Test User',
        createdAt: '2025-12-23T13:00:00.000Z',
      );
      
      final user2 = User(
        userId: '019b4aac-2eed-7238-a881-f2483543059d', // Same ID
        name: 'Test User Updated', // Different name
        createdAt: '2025-12-23T14:00:00.000Z', // Different timestamp
      );
      
      final user3 = User(
        userId: '019b4aac-2eed-7238-a881-f2483543059e', // Different ID
        name: 'Test User',
        createdAt: '2025-12-23T13:00:00.000Z',
      );
      
      // Same userId should be equal
      expect(user1 == user2, true);
      
      // Different userId should not be equal
      expect(user1 == user3, false);
      
      // hashCode should be the same for equal users
      expect(user1.hashCode == user2.hashCode, true);
      
      // hashCode should be different for non-equal users
      expect(user1.hashCode == user3.hashCode, false);
    });
    
    test('User deduplication works with collections', () {
      final user1 = User(
        userId: '019b4aac-2eed-7238-a881-f2483543059d',
        name: 'Test User',
        createdAt: '2025-12-23T13:00:00.000Z',
      );
      
      final user2 = User(
        userId: '019b4aac-2eed-7238-a881-f2483543059d', // Same ID
        name: 'Test User Updated',
        createdAt: '2025-12-23T14:00:00.000Z',
      );
      
      final user3 = User(
        userId: 'different-id',
        name: 'Another User',
        createdAt: '2025-12-23T13:00:00.000Z',
      );
      
      // Test with Set to verify deduplication
      final userSet = <User>{user1, user2, user3};
      expect(userSet.length, 2); // Should deduplicate user1 and user2
      
      // Test with Map to verify deduplication like in AddExpenseScreen
      final Map<String, User> uniqueUsers = {};
      for (var user in [user1, user2, user3]) {
        uniqueUsers[user.userId] = user;
      }
      expect(uniqueUsers.length, 2);
      
      // The second user with the same ID should replace the first one
      expect(uniqueUsers[user1.userId]?.name, 'Test User Updated');
    });
  });
}
