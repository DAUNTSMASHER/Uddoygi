class Payslip {
  final String id;
  final String employeeId;
  final String period;
  final double baseSalary;
  final double bonus;
  final double deductions;
  final double netPay;
  final String status;
  final DateTime generatedAt;

  Payslip({
    required this.id,
    required this.employeeId,
    required this.period,
    required this.baseSalary,
    required this.bonus,
    required this.deductions,
    required this.netPay,
    required this.status,
    required this.generatedAt,
  });

  factory Payslip.fromJson(Map<String, dynamic> json, String docId) {
    return Payslip(
      id: docId,
      employeeId: json['employeeId'] ?? '',
      period: json['period'] ?? '',
      baseSalary: (json['baseSalary'] ?? 0).toDouble(),
      bonus: (json['bonus'] ?? 0).toDouble(),
      deductions: (json['deductions'] ?? 0).toDouble(),
      netPay: (json['netPay'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'period': period,
      'baseSalary': baseSalary,
      'bonus': bonus,
      'deductions': deductions,
      'netPay': netPay,
      'status': status,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}
