class ARAPModel {
  final String id;
  final String type; // accounts_receivable or accounts_payable
  final String partyName;
  final double amount;
  final String description;
  final DateTime date;
  final String enteredBy;

  ARAPModel({
    required this.id,
    required this.type,
    required this.partyName,
    required this.amount,
    required this.description,
    required this.date,
    required this.enteredBy,
  });

  factory ARAPModel.fromJson(Map<String, dynamic> json, String docId) {
    return ARAPModel(
      id: docId,
      type: json['type'] ?? '',
      partyName: json['partyName'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      date: DateTime.parse(json['date']),
      enteredBy: json['enteredBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'partyName': partyName,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'enteredBy': enteredBy,
    };
  }
}
