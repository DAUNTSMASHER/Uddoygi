class LedgerModel {
  final String id;
  final String account;
  final double amount;
  final String type; // debit or credit
  final String description;
  final String date;

  LedgerModel({
    required this.id,
    required this.account,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
  });

  factory LedgerModel.fromJson(Map<String, dynamic> json, String docId) {
    return LedgerModel(
      id: docId,
      account: json['account'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      type: json['type'] ?? 'debit',
      description: json['description'] ?? '',
      date: json['date'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account': account,
      'amount': amount,
      'type': type,
      'description': description,
      'date': date,
    };
  }
}