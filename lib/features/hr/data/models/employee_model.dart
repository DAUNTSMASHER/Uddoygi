class EmployeeModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final String joiningDate;
  final String status; // 'active', 'inactive'

  EmployeeModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.joiningDate,
    required this.status,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json, String docId) {
    return EmployeeModel(
      id: docId,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      department: json['department'] ?? '',
      designation: json['designation'] ?? '',
      joiningDate: json['joiningDate'] ?? '',
      status: json['status'] ?? 'inactive',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'department': department,
      'designation': designation,
      'joiningDate': joiningDate,
      'status': status,
    };
  }
}
