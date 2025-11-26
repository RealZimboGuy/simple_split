import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/database_service.dart';
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
    final user = await dbService.getCurrentUser();

    if (user != null) {
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
