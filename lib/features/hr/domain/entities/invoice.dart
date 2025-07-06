class InvoiceModel {
  final String id;
  final String customerId;
  final String customerName;
  final String agentId;
  final String agentName;
  final String agentEmail;
  final List<Map<String, dynamic>> items;
  final double grandTotal;
  final double shippingCost;
  final double tax;
  final String country;
  final String note;
  final bool submitted;
  final String status;
  final DateTime date;
  final DateTime timestamp;

  InvoiceModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.agentId,
    required this.agentName,
    required this.agentEmail,
    required this.items,
    required this.grandTotal,
    required this.shippingCost,
    required this.tax,
    required this.country,
    required this.note,
    required this.submitted,
    required this.status,
    required this.date,
    required this.timestamp,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json, String docId) {
    return InvoiceModel(
      id: docId,
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      agentId: json['agentId'] ?? '',
      agentName: json['agentName'] ?? '',
      agentEmail: json['agentEmail'] ?? '',
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
      shippingCost: (json['shippingCost'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      country: json['country'] ?? '',
      note: json['note'] ?? '',
      submitted: json['submitted'] ?? false,
      status: json['status'] ?? '',
      date: DateTime.parse(json['date']),
      timestamp: (json['timestamp'] != null)
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'agentId': agentId,
      'agentName': agentName,
      'agentEmail': agentEmail,
      'items': items,
      'grandTotal': grandTotal,
      'shippingCost': shippingCost,
      'tax': tax,
      'country': country,
      'note': note,
      'submitted': submitted,
      'status': status,
      'date': date.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
