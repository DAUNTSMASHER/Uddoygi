import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all attendance records
  Stream<QuerySnapshot> getAllAttendance() {
    return _firestore.collection('attendance').snapshots();
  }

  // Get attendance by user
  Stream<QuerySnapshot> getUserAttendance(String userId) {
    return _firestore
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  // Add a new attendance record
  Future<void> addAttendance({
    required String userId,
    required String date, // format: YYYY-MM-DD
    required String status, // 'present', 'absent', 'leave'
  }) async {
    await _firestore.collection('attendance').add({
      'userId': userId,
      'date': date,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update an attendance record
  Future<void> updateAttendance(String docId, Map<String, dynamic> data) async {
    await _firestore.collection('attendance').doc(docId).update(data);
  }

  // Delete an attendance record
  Future<void> deleteAttendance(String docId) async {
    await _firestore.collection('attendance').doc(docId).delete();
  }
}
