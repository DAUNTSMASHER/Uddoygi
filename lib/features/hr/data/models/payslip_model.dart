class PayslipModel {
  final String id;
  final String employeeId;
  final String payrollId;
  final String issueDate;
  final double totalEarnings;
  final double totalDeductions;
  final double netPay;
  final String remarks;

  PayslipModel({
    required this.id,
    required this.employeeId,
    required this.payrollId,
    required this.issueDate,
    required this.totalEarnings,
    required this.totalDeductions,
    required this.netPay,
    required this.remarks,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json, String docId) {
    return PayslipModel(
      id: docId,
      employeeId: json['employeeId'] ?? '',
      payrollId: json['payrollId'] ?? '',
      issueDate: json['issueDate'] ?? '',
      totalEarnings: (json['totalEarnings'] ?? 0).toDouble(),
      totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
      netPay: (json['netPay'] ?? 0).toDouble(),
      remarks: json['remarks'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'payrollId': payrollId,
      'issueDate': issueDate,
      'totalEarnings': totalEarnings,
      'totalDeductions': totalDeductions,
      'netPay': netPay,
      'remarks': remarks,
    };
  }
}
