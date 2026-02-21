import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class AttendanceDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllAttendance() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.attendance).snapshots();
  }

  Stream<QuerySnapshot> getUserAttendance(String userId) =>
      DB.stream(C.attendance,
          query: (c) => c
              .where('userId', isEqualTo: userId)
              .orderBy('date', descending: true));

  Future<void> addAttendance({
    required String userId,
    required String date,
    required String status,
  }) async {
    final _cid = await _getCid();
    final col = DB.colSync(_cid, C.attendance);
    await col.add({
      'userId': userId,
      'date': date,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAttendance(String docId, Map<String, dynamic> data) async {
    final ref = await DB.doc(C.attendance, docId);
    await ref.update(data);
  }

  Future<void> deleteAttendance(String docId) async {
    final ref = await DB.doc(C.attendance, docId);
    await ref.delete();
  }
}
