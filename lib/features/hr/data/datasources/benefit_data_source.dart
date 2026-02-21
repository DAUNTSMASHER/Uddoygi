import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class BenefitDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllBenefits() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.benefits).snapshots();
  }

  Stream<QuerySnapshot> getUserBenefits(String userId) =>
      DB.stream(C.benefits, query: (c) => c.where('userId', isEqualTo: userId));

  Future<void> addBenefit({
    required String userId,
    required String benefitType,
    required double amount,
    required String status,
  }) async {
    final _cid = await _getCid();
    final col = DB.colSync(_cid, C.benefits);
    await col.add({
      'userId': userId,
      'benefitType': benefitType,
      'amount': amount,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBenefit(String docId, Map<String, dynamic> data) async {
    final ref = await DB.doc(C.benefits, docId);
    await ref.update(data);
  }

  Future<void> deleteBenefit(String docId) async {
    final ref = await DB.doc(C.benefits, docId);
    await ref.delete();
  }
}
