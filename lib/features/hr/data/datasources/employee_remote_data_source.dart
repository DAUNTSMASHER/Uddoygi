import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class EmployeeRemoteDataSource {
  Future<String> _getCid() => LocalStorageService.getSavedCompanyId().then((v) => v ?? '');

  Stream<QuerySnapshot> getAllEmployees() async* {
    final cid = await _getCid();
    yield* DB.colSync(cid, C.employees).snapshots();
  }

  Future<DocumentSnapshot> getEmployeeById(String docId) async {
    final ref = await DB.doc(C.employees, docId);
    return ref.get();
  }

  Future<void> addEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String designation,
    required String joiningDate,
    required String status,
  }) async {
    final _cid = await _getCid();
    final col = DB.colSync(_cid, C.employees);
    await col.add({
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'department': department,
      'designation': designation,
      'joiningDate': joiningDate,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEmployee(String docId, Map<String, dynamic> data) async {
    final ref = await DB.doc(C.employees, docId);
    await ref.update(data);
  }

  Future<void> deleteEmployee(String docId) async {
    final ref = await DB.doc(C.employees, docId);
    await ref.delete();
  }
}
