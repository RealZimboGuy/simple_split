import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/sync_service.dart';

class AnonymousUserScreen extends StatefulWidget {
  final String groupId;
  const AnonymousUserScreen({super.key, required this.groupId});

  @override
  State<AnonymousUserScreen> createState() => _AnonymousUserScreenState();
}

class _AnonymousUserScreenState extends State<AnonymousUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createAnonymousUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final syncService = SyncService();
      final name = _nameController.text.trim();
      
      // Create user and get UUID from server (or generate locally if offline)
      final user = await syncService.createUser(name);
      
      if (!mounted) return;
      
      // Add the user to the current group
      await syncService.joinGroup(widget.groupId, user.userId, user.name);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anonymous user created successfully')),
      );
      
      // Return to previous screen
      Navigator.of(context).pop();
      
    } catch (e) {
      // Show error message if something went wrong
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating anonymous user: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Anonymous User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create a user who will be added to the current group, Note: this is for convenience of splits for people who wont have the app',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                enabled: !_isLoading,
                textInputAction: TextInputAction.done,
                onEditingComplete: _createAnonymousUser,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAnonymousUser,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Create User'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
