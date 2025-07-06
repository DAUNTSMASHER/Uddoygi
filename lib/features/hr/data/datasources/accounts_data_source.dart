import 'package:cloud_firestore/cloud_firestore.dart';

class AccountsDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all accounts (payables and receivables)
  Stream<QuerySnapshot> getAllAccounts() {
    return _firestore.collection('accounts').snapshots();
  }

  // Add a new account record
  Future<void> addAccount({
    required String type, // 'payable' or 'receivable'
    required double amount,
    required String description,
    required String status, // 'paid', 'unpaid'
    required String date,
  }) async {
    await _firestore.collection('accounts').add({
      'type': type,
      'amount': amount,
      'description': description,
      'status': status,
      'date': date,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update an existing account record
  Future<void> updateAccount(String docId, Map<String, dynamic> updatedData) async {
    await _firestore.collection('accounts').doc(docId).update(updatedData);
  }

  // Delete an account record
  Future<void> deleteAccount(String docId) async {
    await _firestore.collection('accounts').doc(docId).delete();
  }
}
