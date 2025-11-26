import 'dart:convert';

class Event {
  final String eventId;
  final String? linkedEventId;  // Allow null
  final String groupId;
  final String userId;
  final String eventType;
  final Map<String, dynamic> payload;
  final String createdAt;

  Event({
    required this.eventId,
    required this.linkedEventId,
    required this.groupId,
    required this.userId,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  /// Create Event from JSON map (API response)
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      eventId: json['event_id'] as String,
      linkedEventId: json['linked_event_id'] as String?, // nullable
      groupId: json['group_id'] as String,
      userId: json['user_id'] as String,
      eventType: json['event_type'] as String,
      payload: Map<String, dynamic>.from(json['payload']),
      createdAt: json['created_at'] as String,
    );
  }

  /// Convert Event to JSON map (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'linked_event_id': linkedEventId, // can be null
      'group_id': groupId,
      'user_id': userId,
      'event_type': eventType,
      'payload': payload,
      'created_at': createdAt,
    };
  }

  /// Create Event from database map
  factory Event.fromMap(Map<String, dynamic> map) {
    // Payload might be a JSON string or a Map or null
    Map<String, dynamic> payloadMap = {};

    final rawPayload = map['payload'];
    if (rawPayload != null) {
      if (rawPayload is String) {
        payloadMap = Map<String, dynamic>.from(jsonDecode(rawPayload));
      } else {
        payloadMap = Map<String, dynamic>.from(rawPayload);
      }
    }

    return Event(
      eventId: map['event_id'] as String,
      linkedEventId: map['linked_event_id'] as String?, // allow null
      groupId: map['group_id'] as String,
      userId: map['user_id'] as String,
      eventType: map['event_type'] as String,
      payload: payloadMap,
      createdAt: map['created_at'] as String,
    );
  }

  /// Convert Event to database map
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'linked_event_id': linkedEventId, // nullable
      'group_id': groupId,
      'user_id': userId,
      'event_type': eventType,
      // store as JSON string
      'payload': jsonEncode(payload),
      'created_at': createdAt,
    };
  }

  // Event types constants
  static const String groupCreated = 'GROUP_CREATED';
  static const String groupAddCurrency = 'GROUP_ADD_CURRENCY';
  static const String groupRemoveCurrency = 'GROUP_REMOVE_CURRENCY';
  static const String groupUserJoined = 'GROUP_USER_JOINED';
  static const String expenseCreated = 'EXPENSE_CREATED';
  static const String expenseDeleted = 'EXPENSE_DELETED';
}
