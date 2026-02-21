import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/payroll_model.dart';
import 'package:uddoygi/services/db.dart';

class PayrollDataSource {
  Future<CollectionReference> get _col => DB.col(C.payrolls);

  Future<void> addPayroll(PayrollModel payroll) async {
    await (await _col).add(payroll.toJson());
  }

  Future<void> updatePayroll(String id, PayrollModel payroll) async {
    await (await _col).doc(id).update(payroll.toJson());
  }

  Future<void> deletePayroll(String id) async {
    await (await _col).doc(id).delete();
  }

  Future<List<PayrollModel>> getPayrollsByEmployee(String employeeId) async {
    final snap = await (await _col)
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('period', descending: true)
        .get();
    return snap.docs
        .map((d) => PayrollModel.fromJson(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<List<PayrollModel>> getAllPayrolls() async {
    final snap = await (await _col).orderBy('period', descending: true).get();
    return snap.docs
        .map((d) => PayrollModel.fromJson(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }
}
