import 'dart:convert';

import 'package:simple_split_mobile/models/projection.dart';
import 'package:simple_split_mobile/services/api_service.dart';

import '../models/event.dart';
import '../models/events/Expense.dart';
import '../models/events/currency.dart';
import '../models/projections/projection_group.dart';
import '../models/user.dart';
import 'database_service.dart';

class ProjectionService {
  final DatabaseService _dbService = DatabaseService();
  final ApiService _apiService = ApiService();

Future<void> reCalculateGroupProjections(String groupId) async {
  final events = await _dbService.getEvents(groupId);

  // First, identify all deleted expense IDs
  // For EXPENSE_DELETED events, the linkedEventId points to the original expense

  // Log all events to console for debugging and return early if none
  if (events == null || events.isEmpty) {
    print('No events found for group $groupId');
    return;
  }

  for (final e in events) {
    try {
      final payloadStr = e.payload is String ? e.payload : jsonEncode(e.payload);
      print('Event ${e.eventId}: type=${e.eventType}, linkedEventId=${e.linkedEventId}, payload=$payloadStr');
    } catch (err) {
      print('Failed to log event ${e.eventId}: $err');
    }
  }

    final deletedEventIds = events
        .where((event) => event.eventType == Event.expenseDeleted)
        .map((event) => event.linkedEventId)
        .where((id) => id != null) // Filter out null linkedEventIds
        .map((id) => id as String) // Cast to String
        .toSet();

    Map<String, User> userMap = {};
    List<String> currencies = [];
    // Create a new ProjectionGroup with empty debts to ensure deleted expenses don't affect calculations
    final projectionGroup = ProjectionGroup(users: [], currencies: [], debts: {});

    for (var value in events) {
      if (value.eventType == Event.groupUserJoined) {
        final user = User.fromJson(value.payload);
        userMap[user.userId] = user;
      }

      if (value.eventType == Event.groupAddCurrency) {
        Currency curr = Currency.fromJson(value.payload);
        currencies.add(curr.currency);
      }

      if (value.eventType == Event.groupRemoveCurrency) {
        Currency curr = Currency.fromJson(value.payload);
        currencies.remove(curr.currency);
      }

      // Only process expense if it hasn't been deleted
      if (value.eventType == Event.expenseCreated && !deletedEventIds.contains(value.eventId)) {
        Expense expense = Expense.fromJson(value.payload);

        final paidBy = expense.paidBy;   // List<Payment>
        final paidFor = expense.paidFor; // List<Share>

        // Calculate paid and owed
        Map<String, double> paid = {};
        Map<String, double> owed = {};

        for (var p in paidBy) {
          paid[p.userId] = (paid[p.userId] ?? 0) + p.amount;
        }

        for (var p in paidFor) {
          owed[p.userId] = (owed[p.userId] ?? 0) + p.amount;
        }

        // Build net balances: positive = owed money, negative = owes
        Map<String, double> net = {};

        userMap.keys.forEach((userId) {
          net[userId] = (paid[userId] ?? 0) - (owed[userId] ?? 0);
        });

        // Split into creditors and debtors
        final creditors = <String, double>{};
        final debtors = <String, double>{};

        net.forEach((userId, balance) {
          if (balance > 0) creditors[userId] = balance;
          if (balance < 0) debtors[userId] = -balance; // convert to positive owed amount
        });

        // Settle debts: debtors pay creditors
        for (var debtor in debtors.keys) {
          var amountToPay = debtors[debtor]!;

          for (var creditor in creditors.keys) {
            if (amountToPay == 0) break;

            var creditorAmount = creditors[creditor]!;

            final payment = amountToPay < creditorAmount
                ? amountToPay
                : creditorAmount;

            projectionGroup.addDebt(debtor, expense.currency, creditor, payment);

            amountToPay -= payment;
            creditors[creditor] = (creditors[creditor] ?? 0) - payment;
          }
        }
      }
    }

    // Copy users into projectionGroup - already deduplicated since we're using a map
    projectionGroup.users.addAll(userMap.values);
    projectionGroup.currencies.addAll(currencies.toSet()); // Ensure currencies are unique as well

    final projection = Projection(
      settingKey: groupId + Projection.suffixUsers,
      settingValue: jsonEncode(projectionGroup),
    );

    await _dbService.saveProjection(projection);

    // Sync users locally
    for (var userId in userMap.keys) {
      final fetchedUser = await _dbService.getUser(userId);
      if (fetchedUser == null) {
        _apiService.getUser(userId).then((fetchedUser) {
          _dbService.saveUser(fetchedUser);
        }).catchError((error) {
          print('Failed to fetch user $userId from server: $error');
        });
      }
    }
  }
  Future<ProjectionGroup> getGroupProjection(String groupId) async {
    final key = groupId + Projection.suffixUsers;

    final projection = await _dbService.getProjection(key);

    if (projection == null) {
      // No projection yet → return empty group projection
      return ProjectionGroup(
        users: [],
        currencies: [],
        debts: {},
      );
    }

    // Decode JSON into Map
    final Map<String, dynamic> map = jsonDecode(projection.settingValue);

    return ProjectionGroup.fromJson(map);
  }

}
