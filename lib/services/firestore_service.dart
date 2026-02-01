import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction_model.dart' as tm;
import '../models/config_models.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  // --- TRANSACTIONS ---

  Future<List<tm.Transaction>> getTransactions() async {
    if (_uid == null) return [];
    
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_uid)
          .collection('transactions')
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure ID matches Document ID
        return tm.Transaction.fromJson(data);
      }).toList();
    } catch (e) {
      print("Firestore Error (getTransactions): $e");
      return [];
    }
  }

  Future<void> addTransaction(tm.Transaction tx) async {
    if (_uid == null) return;
    // Use the ID from the model as the document ID
    await _db.collection('users').doc(_uid).collection('transactions').doc(tx.id).set(tx.toJson());
  }

  Future<void> updateTransaction(tm.Transaction tx) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('transactions').doc(tx.id).update(tx.toJson());
  }

  Future<void> deleteTransaction(String id) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('transactions').doc(id).delete();
  }

  // --- CATEGORIES ---

  Future<List<Category>> getCategories() async {
    if (_uid == null) return [];

    try {
      final snapshot = await _db.collection('users').doc(_uid).collection('categories').get();
      return snapshot.docs.map((doc) => Category.fromJson(doc.data())).toList();
    } catch (e) {
      print("Firestore Error (getCategories): $e");
      return []; // Caller should handle empty list (e.g., load defaults)
    }
  }

  Future<void> saveCategories(List<Category> categories) async {
    if (_uid == null) return;
    final batch = _db.batch();
    final col = _db.collection('users').doc(_uid).collection('categories');
    
    // Note: This is a full overwrite strategy for simplicity in this migration.
    // Ideally, we should diff, but since the Provider saves the whole list...
    
    // 1. Delete existing (Optional, but safe to avoid stale data)
    final existing = await col.get();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }
    
    // 2. Add new
    for (var cat in categories) {
      batch.set(col.doc(cat.id), cat.toJson());
    }
    await batch.commit();
  }
  
  // --- CONFIG / RULES ---
  
  Future<List<AssignmentRule>> getRules() async {
     if (_uid == null) return [];
     try {
       final snapshot = await _db.collection('users').doc(_uid).collection('rules').get();
       return snapshot.docs.map((doc) => AssignmentRule.fromJson(doc.data())).toList();
     } catch (e) {
       return [];
     }
  }

  Future<void> saveRules(List<AssignmentRule> rules) async {
    if (_uid == null) return;
    final batch = _db.batch();
    final col = _db.collection('users').doc(_uid).collection('rules');

    final existing = await col.get();
    for (var doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (var rule in rules) {
      batch.set(col.doc(rule.id), rule.toJson());
    }
    await batch.commit();
  }
  
  // --- SETTINGS ---
  
  Future<Map<String, dynamic>?> getSettings() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).collection('settings').doc('app_settings').get();
    return doc.data();
  }

  Future<void> saveSettings(Map<String, dynamic> data) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('settings').doc('app_settings').set(data);
  }
  
  // --- BUDGET ---
   Future<Map<String, dynamic>?> getBudget() async {
    if (_uid == null) return null;
    final doc = await _db.collection('users').doc(_uid).collection('budget').doc('current').get();
    return doc.data();
  }

  Future<void> saveBudget(Map<String, dynamic> data) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('budget').doc('current').set(data);
  }

}
