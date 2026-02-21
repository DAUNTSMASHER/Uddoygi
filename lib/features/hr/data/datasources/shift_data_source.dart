import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class ShiftDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllShifts() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.shifts).snapshots();
  }

  Stream<QuerySnapshot> getUserShifts(String userId) =>
      DB.stream(C.shifts,
          query: (c) => c
              .where('userId', isEqualTo: userId)
              .orderBy('shiftDate', descending: true));

  Future<void> addShift({
    required String userId,
    required String shiftDate,
    required String startTime,
    required String endTime,
    required String shiftType,
  }) async {
    final _cid = await _getCid();
    final col = DB.colSync(_cid, C.shifts);
    await col.add({
      'userId': userId,
      'shiftDate': shiftDate,
      'startTime': startTime,
      'endTime': endTime,
      'shiftType': shiftType,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateShift(String docId, Map<String, dynamic> data) async {
    final ref = await DB.doc(C.shifts, docId);
    await ref.update(data);
  }

  Future<void> deleteShift(String docId) async {
    final ref = await DB.doc(C.shifts, docId);
    await ref.delete();
  }
}
