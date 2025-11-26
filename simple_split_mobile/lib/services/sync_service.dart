import 'dart:async';
import 'package:simple_split_mobile/models/setting.dart';
import 'package:uuid/uuid.dart';
import '../models/event.dart';
import '../models/group.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'database_service.dart';

class SyncService {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();
  final Uuid _uuid = Uuid();
  
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;

  // Start periodic sync
  void startSync({Duration period = const Duration(minutes: 5)}) {
    stopSync(); // Stop any existing sync timer
    
    // Initial sync
    syncEvents();
    
    // Set up periodic sync
    _syncTimer = Timer.periodic(period, (_) => syncEvents());
  }
  
  // Stop periodic sync
  void stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  // Sync unsynced events with server
  Future<void> syncEvents() async {
    // Get all unsynced events
    final events = await _dbService.getUnsyncedEvents();
    
    for (final event in events) {
      try {
        // Try to send event to server
        final syncedEvent = await _apiService.createEvent(event);
        
        // Mark event as synced
        await _dbService.markEventAsSynced(event.eventId);
      } catch (e) {
        // If sync fails, leave event as unsynced for next attempt
        print('Failed to sync event: $e');
      }
    }
  }
  
  // Pull events for a group
  Future<void> pullEvents(String groupId, String? lastEventId) async {
    try {

      // Get events from server
      final events = await _apiService.getEventsByGroup(groupId, afterId: lastEventId);
      
      // Save events to local database
      for (final event in events) {
        //mark them as synced so we dont try to push to the server again
        await _dbService.saveEvent(event,true);
      }
    } catch (e) {
      print('Failed to pull events: $e');
    }
  }
  
  // Create and store a user locally and on server
  Future<User> createUser(String name) async {
    // Create user via API
    final user = await _apiService.createUser(name);
    
    // Save to local DB
    await _dbService.saveUser(user);

    final setting = Setting(settingKey: Setting.userId, settingValue: user.userId);
    await _dbService.saveSetting(setting);

    return user;
  }
  
  // Create and store a group locally and on server
  Future<Group> createGroup(String name, User user, String startingCurrency) async {
    // Create group via API
    final group = await _apiService.createGroup(name);
    
    // Save to local DB
    await _dbService.saveGroup(group);
    
    // Add user to group
    await _dbService.addUserToGroup(user.userId, group.groupId);
    
    // Create GROUP_CREATED event
    final eventId = _uuid.v7();
    final now = DateTime.now().toUtc().toIso8601String();
    
    final event = Event(
      eventId: eventId,
      linkedEventId: '',
      groupId: group.groupId,
      userId: user.userId,
      eventType: Event.groupCreated,
      payload: {
        'name': name,
        'date_time': now,
      },
      createdAt: now,
    );

    // Create USER_JOINED  event
    final eventId2 = _uuid.v7();

    final eventUserJoin = Event(
      eventId: eventId2,
      linkedEventId: '',
      groupId: group.groupId,
      userId: user.userId,
      eventType: Event.groupUserJoined,
      payload: {
        'name': user.name,
        'user_id': user.userId,
        'created_at': now,
      },
      createdAt: now,
    );
    // Create ADD CURRENCY  event
    final eventId3 = _uuid.v7();

    final eventAddCurrency = Event(
      eventId: eventId3,
      linkedEventId: '',
      groupId: group.groupId,
      userId: user.userId,
      eventType: Event.groupAddCurrency,
      payload: {
        'currency': startingCurrency,
        'date_time': now,
      },
      createdAt: now,
    );

    // Save event to local DB
    await _dbService.saveEvent(event,false);
    // Save event to local DB
    await _dbService.saveEvent(eventUserJoin,false);
    // Save event to local DB
    await _dbService.saveEvent(eventAddCurrency,false);
    
    // Try to sync events
    try {
      await syncEvents();

    } catch (e) {
      // Will be synced later
      print('Failed to sync group created event: $e');
    }
    
    return group;
  }
  
  // Join a group and create an event for it
  Future<Group> joinGroup(String groupId, String userId, String userName) async {

    //ensure that the group is valid on the server or return error
    var group = await _apiService.getGroup(groupId);
    if (group.groupId.isEmpty) {
      throw Exception('Group not found');
    }

    // Save to local DB
    await _dbService.saveGroup(group);
    // Add user to group locally
    await _dbService.addUserToGroup(userId, groupId);

    // Create GROUP_USER_JOINED event
    final eventId = _uuid.v7();
    final now = DateTime.now().toUtc().toIso8601String();

    final event = Event(
      eventId: eventId,
      linkedEventId: '',
      groupId: groupId,
      userId: userId,
      eventType: Event.groupUserJoined,
      payload: {
        'name': userName,
        'user_id': userId,
        'created_at': now,
      },
      createdAt: now,
    );
    
    // Save event to local DB
    await _dbService.saveEvent(event,false);

    await syncEvents();

    return group;
    
  }
}
