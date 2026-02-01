import 'dart:async';
import 'package:flutter/material.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class TransactionsProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _subscription;
  String? _uid;

  // Initialize with User ID
  void init(String uid) {
    _uid = uid;
    _subscription?.cancel();
    _subscription = _firestoreService.getTransactions(uid).listen((data) {
      // Sort by date ascending
      data.sort((a, b) => a.date.compareTo(b.date));
      _transactions = _calculateRunningBalances(data).reversed.toList();
      notifyListeners();
    });
  }
  
  // Cleanup on logout
  void clear() {
    _subscription?.cancel();
    _transactions = [];
    _uid = null;
    notifyListeners(); // Notify UI to show empty state
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<Transaction> get transactions => _transactions;
  
  Future<void> updateTransactionCategory(Transaction tx, String newCategory) async {
      if (_uid == null) return;
      final updatedTx = tx.copyWith(category: newCategory);
      // Optimistic update not strictly needed as Stream will update, but good for UX if slow
      // leaving it to stream for simplicity and consistent state
      await _firestoreService.updateTransaction(_uid!, updatedTx);
  }

  // Getters for Dashboard
  double get totalIncome => _transactions
      .where((t) => t.amount > 0)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.amount < 0)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get currentBalance => _transactions.isNotEmpty ? _transactions.first.balance : 0.0; // reversed, so first is latest

  Future<void> addTransactions(List<Transaction> newTransactions) async {
    if (_uid == null || newTransactions.isEmpty) return;

    // 1. Validation: Check for ANY duplicate
    for (final newTx in newTransactions) {
      bool exists = _transactions.any((existingTx) =>
          existingTx.date.isAtSameMomentAs(newTx.date) &&
          existingTx.description == newTx.description &&
          existingTx.amount == newTx.amount);

      if (exists) {
        throw "Error: Se encontraron movimientos duplicados.";
      }
    }

    // 2. Add to Firestore
    for (var tx in newTransactions) {
      await _firestoreService.addTransaction(_uid!, tx);
    }
  }
  
  // --- Balance Screen Logic ---

  Map<String, double> get accountBalances {
    final Map<String, double> balances = {};
    for (var tx in _transactions) {
      if (!balances.containsKey(tx.sourceAccount)) {
        balances[tx.sourceAccount] = 0.0;
      }
      balances[tx.sourceAccount] = balances[tx.sourceAccount]! + tx.amount;
    }
    return balances;
  }

  double get netWorth => _transactions.fold(0.0, (sum, tx) => sum + tx.amount);

  double get totalAssets {
    double assets = 0.0;
    accountBalances.forEach((_, balance) {
      if (balance > 0) assets += balance;
    });
    return assets;
  }

  double get totalLiabilities {
    double liabilities = 0.0;
    accountBalances.forEach((_, balance) {
      if (balance < 0) liabilities += balance;
    });
    return liabilities;
  }

  Future<void> deleteTransactionsByRange({
    required DateTime start,
    required DateTime end,
    required String type // 'CUENTA_UYU', 'CUENTA_USD', 'TARJETA'
  }) async {
    if (_uid == null) return;

    final startDate = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);

    final toDelete = _transactions.where((t) {
      bool dateMatch = (t.date.isAfter(startDate) || t.date.isAtSameMomentAs(startDate)) && 
                       (t.date.isBefore(endDate) || t.date.isAtSameMomentAs(endDate));
      if (!dateMatch) return false;

      if (type == 'TODOS') return true;
      
      if (type == 'TARJETA') {
        return t.sourceAccount.toLowerCase().contains('visa');
      } else if (type == 'CUENTA_UYU') {
        return t.sourceAccount.toLowerCase().contains('caja') && t.currency == 'UYU';
      } else if (type == 'CUENTA_USD') {
        return t.sourceAccount.toLowerCase().contains('caja') && t.currency == 'USD';
      }
      return false;
    }).toList();

    for (var tx in toDelete) {
      await _firestoreService.deleteTransaction(_uid!, tx.id);
    }
  }

  List<Transaction> _calculateRunningBalances(List<Transaction> sortedTxs) {
    double runningBalance = 0.0;
    final List<Transaction> result = [];
    for (var tx in sortedTxs) {
      runningBalance += tx.amount;
      result.add(tx.copyWith(balance: runningBalance));
    }
    return result;
  }
}
