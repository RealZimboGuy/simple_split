import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class GroupSelectionScreen extends StatefulWidget {
  final User user;

  const GroupSelectionScreen({
    super.key,
    required this.user,
  });

  @override
  State<GroupSelectionScreen> createState() => _GroupSelectionScreenState();
}

class _GroupSelectionScreenState extends State<GroupSelectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _groupCurrencyController = TextEditingController();
  final _groupIdController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;
  final DatabaseService _dbService = DatabaseService();
  List<Group> _groups = [];

  @override
  void initState() {
    super.initState();
    print('[DEBUG_LOG] initState called');
    // Load groups immediately
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await _dbService.getGroups();
    print('[DEBUG_LOG] Groups loaded: ${groups.length} groups');
    groups.forEach((group) {
      print('[DEBUG_LOG] Group: ${group.name}, ID: ${group.groupId}');
    });
    
    if (mounted) {
      setState(() {
        _groups = groups;
      });
      print('[DEBUG_LOG] _groups in state: ${_groups.length}');
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupCurrencyController.dispose();
    _groupIdController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final syncService = SyncService();
      final groupName = _groupNameController.text.trim();
      final currency = _groupCurrencyController.text.trim();

      // Create group and store locally and on server
      final group = await syncService.createGroup(groupName, widget.user,currency);
      
      if (!mounted) return;
      
      // Navigate to home screen
      _navigateToHome(group);
    } catch (e) {
      _showError('Error creating group: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _joinGroup() async {
    if (_groupIdController.text.trim().isEmpty) {
      _showError('Please enter a Group ID');
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final syncService = SyncService();
      final groupId = _groupIdController.text.trim();
      
      // Join group
      final group = await syncService.joinGroup(groupId, widget.user.userId, widget.user.name);
      
      if (!mounted) return;
      
      // Navigate to home screen
      _navigateToHome(group);
    } catch (e) {
      _showError('Error joining group: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  void _navigateToHome(Group group) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          user: widget.user,
          initialGroup: group,
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  void _navigateToHomeScreen() {
    if (_groups.isEmpty) return;
    
    // Navigate to the first group in the list
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          user: widget.user,
          initialGroup: _groups.first,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG_LOG] Building GroupSelectionScreen, _groups.length: ${_groups.length}');
    print('[DEBUG_LOG] _groups.isNotEmpty: ${_groups.isNotEmpty}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Selection'),
        automaticallyImplyLeading: false, // Prevent back button
        actions: [
          // Updated cancel button with proper theming
          ElevatedButton(
            onPressed: _navigateToHomeScreen,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                'Hello, ${widget.user.name}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              
              const Divider(),
              
              const Text(
                'Create a new group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
                enabled: !_isCreating && !_isJoining,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _groupCurrencyController,
                decoration: const InputDecoration(
                  labelText: 'Currency (e.g., USD, EUR)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a currency';
                  }
                  return null;
                },
                enabled: !_isCreating && !_isJoining,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isCreating || _isJoining) ? null : _createGroup,
                  child: _isCreating
                      ? const CircularProgressIndicator()
                      : const Text('Create Group'),
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              
              const Text(
                'Or join an existing group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _groupIdController,
                decoration: const InputDecoration(
                  labelText: 'Enter Group ID',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isCreating && !_isJoining,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_isCreating || _isJoining) ? null : _joinGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: _isJoining
                      ? const CircularProgressIndicator()
                      : const Text('Join Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
