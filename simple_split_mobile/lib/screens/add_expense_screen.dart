import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_split_mobile/models/events/Expense.dart';
import 'package:simple_split_mobile/models/event.dart';
import 'package:simple_split_mobile/models/user.dart';
import 'package:simple_split_mobile/models/group.dart';
import 'package:simple_split_mobile/services/database_service.dart';
import 'package:simple_split_mobile/services/projection_service.dart';
import 'package:simple_split_mobile/services/sync_service.dart';
import 'package:simple_split_mobile/models/projections/projection_group.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';

class AddExpenseScreen extends StatefulWidget {
  final User currentUser;
  final Group group;


  const AddExpenseScreen({
    super.key,
    required this.currentUser,
    required this.group,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final ProjectionService _projectionService = ProjectionService();
  final DatabaseService _databaseService = DatabaseService();
  final SyncService _syncService = SyncService();
  final uuid = Uuid();
  
  // Tab controller
  late TabController _tabController;
  
  String? _selectedPayingUserId;
  String _currency = 'USD'; // Default currency
  List<String> _availableCurrencies = ['USD']; // Default currencies list
  Map<String, bool> _selectedUsers = {};
  Map<String, TextEditingController> _customAmountControllers = {};
  double _remainingAmount = 0.0;
  bool _isLoading = true;
  List<User> _groupUsers = [];
  
  // Split type constants
  static const int SPLIT_EQUAL = 0;
  static const int SPLIT_CUSTOM = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGroupUsers();
    
    // Listen for changes to update remaining amount
    _amountController.addListener(_updateRemainingAmount);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _tabController.dispose();
    
    // Dispose custom amount controllers
    for (var controller in _customAmountControllers.values) {
      controller.dispose();
    }
    
    super.dispose();
  }
  
  void _updateRemainingAmount() {
    if (_amountController.text.isNotEmpty) {
      try {
        final totalAmount = double.parse(_amountController.text);
        double allocatedAmount = 0.0;
        
        for (var controller in _customAmountControllers.values) {
          if (controller.text.isNotEmpty) {
            allocatedAmount += double.tryParse(controller.text) ?? 0.0;
          }
        }
        
        setState(() {
          _remainingAmount = totalAmount - allocatedAmount;
        });
      } catch (e) {
        // Handle parsing error
        setState(() {
          _remainingAmount = 0.0;
        });
      }
    } else {
      setState(() {
        _remainingAmount = 0.0;
      });
    }
  }

  Future<void> _loadGroupUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the group's projection which contains user information and currencies
      final projection = await _projectionService.getGroupProjection(widget.group.groupId);
      
      setState(() {
        // Create a map to deduplicate users based on userId
        final Map<String, User> uniqueUsers = {};
        for (var user in projection.users) {
          uniqueUsers[user.userId] = user;
        }
        
        // Convert map values back to list
        _groupUsers = uniqueUsers.values.toList();
        
        //log the users
        // debugPrint("GROUP USERS");
        // for(var u in _groupUsers ){
        //   debugPrint(u.toString());
        // }

        // Initialize the current user as the payer
        _selectedPayingUserId = widget.currentUser.userId;
        
        // Get available currencies from projection
        if (projection.currencies.isNotEmpty) {
          _availableCurrencies = projection.currencies;
          // Set the first currency as the default if available
          if (_availableCurrencies.isNotEmpty) {
            _currency = _availableCurrencies.first;
          }
        }
        
        // Initialize all users as selected for split by default
        for (var user in _groupUsers) {
          _selectedUsers[user.userId] = true;
          
          // Initialize custom amount controllers
          _customAmountControllers[user.userId] = TextEditingController();
          
          // Add listeners to update remaining amount when any custom amount changes
          _customAmountControllers[user.userId]!.addListener(_updateRemainingAmount);
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    
    final double totalAmount = double.parse(_amountController.text);
    
    // Create paid by object (who's paying)
    if (_selectedPayingUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user who is paying')),
      );
      return;
    }

    // Different validation and handling based on selected tab
    List<PaidFor> paidFor = [];
    String splitType = '';
    
    if (_tabController.index == SPLIT_EQUAL) {
      // Equal Split validation and handling
      if (_selectedUsers.values.every((selected) => !selected)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one user to split the expense with')),
        );
        return;
      }
      
      // Count selected users for even split
      final selectedUserCount = _selectedUsers.values.where((selected) => selected).length;
      final double amountPerUser = selectedUserCount > 0 ? totalAmount / selectedUserCount : 0.0;
      
      // Round to two decimal places
      final double roundedAmountPerUser = (amountPerUser * 100).floor() / 100;
      
      // Create paid for objects (who's splitting the expense evenly)
      paidFor = _selectedUsers.entries
          .where((entry) => entry.value) // Only include selected users
          .map((entry) => PaidFor(
                userId: entry.key,
                amount: roundedAmountPerUser,
              ))
          .toList();
      
      // Check if rounding caused a difference and adjust one share if needed
      final double sumOfShares = paidFor.fold(0.0, (sum, pf) => sum + pf.amount);
      final double difference = totalAmount - sumOfShares;
      
      // If there's a difference due to rounding, adjust the first share
      if (difference.abs() > 0.001 && paidFor.isNotEmpty) {
        paidFor[0] = PaidFor(
          userId: paidFor[0].userId,
          amount: paidFor[0].amount + difference,
        );
      }
      
      splitType = 'EQUAL';
    } else {
      // Custom Split validation and handling
      double allocatedAmount = 0.0;
      
      // Check if any amount is entered
      bool hasAmount = false;
      for (var userId in _customAmountControllers.keys) {
        final controller = _customAmountControllers[userId]!;
        if (controller.text.isNotEmpty && double.tryParse(controller.text) != null && double.parse(controller.text) > 0) {
          hasAmount = true;
          break;
        }
      }
      
      if (!hasAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter at least one amount for custom split')),
        );
        return;
      }
      
      // Create paid for objects from custom amounts
      for (var userId in _customAmountControllers.keys) {
        final controller = _customAmountControllers[userId]!;
        if (controller.text.isNotEmpty) {
          try {
            double amount = double.parse(controller.text);
            allocatedAmount += amount;
            
            if (amount > 0) {
              paidFor.add(PaidFor(
                userId: userId,
                amount: amount,
              ));
            }
          } catch (e) {
            // Skip invalid entries
          }
        }
      }
      
      // Validate total
      final difference = (allocatedAmount - totalAmount).abs();
      if (difference > 0.01) { // Allow small rounding errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Total allocated amount (${allocatedAmount.toStringAsFixed(2)}) does not match expense total (${totalAmount.toStringAsFixed(2)})')),
        );
        return;
      }
      
      splitType = 'CUSTOM';
    }
    
    final List<PaidBy> paidBy = [
      PaidBy(
        userId: _selectedPayingUserId!,
        amount: totalAmount,
      ),
    ];
    
    // Create expense object
    final expense = Expense(
      description: _descriptionController.text,
      dateTime: DateTime.now(),
      splitType: splitType,
      currency: _currency,
      total: totalAmount,
      paidBy: paidBy,
      paidFor: paidFor,
    );
    
    // Create and save the event
    final event = Event(
      eventId: uuid.v7(),
      linkedEventId: '',
      groupId: widget.group.groupId,
      userId: widget.currentUser.userId,
      eventType: Event.expenseCreated,
      payload: expense.toJson(),
      createdAt: DateTime.now().toIso8601String(),
    );
    
    try {
      // Save event locally
      await _databaseService.saveEvent(event, false);
      await _projectionService.reCalculateGroupProjections(widget.group.groupId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense saved successfully')),
        );
        
        // Return success and then trigger background sync
        Navigator.of(context).pop(true);
        
        // Trigger background sync after navigation
        Future.microtask(() async {
          try {
            await _syncService.syncEvents();
          } catch (e) {
            debugPrint('Background sync error: $e');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving expense: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Scrollable content area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText: 'What is this expense for?',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a description';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Amount
                          TextFormField(
                            controller: _amountController,
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: 'How much was spent?',
                              prefixText: ' ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              // Allow only digits, a single decimal point, and limit to 2 decimal places
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              if (double.parse(value) <= 0) {
                                return 'Amount must be greater than zero';
                              }
                              // Validate that it has maximum 2 decimal places
                              if (value.contains('.') && value.split('.')[1].length > 2) {
                                return 'Amount can have at most 2 decimal places';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Currency selection
                          const Text(
                            'Currency',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          DropdownButtonFormField<String>(
                            value: _currency,
                            decoration: const InputDecoration(
                              hintText: 'Select currency',
                            ),
                            items: _availableCurrencies.map((currency) {
                              return DropdownMenuItem<String>(
                                value: currency,
                                child: Text(currency),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _currency = value;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select a currency';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Who's Paying?
                          const Text(
                            'Who paid?',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          DropdownButtonFormField<String>(
                            value: _selectedPayingUserId,
                            hint: const Text('Select who paid'),
                            items: _groupUsers.map((user) {
                              return DropdownMenuItem<String>(
                                value: user.userId,
                                child: Text(user.name),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedPayingUserId = value;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select who paid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Split method tabs
                          const Text(
                            'Split method:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          
                          // Tab Bar - styled to match home screen table headers
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(text: 'Split Among'),
                                Tab(text: 'Custom'),
                              ],
                              indicator: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Theme.of(context).colorScheme.primaryContainer,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
                              unselectedLabelColor:
                              Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Tab content
                          SizedBox(
                            height: 300, // Fixed height for the tab content
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                // Split Among Tab (Equal Split)
                                SingleChildScrollView(
                                  // Add padding to the bottom to prevent list items from being hidden behind the button
                                  padding: const EdgeInsets.only(bottom: 60.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Select users to split equally:',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 8),
                                      ...List.generate(_groupUsers.length, (index) {
                                        final user = _groupUsers[index];
                                        return CheckboxListTile(
                                          title: Text(user.name),
                                          value: _selectedUsers[user.userId] ?? false,
                                          onChanged: (bool? value) {
                                            setState(() {
                                              _selectedUsers[user.userId] = value!;
                                            });
                                          },
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                
                                // Custom Split Tab
                                SingleChildScrollView(
                                  // Add padding to the bottom to prevent list items from being hidden behind the button
                                  padding: const EdgeInsets.only(bottom: 60.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Enter custom amounts:',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _remainingAmount.abs() < 0.01 
                                                  ? Theme.of(context).colorScheme.tertiaryContainer 
                                                  : Theme.of(context).colorScheme.errorContainer,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Amount remaining: ${_currency} ${_remainingAmount.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: _remainingAmount.abs() < 0.01
                                                    ? Theme.of(context).colorScheme.onTertiaryContainer
                                                    : Theme.of(context).colorScheme.onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...List.generate(_groupUsers.length, (index) {
                                        final user = _groupUsers[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 3,
                                                child: Text(
                                                  user.name,
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: TextField(
                                                  controller: _customAmountControllers[user.userId],
                                                  decoration: InputDecoration(
                                                    hintText: '0.00',
                                                    prefixText: '$_currency ',
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                                                    ),
                                                    filled: true,
                                                    fillColor: Theme.of(context).colorScheme.surface,
                                                  ),
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  inputFormatters: [
                                                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Fixed button at bottom
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveExpense,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Save Expense',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
