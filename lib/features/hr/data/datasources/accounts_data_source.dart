import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class AccountsDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllAccounts() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.accounts).snapshots();
  }

  Future<void> addAccount({
    required String type,
    required double amount,
    required String description,
    required String status,
    required String date,
  }) async {
    final _cid = await _getCid();
    final col = DB.colSync(_cid, C.accounts);
    await col.add({
      'type': type,
      'amount': amount,
      'description': description,
      'status': status,
      'date': date,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAccount(String docId, Map<String, dynamic> data) async {
    final ref = await DB.doc(C.accounts, docId);
    await ref.update(data);
  }

  Future<void> deleteAccount(String docId) async {
    final ref = await DB.doc(C.accounts, docId);
    await ref.delete();
  }
}
