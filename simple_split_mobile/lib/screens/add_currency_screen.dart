import 'package:flutter/material.dart';
import 'package:simple_split_mobile/models/events/currency.dart';
import 'package:simple_split_mobile/models/event.dart';
import 'package:simple_split_mobile/models/user.dart';
import 'package:simple_split_mobile/models/group.dart';
import 'package:simple_split_mobile/services/database_service.dart';
import 'package:simple_split_mobile/services/projection_service.dart';
import 'package:uuid/uuid.dart';

class AddCurrencyScreen extends StatefulWidget {
  final User currentUser;
  final Group group;

  const AddCurrencyScreen({
    super.key,
    required this.currentUser,
    required this.group,
  });

  @override
  State<AddCurrencyScreen> createState() => _AddCurrencyScreenState();
}

class _AddCurrencyScreenState extends State<AddCurrencyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currencyController = TextEditingController();
  final _databaseService = DatabaseService();
  final _projectionService = ProjectionService();
  List<String> _commonCurrencies = ['USD', 'EUR','ZAR', 'GBP', 'CAD', 'AUD', 'JPY', 'CNY', 'INR'];
  List<String> _existingCurrencies = [];
  bool _isLoading = true;
  final uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _loadExistingCurrencies();
  }

  @override
  void dispose() {
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingCurrencies() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the group's projection which contains currencies
      final projection = await _projectionService.getGroupProjection(widget.group.groupId);
      
      setState(() {
        _existingCurrencies = projection.currencies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading currencies: $e')),
        );
      }
    }
  }

  Future<void> _addCurrency() async {
    if (!_formKey.currentState!.validate()) return;
    
    final currencyCode = _currencyController.text.trim().toUpperCase();

    // Check if currency already exists in the group
    if (_existingCurrencies.contains(currencyCode)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This currency is already added to the group')),
        );
      }
      return;
    }

    // Create the currency object
    final currency = Currency(
      currency: currencyCode,
      dateTime: DateTime.now().toIso8601String(),
    );

    // Create and save the event
    final event = Event(
      eventId: uuid.v7(),
      linkedEventId: '',
      groupId: widget.group.groupId,
      userId: widget.currentUser.userId,
      eventType: Event.groupAddCurrency,
      payload: {
        'currency': currencyCode,
        'date_time': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      await _databaseService.saveEvent(event, false);
      await _projectionService.reCalculateGroupProjections(widget.group.groupId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Currency added successfully')),
        );
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding currency: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Currency'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add a new currency to your group',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    
                    // Currency input
                    TextFormField(
                      controller: _currencyController,
                      decoration: const InputDecoration(
                        labelText: 'Currency Code',
                        hintText: 'Enter 3-letter currency code (e.g., USD)',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a currency code';
                        }
                        if (value.length != 3) {
                          return 'Currency code must be 3 letters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Common currencies
                    const Text(
                      'Common currencies:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      children: _commonCurrencies.map((currency) {
                        final isDisabled = _existingCurrencies.contains(currency);
                        return FilterChip(
                          label: Text(currency),
                          selected: _currencyController.text == currency,
                          onSelected: isDisabled ? null : (selected) {
                            setState(() {
                              _currencyController.text = currency;
                            });
                          },
                          backgroundColor: isDisabled ? Colors.grey.shade300 : null,
                          labelStyle: isDisabled 
                            ? const TextStyle(color: Colors.grey)
                            : null,
                        );
                      }).toList(),
                    ),

                    if (_existingCurrencies.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Currencies in this group:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        children: _existingCurrencies.map((currency) => Chip(
                          label: Text(currency),
                        )).toList(),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addCurrency,
                        child: const Text('Add Currency'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
