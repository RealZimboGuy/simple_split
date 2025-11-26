import 'package:flutter_test/flutter_test.dart';
import 'package:simple_split_mobile/models/event.dart';
import 'package:simple_split_mobile/services/database_service.dart';

void main() {
  test('LinkedEventId is preserved after marking event as synced', () async {
    // Setup
    final dbService = DatabaseService();
    
    // Clear database
    await dbService.deleteDatabase();
    
    // Create test event with linkedEventId
    final originalEventId = 'original-event-id';
    final linkedEventId = 'linked-event-id';
    
    final event = Event(
      eventId: originalEventId,
      linkedEventId: linkedEventId,
      groupId: 'test-group',
      userId: 'test-user',
      eventType: Event.expenseDeleted,
      payload: {'test': 'data'},
      createdAt: DateTime.now().toIso8601String(),
    );
    
    // Save event
    await dbService.saveEvent(event, false);
    
    // Act - Mark event as synced
    await dbService.markEventAsSynced(originalEventId);
    
    // Query the event
    final events = await dbService.getEvents('test-group');
    
    // Assert
    expect(events.length, 1);
    expect(events[0].eventId, originalEventId);
    expect(events[0].linkedEventId, linkedEventId);
    
    // Clean up
    await dbService.deleteDatabase();
  });
}
