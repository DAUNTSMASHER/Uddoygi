import 'package:cloud_firestore/cloud_firestore.dart';

class PayrollDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all payroll records
  Stream<QuerySnapshot> getAllPayrolls() {
    return _firestore.collection('payrolls').snapshots();
  }

  // Get payrolls by user ID
  Stream<QuerySnapshot> getUserPayrolls(String userId) {
    return _firestore
        .collection('payrolls')
        .where('userId', isEqualTo: userId)
        .orderBy('month', descending: true)
        .snapshots();
  }

  // Add a payroll record
  Future<void> addPayroll({
    required String userId,
    required String month,
    required double baseSalary,
    required double bonus,
    required double deductions,
    required double netSalary,
    required String status, // 'processed', 'pending'
  }) async {
    await _firestore.collection('payrolls').add({
      'userId': userId,
      'month': month,
      'baseSalary': baseSalary,
      'bonus': bonus,
      'deductions': deductions,
      'netSalary': netSalary,
      'status': status,
      'processedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update a payroll record
  Future<void> updatePayroll(String docId, Map<String, dynamic> data) async {
    await _firestore.collection('payrolls').doc(docId).update(data);
  }

  // Delete a payroll record
  Future<void> deletePayroll(String docId) async {
    await _firestore.collection('payrolls').doc(docId).delete();
  }
}
