import 'package:uddoygi/features/hr/data/models/payroll_model.dart';

abstract class PayrollRepository {
  Future<void> addPayroll(PayrollModel payroll);
  Future<void> updatePayroll(String id, PayrollModel payroll);
  Future<void> deletePayroll(String id);
  Future<List<PayrollModel>> getAllPayrolls();
  Future<List<PayrollModel>> getPayrollsByEmployee(String employeeId);
}
