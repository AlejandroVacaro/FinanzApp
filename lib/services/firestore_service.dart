import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/transaction_model.dart';
import '../models/category.dart';
import '../models/assignment_rule.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Transactions ---

  Future<void> addTransaction(String uid, Transaction transaction) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transaction.id)
        .set(transaction.toJson());
  }

  Future<void> updateTransaction(String uid, Transaction transaction) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(transaction.id)
        .update(transaction.toJson());
  }


  Future<void> deleteTransaction(String uid, String id) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(id)
        .delete();
  }

  Stream<List<Transaction>> getTransactions(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        // Ensure ID is set from doc.id if not present
        var data = doc.data();
        data['id'] = doc.id; // Map key matches Transaction.fromJson expectation
        return Transaction.fromJson(data);
      }).toList();
    });
  }

  // --- Config (Categories & Rules) ---

  Future<void> saveCategory(String uid, Category category) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(category.id)
        .set(category.toMap());
  }

  Future<void> deleteCategory(String uid, String id) async {
     await _firestore.collection('users').doc(uid).collection('categories').doc(id).delete();
  }

  Stream<List<Category>> getCategories(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => Category.fromMap(d.data(), d.id)).toList());
  }

  Future<void> saveRule(String uid, AssignmentRule rule) async {
     await _firestore.collection('users').doc(uid).collection('rules').doc(rule.id).set(rule.toMap());
  }
  
  Future<void> deleteRule(String uid, String id) async {
     await _firestore.collection('users').doc(uid).collection('rules').doc(id).delete();
  }

  Stream<List<AssignmentRule>> getRules(String uid) {
      return _firestore.collection('users').doc(uid).collection('rules').snapshots()
      .map((s) => s.docs.map((d) => AssignmentRule.fromMap(d.data(), d.id)).toList());
  }

  Future<void> saveSettings(String uid, Map<String, dynamic> settings) async {
      await _firestore.collection('users').doc(uid).collection('config').doc('settings').set(settings);
  }

  Future<Map<String, dynamic>?> getSettings(String uid) async {
      final doc = await _firestore.collection('users').doc(uid).collection('config').doc('settings').get();
      return doc.data();
  }

  // --- Budget ---
  Future<void> saveBudget(String uid, Map<String, dynamic> budgetData) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('data')
        .doc('budget')
        .set(budgetData);
  }

  Future<Map<String, dynamic>?> getBudget(String uid) async {
    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('data')
        .doc('budget')
        .get();
    return doc.data();
  }
}
