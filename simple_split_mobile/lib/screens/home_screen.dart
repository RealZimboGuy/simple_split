import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:simple_split_mobile/services/projection_service.dart';
import 'package:simple_split_mobile/models/events/Expense.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/group.dart';
import '../models/event.dart';
import '../models/projections/projection_group.dart';
import '../models/settlement.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import 'group_selection_screen.dart';
import 'add_expense_screen.dart';
import 'add_currency_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  final Group initialGroup;

  const HomeScreen({
    super.key,
    required this.user,
    required this.initialGroup,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Group _currentGroup;
  final SyncService _syncService = SyncService();
  final ProjectionService _projectionService = ProjectionService();
  final DatabaseService _dbService = DatabaseService();
  List<Group> _userGroups = [];
  bool _isSyncing = false;
  final uuid = Uuid();
  String? _selectedCurrency;
  // Counter for tracking consecutive clicks on Expenses text
  int _expensesClickCount = 0;
  // Timestamp for tracking click timing
  DateTime? _lastClickTime;

  // Show confirmation dialog before deleting an expense
  void _showDeleteConfirmation(Event event) {
    final expense = Expense.fromJson(event.payload);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Close the dialog
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              _logExpenseDeletedEvent(event);
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
  
  // Log expense deleted event
  void _logExpenseDeletedEvent(Event originalEvent) async {
    try {
      final expense = Expense.fromJson(originalEvent.payload);
      
      // Create a new event for deletion
      final deleteEvent = Event(
        eventId: uuid.v7(),
        linkedEventId: originalEvent.eventId,
        groupId: _currentGroup.groupId,
        userId: widget.user.userId,
        eventType: Event.expenseDeleted,
        payload: originalEvent.payload,
        createdAt: DateTime.now().toIso8601String(),
      );
      
      // Save event locally
      await _dbService.saveEvent(deleteEvent, false);
      
      // Recalculate projections immediately
      await _projectionService.reCalculateGroupProjections(_currentGroup.groupId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
        
        // Refresh UI with local data
        setState(() {});
        
        // Trigger background sync
        Future.microtask(() {
          _syncEventsInBackground();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Show settlement modal
  void _showSettlementModal(String currency, List<MapEntry<String, double>> positions, ProjectionGroup projection) {
    // Calculate optimal settlement plan
    final settlements = _calculateSettlements(positions, projection);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settlement Plan: $currency',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              
              if (settlements.isEmpty)
                const Text('No settlements needed.'),
              
              ...settlements.map((settlement) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        '${settlement.fromUser.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(' pays '),
                      Text(
                        '${settlement.toUser.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(': '),
                      Text(
                        '$currency ${NumberFormat('#,##0.00').format(settlement.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              
              const SizedBox(height: 20),
              const Text(
                'Note: This is a simplified settlement plan to minimize the number of transactions.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
  
  // Settlement calculation algorithm
  List<Settlement> _calculateSettlements(List<MapEntry<String, double>> positions, ProjectionGroup projection) {
    List<Settlement> settlements = [];
    
    // Separate users into creditors (positive balance) and debtors (negative balance)
    List<MapEntry<String, double>> creditors = [];
    List<MapEntry<String, double>> debtors = [];
    
    for (var position in positions) {
      if (position.value > 0) {
        creditors.add(position);
      } else if (position.value < 0) {
        debtors.add(MapEntry(position.key, -position.value)); // Store positive amount for simplicity
      }
    }
    
    // Sort both lists by amount (descending)
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));
    
    // Pair debtors with creditors to minimize transactions
    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      var creditor = creditors.first;
      var debtor = debtors.first;
      
      // Find the users in the projection
      User creditorUser;
      User debtorUser;
      
      try {
        creditorUser = projection.users.firstWhere((u) => u.userId == creditor.key);
      } catch (e) {
        creditorUser = User(userId: creditor.key, name: "Unknown", createdAt: "");
      }
      
      try {
        debtorUser = projection.users.firstWhere((u) => u.userId == debtor.key);
      } catch (e) {
        debtorUser = User(userId: debtor.key, name: "Unknown", createdAt: "");
      }
      
      // Calculate the transfer amount
      final amount = creditor.value < debtor.value ? creditor.value : debtor.value;
      
      // Create a settlement
      settlements.add(Settlement(
        fromUser: debtorUser,
        toUser: creditorUser,
        amount: amount,
      ));
      
      // Update balances
      if (creditor.value > debtor.value) {
        // Creditor still has remaining balance
        creditors[0] = MapEntry(creditor.key, creditor.value - debtor.value);
        debtors.removeAt(0);
      } else if (creditor.value < debtor.value) {
        // Debtor still has remaining balance
        debtors[0] = MapEntry(debtor.key, debtor.value - creditor.value);
        creditors.removeAt(0);
      } else {
        // Both are settled
        creditors.removeAt(0);
        debtors.removeAt(0);
      }
    }
    
    return settlements;
  }

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.initialGroup;
    
    // Start sync service for periodic syncing
    _syncService.startSync();
    
    // Load user groups immediately
    _loadUserGroups();
    
    // Load data asynchronously to prevent blocking the UI
    Future.microtask(() async {
      await _loadLocalData();
      if (mounted) {
        setState(() {});
      }
      
      // Perform background sync after local data is loaded
      _syncEventsInBackground();
    });
  }

  @override
  void dispose() {
    // Stop sync service when screen is disposed
    _syncService.stopSync();
    super.dispose();
  }

  Future<void> _loadUserGroups() async {
    final groups = await _dbService.getGroups();
    
    if (mounted) {
      setState(() {
        _userGroups = groups;
      });
    }
  }

  // Load data from local database without network operations
  Future<void> _loadLocalData() async {
    try {
      // Recalculate projections based on local data
      await _projectionService.reCalculateGroupProjections(_currentGroup.groupId);
      // Note: This is an expensive operation that recalculates all projections
      // We now call this asynchronously to avoid blocking the UI
    } catch (e) {
      debugPrint('Error loading local data: $e');
    }
  }

  // Background sync that doesn't block the UI
  Future<void> _syncEventsInBackground() async {
    try {
      // Don't show loading indicator for background sync
      // Sync events for current group
      await _syncService.syncEvents();
      await _syncService.pullEvents(_currentGroup.groupId, null);

      await _projectionService.reCalculateGroupProjections(_currentGroup.groupId);
      
      // Refresh user groups
      await _loadUserGroups();
      
      // Refresh UI if needed
      if (mounted) {
        setState(() {});
      }
    } catch (e, stack) {
      // Log full error + stack trace
      debugPrint("❌ Background sync error: $e");
      debugPrint("STACK TRACE:");
      debugPrint(stack.toString());
    }
  }

  // Sync with loading indicator (for manual sync)
  Future<void> _syncEvents() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Sync events for current group
      await _syncService.syncEvents();
      await _syncService.pullEvents(_currentGroup.groupId, null);

      await _projectionService.reCalculateGroupProjections(_currentGroup.groupId);
      
      // Refresh user groups
      await _loadUserGroups();
    } catch (e, stack) {
      // Log full error + stack trace
      debugPrint("❌ Sync error: $e");
      debugPrint("STACK TRACE:");
      debugPrint(stack.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  void _changeGroup(Group group) {
    setState(() {
      _currentGroup = group;
      // Reset currency filter when changing groups
      _selectedCurrency = null;
    });
    
    // Close drawer immediately
    Navigator.of(context).pop();
    
    // Since we're changing groups, we need to load local data
    // But we'll do it asynchronously to prevent UI lag
    Future.microtask(() async {
      await _loadLocalData();
      if (mounted) {
        setState(() {});
      }
      
      // Then sync in background
      _syncEventsInBackground();
    });
  }
  
  void _navigateToAddCurrencyScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCurrencyScreen(
          currentUser: widget.user,
          group: _currentGroup,
        ),
      ),
    ).then((value) {
      // Refresh the screen if currency was added
      if (value == true) {
        // Projection has already been recalculated
        // Reset currency filter and trigger UI refresh to show new data
        setState(() {
          _selectedCurrency = null;
        });
        
        // Then sync in background without blocking UI
        Future.microtask(() {
          _syncEventsInBackground();
        });
      }
    });
  }
  
  void _copyGroupId() {
    // Text to copy with the message and group ID
    final String textToCopy = "Please join my Simple Split group, the Id to join is: ${_currentGroup.groupId}";
    
    // Copy to clipboard
    Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
      // Show a confirmation message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group ID copied to clipboard')),
      );
    });
  }
  
  // Handle consecutive clicks on Expenses text (hidden feature)
  void _handleExpensesTextClick() {
    final now = DateTime.now();
    
    // If the last click was more than 2 seconds ago, reset the counter
    if (_lastClickTime != null && now.difference(_lastClickTime!).inSeconds > 2) {
      _expensesClickCount = 0;
    }
    
    // Update last click time and increment counter
    _lastClickTime = now;
    _expensesClickCount++;
    
    // Check if we've reached 5 consecutive clicks
    if (_expensesClickCount == 5) {
      _showResetExpensesDialog();
      _expensesClickCount = 0; // Reset counter after triggering dialog
    }
  }
  
  // Show dialog for resetting expenses sync status
  void _showResetExpensesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hidden Feature Activated'),
        content: const Text('Resetting expenses'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              _resetExpensesSyncStatus();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  // Reset sync status for all events in the current group
  Future<void> _resetExpensesSyncStatus() async {
    try {
      await _dbService.resetSyncedForGroup(_currentGroup.groupId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expenses sync status has been reset')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting expenses: $e')),
        );
      }
    }
  }
  
  void _showLeaveGroupConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Group'),
          content: const Text('Are you sure you want to leave this group? This will delete the group data from your device.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _leaveGroup();
              },
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }
  
  void _leaveGroup() async {
    final currentGroupId = _currentGroup.groupId;
    
    // Delete the current group from the database
    await DatabaseService().deleteGroup(currentGroupId);
    
    // Get remaining groups
    final groups = await DatabaseService().getGroups();
    
    if (groups.isEmpty) {
      // No groups left, navigate to group creation screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => GroupSelectionScreen(user: widget.user)),
        (route) => false, // Remove all previous routes
      );
    } else {
      // Update current group to first available group
      setState(() {
        _currentGroup = groups.first;
      });
      
      // Recalculate projections for the new current group
      await _projectionService.reCalculateGroupProjections(_currentGroup.groupId);
      
      // Refresh UI
      setState(() {});
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully left the group')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentGroup.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _syncEvents,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'add_currency') {
                _navigateToAddCurrencyScreen();
              } else if (value == 'copy_group_id') {
                _copyGroupId();
              } else if (value == 'leave_group') {
                _showLeaveGroupConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'add_currency',
                child: Text('Add Currency to Group'),
              ),
              const PopupMenuItem<String>(
                value: 'copy_group_id',
                child: Text('Copy Group ID'),
              ),
              const PopupMenuItem<String>(
                value: 'leave_group',
                child: Text('Leave Group'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 10,
        highlightElevation: 12,  // when pressed
        focusElevation: 12,
        hoverElevation: 12,
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                currentUser: widget.user,
                group: _currentGroup,
              ),
            ),
          ).then((value) {
            // Refresh the screen if expense was added
            if (value == true) {
              // Projection has already been recalculated in add_expense_screen.dart
              // Simply trigger a UI refresh to show new data
              setState(() {});
              
              // Then sync in background without blocking UI
              Future.microtask(() {
                _syncEventsInBackground();
              });
            }
          });
        },
        child: const Icon(Icons.add),
        tooltip: 'Add Expense',
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Copy user ID to clipboard
                      Clipboard.setData(ClipboardData(text: widget.user.userId)).then((_) {
                        // Show confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User ID copied to clipboard')),
                        );
                      });
                    },
                    child: UserAccountsDrawerHeader(
                      accountName: Text(widget.user.name),
                      accountEmail: Text('ID: ${widget.user.userId.substring(0, 8)}...'),
                      currentAccountPicture: CircleAvatar(
                        child: Text(widget.user.name[0].toUpperCase()),
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Your Groups'),
                    subtitle: const Text('Switch to a different group'),
                  ),
                  ..._userGroups.map((group) => ListTile(
                    title: Text(group.name),
                    selected: group.groupId == _currentGroup.groupId,
                    onTap: () => _changeGroup(group),
                  )),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Create or Join Another Group'),
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => GroupSelectionScreen(user: widget.user),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Version number at the bottom
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Version: 1.0.7',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
      body: _isSyncing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing data...'),
                ],
              ),
            )
          : buildGroupsWithDebts([_currentGroup], _projectionService),
    );
  }

  Widget buildGroupsWithDebts(List<Group> groups, ProjectionService projectionService) {
    return FutureBuilder(
      future: Future.wait([
        projectionService.getGroupProjection(groups[0].groupId),
        _dbService.getEvents(groups[0].groupId),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final projection = snapshot.data![0] as ProjectionGroup;
        final events = snapshot.data![1] as List<Event>;
        
        // Filter and sort expense events
        // First, get all expense deletion events and create a set of their linked event IDs
        final deletedEventIds = events
            .where((event) => event.eventType == Event.expenseDeleted)
            .map((event) => event.linkedEventId)
            .where((id) => id != null) // Filter out null linkedEventIds
            .map((id) => id as String) // Cast to String
            .toSet();
            
        // Filter expense events, excluding those that have been deleted
        final expenseEvents = events
            .where((event) => 
                event.eventType == Event.expenseCreated && 
                !deletedEventIds.contains(event.eventId))
            .toList();
            
        expenseEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Debts section - Net Positions with compact table layout
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildNetPositionsTable(projection),
                ),
              ),
              
              // Expenses list header with currency filter
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _handleExpensesTextClick,
                      child: const Text(
                        'Expenses',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (projection.currencies.isNotEmpty)
                      DropdownButton<String>(
                        value: _selectedCurrency,
                        hint: const Text('Filter by currency'),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCurrency = newValue;
                          });
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All currencies'),
                          ),
                          ...projection.currencies.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
              ),
              
              // Expenses list
              if (expenseEvents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('No expenses yet. Add your first expense!'),
                  ),
                )
              else
                Builder(
                  builder: (context) {
                    // Filter expenses based on selected currency
                    final filteredExpenses = expenseEvents
                        .where((event) {
                          // If no currency is selected, show all expenses
                          if (_selectedCurrency == null) return true;
                          
                          // Filter expenses by the selected currency
                          final expense = Expense.fromJson(event.payload);
                          return expense.currency == _selectedCurrency;
                        })
                        .toList();
                        
                    // Check if we have any expenses after filtering
                    if (filteredExpenses.isEmpty && _selectedCurrency != null) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                          child: Text('No expenses found for ${_selectedCurrency} currency.'),
                        ),
                      );
                    }
                    
                    // Display the filtered expenses
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: filteredExpenses
                            .map((event) {
                              return _buildExpenseCard(event, projection);
                            })
                            .toList(),
                      ),
                    );
                  },
                ),
              
              // Add some padding at the bottom to ensure the FAB doesn't obscure content
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }
  
  List<Widget> _buildNetPositionsTable(ProjectionGroup projection) {
    // Get net positions map
    final netPositions = projection.calculateNetPositions();
    
    // Group positions by currency
    Map<String, List<MapEntry<String, double>>> positionsByCurrency = {};
    
    for (var entry in netPositions.entries) {
      final parts = entry.key.split('->');
      if (parts.length < 2) continue;
      
      final userId = parts[0];
      final currency = parts[1];
      final amount = entry.value;
      
      // Skip very small amounts
      if (amount.abs() < 0.01) continue;
      
      if (!positionsByCurrency.containsKey(currency)) {
        positionsByCurrency[currency] = [];
      }
      
      positionsByCurrency[currency]!.add(MapEntry(userId, amount));
    }
    
    if (positionsByCurrency.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No outstanding balances',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        )
      ];
    }
    
    // Create a table for more space-efficient display
    return [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Table(
          columnWidths: const {
            0: IntrinsicColumnWidth(), // Currency column
            1: FlexColumnWidth(3),     // Details column (takes more space)
            2: IntrinsicColumnWidth(), // Settle button column
          },
          border: TableBorder.all(
            color: Colors.grey.shade300,
            width: 1,
            borderRadius: BorderRadius.circular(8.0),
          ),
          children: [
            // Table header with theme color
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Currency',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Net Positions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            // Table rows for each currency
            ...positionsByCurrency.entries.map((currencyEntry) {
              final currency = currencyEntry.key;
              final positions = currencyEntry.value;
              
              // Build the positions text for this currency
              List<Widget> positionWidgets = [];
              for (var position in positions) {
                final userId = position.key;
                final amount = position.value;
                
                // Try to find user in the projection
                User? user;
                try {
                  user = projection.users.firstWhere((u) => u.userId == userId);
                } catch (e) {
                  user = User(userId: userId, name: "Unknown", createdAt: "");
                }
                
                final isPositive = amount > 0;
                
                positionWidgets.add(
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Text(
                          '${user.name} ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${isPositive ? 'is owed' : 'owes'} ',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          NumberFormat('#,##0.00').format(amount.abs()),
                          style: TextStyle(
                            color: isPositive 
                                ? Theme.of(context).colorScheme.tertiary
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return TableRow(
                decoration: BoxDecoration(
                  color: positionsByCurrency.entries.toList().indexOf(currencyEntry) % 2 == 0
                      ? Colors.grey.shade50
                      : Colors.white,
                ),
                children: [
                  // Currency cell
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      currency,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  // Details cell with positions list
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: positionWidgets,
                    ),
                  ),
                  // Settle button cell
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showSettlementModal(currency, positions, projection),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        minimumSize: const Size(60, 30),
                      ),
                      child: const Text('Settle'),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    ];
  }

  Widget _buildExpenseCard(Event event, ProjectionGroup projection) {
    final expense = Expense.fromJson(event.payload);
    
    String payersText = expense.paidBy.map((payment) {
      User? user;
      try {
        user = projection.users.firstWhere((u) => u.userId == payment.userId);
      } catch (e) {
        user = null;
      }
      return '${user?.name ?? 'Unknown'} (${expense.currency} ${NumberFormat('#,##0.00').format(payment.amount)})';
    }).join(', ');
    
    String recipientsText = expense.paidFor.map((share) {
      User? user;
      try {
        user = projection.users.firstWhere((u) => u.userId == share.userId);
      } catch (e) {
        user = null;
      }
      return '${user?.name ?? 'Unknown'} (${NumberFormat('#,##0.00').format(share.amount)})';
    }).join(', ');
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(expense.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black),
                children: [
                  const TextSpan(
                    text: 'Paid by: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: payersText),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black),
                children: [
                  const TextSpan(
                    text: 'Paid for: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: recipientsText),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black),
                children: [
                  const TextSpan(
                    text: 'Recorded by: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: projection.users
                        .firstWhere(
                          (u) => u.userId == event.userId,
                          orElse: () => User(userId: event.userId, name: 'Unknown', createdAt: ''),
                        )
                        .name,
                  ),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black),
                children: [
                  const TextSpan(
                    text: 'Total: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: '${expense.currency} ${NumberFormat('#,##0.00').format(expense.total)}'),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black),
                children: [
                  const TextSpan(
                    text: 'Date: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: DateFormat('MMM d, yyyy HH:mm').format(expense.dateTime)),
                ],
              ),
            ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => _showDeleteConfirmation(event),
          tooltip: 'Delete expense',
        ),
      ),
    );
  }
}
