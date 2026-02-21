import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class PayrollDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllPayrolls() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.payrolls).snapshots();
  }

  Stream<QuerySnapshot> getUserPayrolls(String userId) =>
      DB.stream(C.payrolls,
          query: (c) => c
              .where('userId', isEqualTo: userId)
              .orderBy('month', descending: true));

  Future<void> addPayroll({
    required String userId,
    required String month,
    required double baseSalary,
    required double bonus,
    required double deductions,
    required double netSalary,
    required String status,
  }) async {
    final _cid = await _getCid();
    final col = DB.colSync(_cid, C.payrolls);
    await col.add({
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

  Future<void> updatePayroll(String docId, Map<String, dynamic> data) async {
    final ref = await DB.doc(C.payrolls, docId);
    await ref.update(data);
  }

  Future<void> deletePayroll(String docId) async {
    final ref = await DB.doc(C.payrolls, docId);
    await ref.delete();
  }
}
