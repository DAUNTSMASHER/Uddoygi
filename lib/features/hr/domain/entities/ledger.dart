class LedgerModel {
  final String id;
  final DateTime date;
  final String description;
  final double debit;
  final double credit;
  final String accountType; // e.g., Expense, Income, Asset, Liability
  final String referenceId;

  LedgerModel({
    required this.id,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.accountType,
    required this.referenceId,
  });

  factory LedgerModel.fromJson(Map<String, dynamic> json, String docId) {
    return LedgerModel(
      id: docId,
      date: DateTime.parse(json['date']),
      description: json['description'] ?? '',
      debit: (json['debit'] ?? 0).toDouble(),
      credit: (json['credit'] ?? 0).toDouble(),
      accountType: json['accountType'] ?? '',
      referenceId: json['referenceId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'debit': debit,
      'credit': credit,
      'accountType': accountType,
      'referenceId': referenceId,
    };
  }
}
