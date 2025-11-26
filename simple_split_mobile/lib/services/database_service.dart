import 'dart:convert';
import 'package:simple_split_mobile/models/projection.dart';
import 'package:simple_split_mobile/models/setting.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/event.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'simple_split.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create user table
    await db.execute('''
      CREATE TABLE users(
        user_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create settings table
    await db.execute('''
      CREATE TABLE settings(
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');
    // Create projections table
    await db.execute('''
      CREATE TABLE projections(
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )
    ''');

    // Create groups table
    await db.execute('''
      CREATE TABLE groups(
        group_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create user_groups table (for many-to-many relationship)
    await db.execute('''
      CREATE TABLE user_groups(
        user_id TEXT,
        group_id TEXT,
        PRIMARY KEY (user_id, group_id),
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE,
        FOREIGN KEY (group_id) REFERENCES groups (group_id) ON DELETE CASCADE
      )
    ''');

    // Create events table
    await db.execute('''
      CREATE TABLE events(
        event_id TEXT PRIMARY KEY,
        linked_event_id TEXT NULL,
        group_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups (group_id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE
      )
    ''');
  }

  // User operations
  Future<void> saveSetting(Setting setting) async {
    final db = await database;
    await db.insert(
      'settings',
      setting.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<Setting> getSetting(String key) async {
    final db = await database;

    final result = await db.query(
      'settings',
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Setting(
        settingKey: result.first['setting_key'] as String,
        settingValue: result.first['setting_value'] as String,
      );
    }

    throw Exception('Setting not found');
  }


  // User operations
  Future<void> saveProjection(Projection projection) async {
    final db = await database;
    await db.insert(
      'projections',
      projection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }  // User operations
  Future<void> saveUser(User user) async {
    final db = await database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<Projection?> getProjection(String settingKey) async {
    final db = await database;

    final result = await db.query(
      'projections',
      where: 'setting_key = ?',
      whereArgs: [settingKey],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Projection(
        settingKey: result.first['setting_key'] as String,
        settingValue: result.first['setting_value'] as String,
      );
    }

    return null;
  }

  Future<User?> getUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  Future<User?> getCurrentUser() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');

    if (maps.isEmpty) return null;
    return User.fromMap(maps.first); // Assuming there's only one user for now
  }

  // Group operations
  Future<void> saveGroup(Group group) async {
    final db = await database;
    await db.insert(
      'groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Group?> getGroup(String groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    if (maps.isEmpty) return null;
    return Group.fromMap(maps.first);
  }

  Future<List<Group>> getGroups() async {
    final db = await database;
    
    // Check if the groups table exists and has records
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='groups'");
    print('[DEBUG_LOG] Groups table exists: ${tables.isNotEmpty}');
    
    if (tables.isEmpty) {
      print('[DEBUG_LOG] Groups table does not exist!');
      return [];
    }
    
    // Get all groups with a simpler query
    final List<Map<String, dynamic>> maps = await db.query('groups');
    print('[DEBUG_LOG] Raw DB query returned ${maps.length} groups');
    
    // Print each group's data for debugging
    for (var map in maps) {
      print('[DEBUG_LOG] Group from DB: ${map.toString()}');
    }

    return List.generate(maps.length, (i) => Group.fromMap(maps[i]));
  }

  Future<void> addUserToGroup(String userId, String groupId) async {
    final db = await database;
    await db.insert(
      'user_groups',
      {
        'user_id': userId,
        'group_id': groupId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Event operations
  Future<void> saveEvent(Event event, bool synced) async {
    final db = await database;
    
    // Ensure linkedEventId is null if it's empty
    String? linkedEventId = event.linkedEventId;
    if (linkedEventId != null && linkedEventId.isEmpty) {
      linkedEventId = null;
    }
    
    await db.insert(
      'events',
      {
        'event_id': event.eventId,
        'linked_event_id': linkedEventId,
        'group_id': event.groupId,
        'user_id': event.userId,
        'event_type': event.eventType,
        'payload': jsonEncode(event.payload), // Convert Map to JSON string
        'created_at': event.createdAt,
        'synced': synced? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Event>> getEvents(String groupId, {String? afterId}) async {
    final db = await database;
    
    String whereClause = 'group_id = ?';
    List<dynamic> whereArgs = [groupId];
    
    if (afterId != null && afterId != '0') {
      whereClause += ' AND created_at > (SELECT created_at FROM events WHERE event_id = ?)';
      whereArgs.add(afterId);
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      // Convert JSON string back to Map
      final payloadMap = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
      
      // Convert empty string to null for linkedEventId
      String? linkedEventId = map['linked_event_id'] as String?;
      if (linkedEventId != null && linkedEventId.isEmpty) {
        linkedEventId = null;
      }
      
      return Event(
        eventId: map['event_id'] as String,
        linkedEventId: linkedEventId,
        groupId: map['group_id'] as String,
        userId: map['user_id'] as String,
        eventType: map['event_type'] as String,
        payload: payloadMap,
        createdAt: map['created_at'] as String,
      );
    });
  }

  Future<List<Event>> getUnsyncedEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      final payloadMap = jsonDecode(map['payload'] as String) as Map<String, dynamic>;
      
      // Convert empty string to null for linkedEventId
      String? linkedEventId = map['linked_event_id'] as String?;
      if (linkedEventId != null && linkedEventId.isEmpty) {
        linkedEventId = null;
      }
      
      return Event(
        eventId: map['event_id'] as String,
        linkedEventId: linkedEventId,
        groupId: map['group_id'] as String,
        userId: map['user_id'] as String,
        eventType: map['event_type'] as String,
        payload: payloadMap,
        createdAt: map['created_at'] as String,
      );
    });
  }

  Future<void> markEventAsSynced(String eventId) async {
    final db = await database;
    
    // First, get the current event to preserve its linkedEventId
    final List<Map<String, dynamic>> eventMaps = await db.query(
      'events',
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (eventMaps.isEmpty) {
      return; // Event not found
    }
    
    // Update only the synced flag, preserving all other values
    await db.update(
      'events',
      {'synced': 1},
      where: 'event_id = ?',
      whereArgs: [eventId],
    );
  }

  // Delete database (useful for testing or resetting)
  Future<void> deleteDatabase() async {
    String path = join(await getDatabasesPath(), 'simple_split.db');
    databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
