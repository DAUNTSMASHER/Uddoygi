import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class LeaveDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllLeaveRequests() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.leaveRequests).snapshots();
  }

  Stream<QuerySnapshot> getUserLeaveRequests(String userId) async* {
    final col = DB.colSync(await _getCid(), C.leaveRequests);
    yield* col.where('userId', isEqualTo: userId)
        .orderBy('startDate', descending: true)
        .snapshots();
  }

  Future<void> addLeaveRequest({
    required String userId,
    required String startDate,
    required String endDate,
    required String reason,
    required String status,
  }) async {
    await (await DB.col(C.leaveRequests)).add({
      'userId': userId,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLeaveRequest(String docId, Map<String, dynamic> data) async =>
      (await DB.col(C.leaveRequests)).doc(docId).update(data);

  Future<void> deleteLeaveRequest(String docId) async =>
      (await DB.col(C.leaveRequests)).doc(docId).delete();
}
