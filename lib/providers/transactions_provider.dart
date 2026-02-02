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
  
  Future<void> updateTransaction(Transaction tx) async {
      if (_uid == null) return;
      // Update full transaction (category, description, etc)
      await _firestoreService.updateTransaction(_uid!, tx);
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

    // 2. Add to Firestore (Batch)
    try {
      await _firestoreService.batchAddTransactionsChunked(_uid!, newTransactions);
    } catch (e) {
      throw "Error guardando movimientos: $e";
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

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> deleteTransactionsByRange({
    required DateTime start,
    required DateTime end,
    required String type // 'CUENTA_UYU', 'CUENTA_USD', 'TARJETA'
  }) async {
    if (_uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
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

      if (toDelete.isNotEmpty) {
         final ids = toDelete.map((e) => e.id).toList();
         await _firestoreService.batchDeleteTransactionsChunked(_uid!, ids);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> applyRuleToExistingTransactions(String keyword, String categoryName) async {
    if (_uid == null) return 0;
    
    final matchingTxs = _transactions.where((tx) =>
      tx.description.toLowerCase().contains(keyword.toLowerCase()) && 
      tx.category != categoryName
    ).toList();
    
    if (matchingTxs.isEmpty) return 0;
    
    final updatedTxs = matchingTxs.map((tx) => tx.copyWith(category: categoryName)).toList();
    
    // Update local state (Optimistic)
    // Note: Since _transactions is derived from firestore stream, 
    // we rely on the helper to push to backend, then stream will update list.
    // But for immediate feedback we can notify listeners if we manually updated local list,
    // however, the stream approach is safer.
    
    try {
      await _firestoreService.batchUpdateTransactionsChunked(_uid!, updatedTxs);
      return updatedTxs.length;
    } catch (e) {
      debugPrint("Error applying rule: $e");
      rethrow;
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
