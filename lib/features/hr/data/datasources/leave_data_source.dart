import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all leave requests
  Stream<QuerySnapshot> getAllLeaveRequests() {
    return _firestore.collection('leave_requests').snapshots();
  }

  // Get leave requests by user ID
  Stream<QuerySnapshot> getUserLeaveRequests(String userId) {
    return _firestore
        .collection('leave_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  // Add a new leave request
  Future<void> addLeaveRequest({
    required String userId,
    required String startDate, // format YYYY-MM-DD
    required String endDate,
    required String reason,
    required String status, // 'pending', 'approved', 'rejected'
  }) async {
    await _firestore.collection('leave_requests').add({
      'userId': userId,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update a leave request
  Future<void> updateLeaveRequest(String docId, Map<String, dynamic> updatedData) async {
    await _firestore.collection('leave_requests').doc(docId).update(updatedData);
  }

  // Delete a leave request
  Future<void> deleteLeaveRequest(String docId) async {
    await _firestore.collection('leave_requests').doc(docId).delete();
  }
}
