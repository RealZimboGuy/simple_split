import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/setting.dart';
import 'models/user.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'screens/username_screen.dart';
import 'screens/home_screen.dart';
import 'screens/group_selection_screen.dart';

void main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Enable FFI only on desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize Firebase with default options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize Firebase services
    await FirebaseService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Split',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorKey: FirebaseService.navigatorKey,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserAndNavigate();
  }

  Future<void> _checkUserAndNavigate() async {
    // Simulate a splash screen delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if user exists in database
    final dbService = DatabaseService();

    String? userId;
    try {
      // Get user ID from settings
      final userIdSetting = await dbService.getSetting(Setting.userId);
      userId = userIdSetting.settingValue;
    } catch (e) {
      debugPrint('Failed to get user ID: $e');
    }
    
    if (userId != null) {
      // Get the user object
      final user = await dbService.getUser(userId);
      
      if (user == null) {
        // User ID found but user object not found
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const UsernameScreen(),
            ),
          );
        }
        return;
      }
      
      // User exists, get their groups
      final groups = await dbService.getGroups();

      if (groups.isNotEmpty) {
        // Navigate to home screen with first group
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                user: user,
                initialGroup: groups.first,
              ),
            ),
          );
        }
      } else {
        // Navigate to group selection screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => GroupSelectionScreen(user: user),
            ),
          );
        }
      }
    } else {
      // Navigate to username screen for first-time users
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const UsernameScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 150, height: 150, 
              errorBuilder: (context, error, stackTrace) {
                return Icon(Icons.account_balance_wallet, size: 100, 
                  color: Theme.of(context).primaryColor);
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Simple Split',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
