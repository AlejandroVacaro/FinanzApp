import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import '../models/assignment_rule.dart';
import '../services/firestore_service.dart';

class ConfigProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String? _uid;
  StreamSubscription? _catSubscription;
  StreamSubscription? _ruleSubscription;

  ConfigProvider(); 

  double _exchangeRate = 42.5;

  List<Category> _categories = [];
  List<AssignmentRule> _rules = [];

  // Default initial data for new users
  final List<Category> _defaultCategories = [
    const Category(id: '1', name: 'Ingresos laborales', type: CategoryType.income, icon: 'work', color: '#4CAF50'),
    const Category(id: '2', name: 'Devoluciones de impuestos', type: CategoryType.income, icon: 'account_balance', color: '#4CAF50'),
    const Category(id: '3', name: 'Ingresos extra', type: CategoryType.income, icon: 'attach_money', color: '#4CAF50'),
    const Category(id: '4', name: 'Alquiler', type: CategoryType.expense, icon: 'home', color: '#F44336'),
    const Category(id: '5', name: 'Gastos comunes', type: CategoryType.expense, icon: 'apartment', color: '#F44336'),
    const Category(id: '6', name: 'Alimentación e higiene', type: CategoryType.expense, icon: 'restaurant', color: '#FF9800'),
    const Category(id: '7', name: 'Transporte', type: CategoryType.expense, icon: 'directions_bus', color: '#2196F3'),
    const Category(id: '8', name: 'UTE', type: CategoryType.expense, icon: 'lightbulb', color: '#FFC107'),
    const Category(id: '9', name: 'ANTEL', type: CategoryType.expense, icon: 'phone', color: '#2196F3'),
    const Category(id: '10', name: 'León', type: CategoryType.expense, icon: 'pets', color: '#795548'),
    const Category(id: '11', name: 'Vestimenta', type: CategoryType.expense, icon: 'checkroom', color: '#9C27B0'),
    const Category(id: '12', name: 'Suscripciones', type: CategoryType.expense, icon: 'subscriptions', color: '#607D8B'),
    const Category(id: '13', name: 'Salidas y ocio', type: CategoryType.expense, icon: 'movie', color: '#E91E63'),
    const Category(id: '14', name: 'Impuestos y tributos', type: CategoryType.expense, icon: 'gavel', color: '#607D8B'),
    const Category(id: '15', name: 'Estética', type: CategoryType.expense, icon: 'spa', color: '#E91E63'),
    const Category(id: '16', name: 'Retiro de efectivo', type: CategoryType.expense, icon: 'local_atm', color: '#4CAF50'),
    const Category(id: '17', name: 'Salud', type: CategoryType.expense, icon: 'local_hospital', color: '#F44336'),
    const Category(id: '18', name: 'Educación', type: CategoryType.expense, icon: 'school', color: '#2196F3'),
    const Category(id: '19', name: 'Artículos tecnológicos', type: CategoryType.expense, icon: 'computer', color: '#9E9E9E'),
    const Category(id: '20', name: 'Artículos del hogar', type: CategoryType.expense, icon: 'kitchen', color: '#795548'),
    const Category(id: '21', name: 'Otros egresos', type: CategoryType.expense, icon: 'category', color: '#9E9E9E'),
    const Category(id: '22', name: 'Ahorro', type: CategoryType.savings, icon: 'savings', color: '#4CAF50'),
    const Category(id: '23', name: 'Movimiento puente', type: CategoryType.transfer, icon: 'compare_arrows', color: '#9E9E9E'),
    const Category(id: '24', name: 'Categoría no asignada', type: CategoryType.transfer, icon: 'help_outline', color: '#9E9E9E'),
  ];

  void init(String uid) {
    _uid = uid;
    _catSubscription?.cancel();
    _ruleSubscription?.cancel();

    // Listen to Categories
    _catSubscription = _firestoreService.getCategories(uid).listen((cats) {
      if (cats.isEmpty) {
        _initializeDefaults(uid);
      } else {
        _categories = cats;
        notifyListeners();
      }
    });

    // Listen to Rules
    _ruleSubscription = _firestoreService.getRules(uid).listen((rules) {
      _rules = rules;
      notifyListeners();
    });

    // Load Settings
    _firestoreService.getSettings(uid).then((data) {
      if (data != null) {
        _exchangeRate = (data['rate'] as num?)?.toDouble() ?? 42.5;
        if (data['lastBackup'] != null) {
           _lastBackup = DateTime.tryParse(data['lastBackup']);
        }
        notifyListeners();
      }
    });
  }

  void clear() {
    _uid = null;
    _catSubscription?.cancel();
    _ruleSubscription?.cancel();
    _categories = [];
    _rules = [];
    notifyListeners();
  }
  
  void _initializeDefaults(String uid) async {
     for (var c in _defaultCategories) {
       await _firestoreService.saveCategory(uid, c);
     }
  }

  // Getters
  double get exchangeRate => _exchangeRate;
  List<Category> get categories => _categories;
  List<AssignmentRule> get rules => _rules;

  List<String> get incomeCategories => _categories
      .where((c) => c.type == CategoryType.income)
      .map((c) => c.name)
      .toList();

  List<String> get expenseCategories => _categories
      .where((c) => c.type == CategoryType.expense)
      .map((c) => c.name)
      .toList();

  // Setters & Logic
  void setExchangeRate(double value) {
    _exchangeRate = value;
    if (_uid != null) {
      _firestoreService.saveSettings(_uid!, {'rate': value});
    }
    notifyListeners();
  }

  void addCategory(String name, CategoryType type) {
    if (_uid == null) return;
    final cat = Category(
      id: const Uuid().v4(), 
      name: name, 
      type: type,
      icon: 'label',     // Default icon
      color: '#9E9E9E'   // Default color
    );
    _firestoreService.saveCategory(_uid!, cat);
  }

  void removeCategory(String id) {
    if (_uid == null) return;
    _firestoreService.deleteCategory(_uid!, id);
  }

  void addRule(String keyword, String categoryId) {
    if (_uid == null) return;
    final rule = AssignmentRule(id: const Uuid().v4(), keyword: keyword, categoryId: categoryId);
    _firestoreService.saveRule(_uid!, rule);
  }

  void removeRule(String id) {
    if (_uid == null) return;
    _firestoreService.deleteRule(_uid!, id);
  }

  // Missing method reimplementation
  void editRule(String id, String newKeyword, String newCategoryId) {
    if (_uid == null) return;
    // We assume strict matching for ID
    final rule = AssignmentRule(id: id, keyword: newKeyword, categoryId: newCategoryId);
    _firestoreService.saveRule(_uid!, rule);
  }

  String? getCategoryIdForDescription(String description) {
    for (var rule in _rules) {
      if (description.toLowerCase().contains(rule.keyword.toLowerCase())) {
        return rule.categoryId;
      }
    }
    return null;
  }

  Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  // Edit methods
  void editCategory(String id, String newName, CategoryType newType) {
    if (_uid == null) return;
     try {
       final cat = _categories.firstWhere((c) => c.id == id);
       
       final newCat = Category(
          id: id, 
          name: newName, 
          type: newType, 
          icon: cat.icon, 
          color: cat.color, 
          parentId: cat.parentId
        );
       _firestoreService.saveCategory(_uid!, newCat);
     } catch (e) {
       print("Category not found to edit: $id");
     }
  }

  // --- BACKUP & RESTORE ---
  
  DateTime? _lastBackup;
  DateTime? get lastBackup => _lastBackup;

  Future<void> performBackup() async {
     if (_uid == null) return;
     try {
       await _firestoreService.createBackup(_uid!);
       _lastBackup = DateTime.now();
       
       // Save timestamp to settings
       _firestoreService.saveSettings(_uid!, {
         'rate': _exchangeRate,
         'lastBackup': _lastBackup!.toIso8601String()
       });
       
       notifyListeners();
     } catch (e) {
       print("Backup failed: $e");
       rethrow;
     }
  }

  Future<void> performRestore(BuildContext context) async {
     // For now, restoring is complex (overwrite logic). 
     // We just show a message that backups are saved in Cloud.
     // If user truly wants to restore, we'd need a UI to pick which backup.
     ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Tus respaldos están seguros en Google Cloud.'))
     );
  }


}
