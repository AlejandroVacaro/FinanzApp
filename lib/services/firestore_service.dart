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


  Future<void> batchAddTransactions(String uid, List<Transaction> transactions) async {
    final batch = _firestore.batch();
    int count = 0;
    
    // Firestore batch limit is 500
    for (var i = 0; i < transactions.length; i++) {
        final tx = transactions[i];
         // Ensure ID is valid or generate one if empty (Transaction model defaults it but let's be safe)
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('transactions')
            .doc(tx.id.isEmpty ? null : tx.id);
            
        batch.set(docRef, tx.toJson());
        count++;

        if (count == 499) {
           await batch.commit();
           count = 0;
           // New batch needed? Yes, create new one implicitly by calling batch() again? 
           // actually batch object cannot be reused easily.
           // Better approach: External loop chunking.
        }
    }
     // Commit remaining
    if (count > 0) await batch.commit();
  }
  
  // Revised method with proper chunking logic
  Future<void> batchAddTransactionsChunked(String uid, List<Transaction> transactions) async {
      int chunkSize = 450; 
      for (var i = 0; i < transactions.length; i += chunkSize) {
          final batch = _firestore.batch();
          final end = (i + chunkSize < transactions.length) ? i + chunkSize : transactions.length;
          final chunk = transactions.sublist(i, end);
          
          for (var tx in chunk) {
              final docRef = _firestore
                .collection('users')
                .doc(uid)
                .collection('transactions')
                .doc(tx.id);
              batch.set(docRef, tx.toJson());
          }
          await batch.commit();
      }
  }

  Future<void> batchDeleteTransactionsChunked(String uid, List<String> ids) async {
      int chunkSize = 450; 
      for (var i = 0; i < ids.length; i += chunkSize) {
          final batch = _firestore.batch();
          final end = (i + chunkSize < ids.length) ? i + chunkSize : ids.length;
          final chunkIds = ids.sublist(i, end);
          
          for (var id in chunkIds) {
              final docRef = _firestore.collection('users').doc(uid).collection('transactions').doc(id);
              batch.delete(docRef);
          }
          await batch.commit();
      }
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

  Future<void> batchAddRules(String uid, List<AssignmentRule> rules) async {
    final batch = _firestore.batch();
    for (var rule in rules) {
      final docRef = _firestore.collection('users').doc(uid).collection('rules').doc(); // Auto-ID
      // Correct ID in the object
      final ruleWithId = rule.copyWith(id: docRef.id);
      batch.set(docRef, ruleWithId.toMap());
    }
    await batch.commit();
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
  // --- Backup System ---
  
  Future<void> createBackup(String uid) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-'); // Safe for doc ID
    final backupRef = _firestore.collection('users').doc(uid).collection('backups').doc(timestamp);

    // 1. Fetch all data
    final txSnapshot = await _firestore.collection('users').doc(uid).collection('transactions').get();
    final catSnapshot = await _firestore.collection('users').doc(uid).collection('categories').get();
    final ruleSnapshot = await _firestore.collection('users').doc(uid).collection('rules').get();
    final budgetDoc = await _firestore.collection('users').doc(uid).collection('data').doc('budget').get();
    
    final txList = txSnapshot.docs.map((d) => d.data()..['id'] = d.id).toList();
    final catList = catSnapshot.docs.map((d) => d.data()..['id'] = d.id).toList();
    final ruleList = ruleSnapshot.docs.map((d) => d.data()..['id'] = d.id).toList();
    final budgetData = budgetDoc.data() ?? {};

    // 2. Create Payload
    final backupData = {
      'timestamp': DateTime.now().toIso8601String(),
      'transactions': txList,
      'categories': catList,
      'rules': ruleList,
      'budget': budgetData,
      'device': 'web',
      'version': '1.0'
    };

    // 3. Save
    await backupRef.set(backupData);
  }
}
