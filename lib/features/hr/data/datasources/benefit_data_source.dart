import 'package:cloud_firestore/cloud_firestore.dart';

class BenefitDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all benefits
  Stream<QuerySnapshot> getAllBenefits() {
    return _firestore.collection('benefits').snapshots();
  }

  // Get benefits by user
  Stream<QuerySnapshot> getUserBenefits(String userId) {
    return _firestore
        .collection('benefits')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  // Add a new benefit record
  Future<void> addBenefit({
    required String userId,
    required String benefitType,
    required double amount,
    required String status, // 'active', 'inactive'
  }) async {
    await _firestore.collection('benefits').add({
      'userId': userId,
      'benefitType': benefitType,
      'amount': amount,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update a benefit record
  Future<void> updateBenefit(String docId, Map<String, dynamic> data) async {
    await _firestore.collection('benefits').doc(docId).update(data);
  }

  // Delete a benefit record
  Future<void> deleteBenefit(String docId) async {
    await _firestore.collection('benefits').doc(docId).delete();
  }
}
