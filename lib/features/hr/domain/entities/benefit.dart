class BenefitModel {
  final String id;
  final String employeeId;
  final String benefitType; // e.g., Health Insurance, Bonus, Travel Allowance
  final double amount;
  final String description;
  final DateTime dateGranted;
  final String grantedBy;

  BenefitModel({
    required this.id,
    required this.employeeId,
    required this.benefitType,
    required this.amount,
    required this.description,
    required this.dateGranted,
    required this.grantedBy,
  });

  factory BenefitModel.fromJson(Map<String, dynamic> json, String docId) {
    return BenefitModel(
      id: docId,
      employeeId: json['employeeId'] ?? '',
      benefitType: json['benefitType'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      dateGranted: DateTime.parse(json['dateGranted']),
      grantedBy: json['grantedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'benefitType': benefitType,
      'amount': amount,
      'description': description,
      'dateGranted': dateGranted.toIso8601String(),
      'grantedBy': grantedBy,
    };
  }
}
