class BenefitModel {
  final String id;
  final String userId;
  final String benefitType;
  final double amount;
  final String status; // 'active' or 'inactive'

  BenefitModel({
    required this.id,
    required this.userId,
    required this.benefitType,
    required this.amount,
    required this.status,
  });

  factory BenefitModel.fromJson(Map<String, dynamic> json, String docId) {
    return BenefitModel(
      id: docId,
      userId: json['userId'] ?? '',
      benefitType: json['benefitType'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'inactive',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'benefitType': benefitType,
      'amount': amount,
      'status': status,
    };
  }
}
