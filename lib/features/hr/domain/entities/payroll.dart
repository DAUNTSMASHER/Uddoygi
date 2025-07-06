import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/payroll_model.dart';

class PayrollDataSource {
  final CollectionReference _payrollCollection =
  FirebaseFirestore.instance.collection('payrolls');

  Future<void> addPayroll(PayrollModel payroll) async {
    try {
      await _payrollCollection.add(payroll.toJson());
    } catch (e) {
      print('Error adding payroll: $e');
      rethrow;
    }
  }

  Future<void> updatePayroll(String id, PayrollModel payroll) async {
    try {
      await _payrollCollection.doc(id).update(payroll.toJson());
    } catch (e) {
      print('Error updating payroll: $e');
      rethrow;
    }
  }

  Future<void> deletePayroll(String id) async {
    try {
      await _payrollCollection.doc(id).delete();
    } catch (e) {
      print('Error deleting payroll: $e');
      rethrow;
    }
  }

  Future<List<PayrollModel>> getPayrollsByEmployee(String employeeId) async {
    try {
      final querySnapshot = await _payrollCollection
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('period', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return PayrollModel.fromJson(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching payrolls by employee: $e');
      return [];
    }
  }

  Future<List<PayrollModel>> getAllPayrolls() async {
    try {
      final querySnapshot =
      await _payrollCollection.orderBy('period', descending: true).get();

      return querySnapshot.docs.map((doc) {
        return PayrollModel.fromJson(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Error fetching all payrolls: $e');
      return [];
    }
  }
}
