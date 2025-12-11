import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/event.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  late final String baseUrl;
  final uuid = Uuid();

  factory ApiService({String? baseUrl}) {
    if (baseUrl != null) {
      _instance._updateBaseUrl(baseUrl);
    }
    return _instance;
  }

  ApiService._internal() {
    baseUrl = dotenv.env['API_BASE_URL'] ?? 'https://simple-split-api-106581424606.europe-west1.run.app/api';
  }

  void _updateBaseUrl(String newBaseUrl) {
    baseUrl = newBaseUrl;
  }

  // User API calls
  Future<User> createUser(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return User.fromJson(userData);
      } else {
        throw Exception('Failed to create user: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');

    }
  }
  // User API calls
// User API calls
Future<User> getUser(String id) async {
  try {
    final uri = Uri.parse('$baseUrl/users/get').replace(queryParameters: {'id': id});
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        return User.fromJson(userData);
      } else {
        throw Exception('Failed to create user: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');

    }
  }

  // Group API calls
  Future<Group> createGroup(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/groups/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 200) {
        final groupData = json.decode(response.body);
        //create an event for user joining the group

        return Group.fromJson(groupData);
      } else {
        throw Exception('Failed to create group: ${response.statusCode}');
      }
    } catch (e) {
     throw Exception('Failed to create group: ${e.toString()}');
    }
  }

  Future<Group> getGroup(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/groups/get').replace(queryParameters: {'id': id});
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final groupData = json.decode(response.body);
        return Group.fromJson(groupData);
      } else {
        throw Exception('Failed to get group: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get group: ${e.toString()}');

    }
  }

  Future<List<Group>> getGroupsByUserId(String id) async {
    try {
      final uri = Uri.parse('$baseUrl/groups/by-user').replace(queryParameters: {'user_id': id});
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> groupsData = json.decode(response.body);
        return groupsData.map((groupData) => Group.fromJson(groupData)).toList();
      } else {
        throw Exception('Failed to fetch groups: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch groups: ${e.toString()}');

    }

  }

  // Event API calls
  Future<Event> createEvent(Event event) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/events/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(event.toJson()),
      );

      if (response.statusCode == 200) {
        final eventData = json.decode(response.body);
        return Event.fromJson(eventData);
      } else {
        throw Exception('Failed to create event: ${response.statusCode}');
      }
    } catch (e) {
      // For offline mode, just return the original event
      // This will be synced later
      return event;
    }
  }

  Future<List<Event>> getEventsByGroup(String groupId, {String? afterId}) async {
    try {
      String url = '$baseUrl/events/by-group?group_id=$groupId';
      if (afterId != null) {
        url += '&after_id=$afterId';
      } else {
        url += '&after_id=0'; // Default to get all events
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> eventsData = json.decode(response.body);
        return eventsData.map((eventData) => Event.fromJson(eventData)).toList();
      } else {
        throw Exception('Failed to fetch events: ${response.statusCode}');
      }
    } catch (e) {
      // For offline mode, return an empty list
      // The app will use local events
      return [];
    }
  }

  // Helper method to create a UUID v7 (compatible with server)
  String generateUuidV7() {
    return uuid.v7();
  }

  // Firebase token registration
  Future<bool> registerFirebaseToken(String userId, String token) async {
    try {
      final uri = Uri.parse('$baseUrl/users/firebase')
          .replace(queryParameters: {'id': userId});

      // Log the URL *before* calling API
      log('POST $uri', name: 'registerFirebaseToken');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': token}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to register token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to register token: ${e.toString()}');
    }
  }
}
