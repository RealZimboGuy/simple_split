import 'package:flutter/material.dart';
import '../models/setting.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'group_selection_screen.dart';
import 'home_screen.dart';

class UsernameScreen extends StatefulWidget {
  const UsernameScreen({super.key});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _userIdController = TextEditingController();
  bool _isLoading = false;
  bool _isMigrating = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _submitUsername() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final syncService = SyncService();
      final username = _usernameController.text.trim();
      
      // Create user and get UUID from server (or generate locally if offline)
      final user = await syncService.createUserAndSaveDefault(username);
      
      if (!mounted) return;
      
      // Navigate to group selection screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GroupSelectionScreen(user: user),
        ),
      );
    } catch (e) {
      // Show error message if something went wrong
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating user: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _migrateUser() async {
    if (_userIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a User ID')),
      );
      return;
    }

    setState(() {
      _isMigrating = true;
    });

    try {
      final apiService = ApiService();
      final syncService = SyncService();
      final dbService = DatabaseService();
      final userId = _userIdController.text.trim();
      
      // Validate user exists
      final user = await apiService.getUser(userId);
      
      if (user.userId.isEmpty) {
        throw Exception('User not found');
      }
      
      // Save user details in settings
      await dbService.saveUser(user);
      
      final setting = Setting(
        settingKey: Setting.userId, 
        settingValue: user.userId
      );
      await dbService.saveSetting(setting);
      
      // Get user's groups and join them
      final groups = await apiService.getGroupsByUserId(userId);
      for (var group in groups) {
        await syncService.joinGroup(group.groupId, user.userId, user.name);
      }
      
      if (!mounted) return;
      
      // Navigate to group selection screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => GroupSelectionScreen(user: user),
        ),
      );
    } catch (e) {
      // Show error message if something went wrong
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error migrating user: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMigrating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Simple Split'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // New User Section
                const Text(
                  'Enter your name to get started',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                  enabled: !_isLoading && !_isMigrating,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: _submitUsername,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isMigrating) ? null : _submitUsername,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Continue'),
                  ),
                ),
                
                const SizedBox(height: 40),
                const Divider(),
                const SizedBox(height: 24),
                
                // Migration Section
                const Text(
                  'Or enter existing User ID to migrate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: 'Existing User ID',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_isLoading && !_isMigrating,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isMigrating) ? null : _migrateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isMigrating
                        ? const CircularProgressIndicator()
                        : const Text('Migrate User'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
