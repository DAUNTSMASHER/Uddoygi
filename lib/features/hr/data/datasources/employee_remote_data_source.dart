import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeRemoteDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all employees
  Stream<QuerySnapshot> getAllEmployees() {
    return _firestore.collection('employees').snapshots();
  }

  // Get single employee by ID
  Future<DocumentSnapshot> getEmployeeById(String docId) async {
    return await _firestore.collection('employees').doc(docId).get();
  }

  // Add a new employee
  Future<void> addEmployee({
    required String fullName,
    required String email,
    required String phone,
    required String department,
    required String designation,
    required String joiningDate,
    required String status, // 'active', 'inactive'
  }) async {
    await _firestore.collection('employees').add({
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

  // Update employee data
  Future<void> updateEmployee(String docId, Map<String, dynamic> updatedData) async {
    await _firestore.collection('employees').doc(docId).update(updatedData);
  }

  // Delete an employee
  Future<void> deleteEmployee(String docId) async {
    await _firestore.collection('employees').doc(docId).delete();
  }
}
