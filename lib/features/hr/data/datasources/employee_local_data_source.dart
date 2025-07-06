import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EmployeeLocalDataSource {
  static const String _employeeListKey = 'employee_list';

  // Save list of employees locally as JSON string
  Future<void> saveEmployeeList(List<Map<String, dynamic>> employees) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(employees);
    await prefs.setString(_employeeListKey, encoded);
  }

  // Load employee list from local storage
  Future<List<Map<String, dynamic>>> getEmployeeList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_employeeListKey);
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  // Clear local cache of employees
  Future<void> clearEmployeeList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_employeeListKey);
  }
}
