import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/setting.dart';
import '../models/group.dart';
import '../models/user.dart';
import '../screens/home_screen.dart';
import 'api_service.dart';
import 'database_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  late final FirebaseMessaging _messaging;
  late final FlutterLocalNotificationsPlugin _localNotifications;
  String? _token;

  // Notification channel details
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal() {
    _messaging = FirebaseMessaging.instance;
    _localNotifications = FlutterLocalNotificationsPlugin();
  }

  // Global navigator key to access context from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  Future<void> initialize() async {
    // Firebase.initializeApp() is already called in main.dart
    
    // Configure local notifications
    await _setupLocalNotifications();
    
    // Request permission
    await _requestPermission();
    
    // Get the token and setup handlers
    await _setupTokenHandling();
    
    // Set up message handlers
    _setupMessageHandlers();
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        debugPrint('Notification tapped: ${response.payload}');
        
        // Check if payload contains group_id
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            // Try to parse the payload as JSON
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              response.payload!.split(',').map((item) {
                final parts = item.split(':');
                if (parts.length == 2) {
                  return MapEntry(parts[0].trim(), parts[1].trim());
                }
                return null;
              }).where((item) => item != null).map((item) => item!).toList()
              .fold<Map<String, dynamic>>({}, (map, entry) {
                map[entry.key] = entry.value;
                return map;
              })
            );
            
            // Check if group_id exists in the data
            if (data.containsKey('group_id') && data['group_id'] != null) {
              // Navigate to the group
              navigateToGroup(data['group_id']);
            }
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );
    
    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _setupTokenHandling() async {
    // Get the token
    _token = await _messaging.getToken();
    debugPrint('Firebase token: $_token');
    
    // Send token to server if available
    if (_token != null) {
      await _sendTokenToServer(_token!);
    }
    
    // Listen for token refreshes
    _messaging.onTokenRefresh.listen((newToken) async {
      _token = newToken;
      debugPrint('Firebase token refreshed: $_token');
      await _sendTokenToServer(newToken);
    });
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final apiService = ApiService();
      final dbService = DatabaseService();
      final user = await dbService.getSetting(Setting.userId);

      if (user != null) {
        await apiService.registerFirebaseToken(user.settingValue, token);
        debugPrint('Token registered with server for user ${user.settingValue}');
      } else {
        debugPrint('Cannot register token: No current user');
      }
    } catch (e) {
      debugPrint('Failed to register token with server: $e');
    }
  }

  void _setupMessageHandlers() {
    // Handle messages when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message also contained a notification: ${message.notification}');
        _showLocalNotification(message);
      }
    });

    // Handle when the app is opened from a notification when the app is terminated
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state by notification');
        debugPrint('Message data: ${message.data}');
        
        // Check if message contains group_id
        if (message.data.containsKey('group_id') && message.data['group_id'] != null) {
          // Navigate to the group
          navigateToGroup(message.data['group_id']);
        }
      }
    });

    // Handle when the app is opened from a notification when the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background state by notification');
      debugPrint('Message data: ${message.data}');
      
      // Check if message contains group_id
      if (message.data.containsKey('group_id') && message.data['group_id'] != null) {
        // Navigate to the group
        navigateToGroup(message.data['group_id']);
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      // Build the payload string from data
      String payload = '';
      if (message.data.containsKey('group_id')) {
        payload = 'group_id: ${message.data['group_id']}';
      }
      if (message.data.containsKey('event_id')) {
        if (payload.isNotEmpty) payload += ', ';
        payload += 'event_id: ${message.data['event_id']}';
      }
      if (message.data.containsKey('type')) {
        if (payload.isNotEmpty) payload += ', ';
        payload += 'type: ${message.data['type']}';
      }
      
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    }
  }

  // Get the current token
  String? get token => _token;
  
  // Navigate to a specific group when notification is clicked
  Future<void> navigateToGroup(String groupId) async {
    try {
      final dbService = DatabaseService();
      
      // Get the group from the database
      final group = await dbService.getGroup(groupId);
      if (group == null) {
        debugPrint('Cannot navigate: Group $groupId not found');
        return;
      }
      
      // Get current user
      final userSetting = await dbService.getSetting(Setting.userId);
      final user = await dbService.getUser(userSetting.settingValue);
      if (user == null) {
        debugPrint('Cannot navigate: Current user not found');
        return;
      }
      
      // Get the navigator context and navigate
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              user: user,
              initialGroup: group,
            ),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error navigating to group: $e');
    }
  }
}
