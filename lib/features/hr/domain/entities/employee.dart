class EmployeeModel {
  final String id;
  final String fullName;
  final String email;
  final String department;
  final String designation;
  final DateTime joiningDate;
  final bool isActive;
  final bool isHead;
  final String phone;
  final String address;

  EmployeeModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.department,
    required this.designation,
    required this.joiningDate,
    required this.isActive,
    required this.isHead,
    required this.phone,
    required this.address,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json, String docId) {
    return EmployeeModel(
      id: docId,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      department: json['department'] ?? '',
      designation: json['designation'] ?? '',
      joiningDate: DateTime.parse(json['joiningDate']),
      isActive: json['isActive'] ?? true,
      isHead: json['isHead'] ?? false,
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'email': email,
      'department': department,
      'designation': designation,
      'joiningDate': joiningDate.toIso8601String(),
      'isActive': isActive,
      'isHead': isHead,
      'phone': phone,
      'address': address,
    };
  }
}
