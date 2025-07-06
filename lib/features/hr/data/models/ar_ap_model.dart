class ArApModel {
  final String id;
  final String type; // 'payable' or 'receivable'
  final double amount;
  final String description;
  final String date;
  final String status; // 'paid', 'unpaid'

  ArApModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.date,
    required this.status,
  });

  factory ArApModel.fromJson(Map<String, dynamic> json, String docId) {
    return ArApModel(
      id: docId,
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'unpaid',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'amount': amount,
      'description': description,
      'date': date,
      'status': status,
    };
  }
}
