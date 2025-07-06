import 'package:cloud_firestore/cloud_firestore.dart';

class ShiftDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all shift assignments
  Stream<QuerySnapshot> getAllShifts() {
    return _firestore.collection('shifts').snapshots();
  }

  // Stream shifts by user ID
  Stream<QuerySnapshot> getUserShifts(String userId) {
    return _firestore
        .collection('shifts')
        .where('userId', isEqualTo: userId)
        .orderBy('shiftDate', descending: true)
        .snapshots();
  }

  // Add a shift entry
  Future<void> addShift({
    required String userId,
    required String shiftDate, // YYYY-MM-DD
    required String startTime, // e.g., 09:00
    required String endTime,   // e.g., 17:00
    required String shiftType, // Morning, Night, etc.
  }) async {
    await _firestore.collection('shifts').add({
      'userId': userId,
      'shiftDate': shiftDate,
      'startTime': startTime,
      'endTime': endTime,
      'shiftType': shiftType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update a shift record
  Future<void> updateShift(String docId, Map<String, dynamic> updatedData) async {
    await _firestore.collection('shifts').doc(docId).update(updatedData);
  }

  // Delete a shift record
  Future<void> deleteShift(String docId) async {
    await _firestore.collection('shifts').doc(docId).delete();
  }
}
