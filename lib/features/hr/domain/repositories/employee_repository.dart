import 'package:uddoygi/features/hr/domain/entities/employee.dart';

abstract class EmployeeRepository {
  Future<void> addEmployee(EmployeeModel employee);
  Future<void> updateEmployee(String id, EmployeeModel employee);
  Future<void> deleteEmployee(String id);
  Future<EmployeeModel?> getEmployeeById(String id);
  Future<List<EmployeeModel>> getAllEmployees();
}
