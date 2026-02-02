import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class BudgetProvider extends ChangeNotifier {
  // Key 1: Category ID, Key 2: Month (yyyy-MM), Value: Amount
  Map<String, Map<String, double>> _budgetData = {};
  
  // Key: Month (yyyy-MM), Value: Amount
  Map<String, double> _marginData = {};
  
  // Key: Month (yyyy-MM), Value: Amount
  Map<String, double> _manualInitialBalances = {};
  
  // Key: Month (yyyy-MM), Value: Note
  Map<String, String> _initialBalanceNotes = {};

  final FirestoreService _firestoreService = FirestoreService();
  String? _uid;

  BudgetProvider();

  void init(String uid) {
    _uid = uid;
    loadData();
  }

  void clear() {
    _uid = null;
    _budgetData = {};
    _marginData = {};
    _manualInitialBalances = {};
    _initialBalanceNotes = {};
    notifyListeners();
  }

  Map<String, Map<String, double>> get budgetData => _budgetData;
  Map<String, double> get marginData => _marginData;
  Map<String, double> get manualInitialBalances => _manualInitialBalances;
  Map<String, String> get initialBalanceNotes => _initialBalanceNotes;

  Future<void> loadData() async {
    if (_uid == null) return;
    try {
      final data = await _firestoreService.getBudget(_uid!);
        if (data != null && data['budgetData'] != null) {
        // Parse nested map
        _budgetData = {};
        final rawMap = data['budgetData'] as Map<String, dynamic>;
        
        _budgetData = rawMap.map((categoryId, monthsMap) {
          return MapEntry(
            categoryId,
            (monthsMap as Map<String, dynamic>).map((month, amount) {
              return MapEntry(month, (amount as num).toDouble());
            }),
          );
        });

        // Load Margen
        if (data['marginData'] != null) {
           final rawMargin = data['marginData'] as Map<String, dynamic>;
           _marginData = rawMargin.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }

        // Load Manual Initial Balances
        if (data['manualInitialBalances'] != null) {
           final rawManual = data['manualInitialBalances'] as Map<String, dynamic>;
           _manualInitialBalances = rawManual.map((k, v) => MapEntry(k, (v as num).toDouble()));
        }

        // Load Notes
        if (data['initialBalanceNotes'] != null) {
           final rawNotes = data['initialBalanceNotes'] as Map<String, dynamic>;
           _initialBalanceNotes = rawNotes.map((k, v) => MapEntry(k, v.toString()));
        }

        notifyListeners();
      } else {
        _initializeDefaultData();
      }
    } catch (e) {
      print('Error loading budget: $e');
      _initializeDefaultData();
    }
  }

  Future<void> _saveData() async {
    if (_uid == null) return;
    final data = {
      'budgetData': _budgetData,
      'marginData': _marginData,
      'manualInitialBalances': _manualInitialBalances,
      'initialBalanceNotes': _initialBalanceNotes,
    };

    await _firestoreService.saveBudget(_uid!, data);
  }

  void _initializeDefaultData() {
    // Initialize with requested default values for months 2025-04 to 2026-12
    final defaults = {
      '1': 0.0, // Ingresos laboraless
      '4': -23500.0,
      '5': -4500.0,
      '6': -15000.0,
      '7': -1000.0,
      '8': -3000.0,
      '9': -1500.0,
    };

    final start = DateTime(2025, 4);
    final end = DateTime(2026, 12);
    
    // Create range of months
    for (int i = 0; i <= (end.year - start.year) * 12 + end.month - start.month; i++) {
        final date = DateTime(start.year, start.month + i);
        final monthStr = "${date.year}-${date.month.toString().padLeft(2, '0')}";
        
        defaults.forEach((catId, amount) {
          if (!_budgetData.containsKey(catId)) {
            _budgetData[catId] = {};
          }
          if (!_budgetData[catId]!.containsKey(monthStr)) {
             _budgetData[catId]![monthStr] = amount;
          }
        });
    }
    
    
    // Initialize default Margin
    // _marginData['2025-04'] = 0.0; // Example if needed

    _saveData();
  }

  double getAmount(String categoryId, DateTime month) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    return _budgetData[categoryId]?[monthStr] ?? 0.0;
  }

  void updateAmount(String categoryId, DateTime month, double amount) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    if (!_budgetData.containsKey(categoryId)) {
      _budgetData[categoryId] = {};
    }
    _budgetData[categoryId]![monthStr] = amount;
    _saveData();
    notifyListeners();
  }

  double getTotalForMonth(DateTime month) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    double total = 0.0;
    
    _budgetData.forEach((_, months) {
      total += months[monthStr] ?? 0.0;
    });
    
    return total;
  }

  // --- MARGIN METHODS ---
  double getMargin(DateTime month) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    return _marginData[monthStr] ?? 0.0;
  }

  void updateMargin(DateTime month, double amount) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    _marginData[monthStr] = amount;
    _saveData();
    notifyListeners();
  }

  // --- MANUAL INITIAL BALANCE METHODS ---
  double? getManualInitialBalance(DateTime month) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    return _manualInitialBalances[monthStr];
  }

  String? getInitialBalanceNote(DateTime month) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    return _initialBalanceNotes[monthStr];
  }

  void updateManualInitialBalance(DateTime month, double amount, String note) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    _manualInitialBalances[monthStr] = amount;
    _initialBalanceNotes[monthStr] = note;
    _saveData();
    notifyListeners();
  }

  void clearManualInitialBalance(DateTime month) {
    final monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    _manualInitialBalances.remove(monthStr);
    _initialBalanceNotes.remove(monthStr);
    _saveData(); // Explicitly save the removal
    notifyListeners();
  }
}
