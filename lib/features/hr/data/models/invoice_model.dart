class InvoiceModel {
  final String id;
  final String agentId;
  final String agentName;
  final String agentEmail;
  final String customerId;
  final String customerName;
  final String country;
  final String date;
  final String note;
  final double grandTotal;
  final double tax;
  final double shippingCost;
  final bool submitted;
  final String status;
  final List<Map<String, dynamic>> items;

  InvoiceModel({
    required this.id,
    required this.agentId,
    required this.agentName,
    required this.agentEmail,
    required this.customerId,
    required this.customerName,
    required this.country,
    required this.date,
    required this.note,
    required this.grandTotal,
    required this.tax,
    required this.shippingCost,
    required this.submitted,
    required this.status,
    required this.items,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json, String docId) {
    return InvoiceModel(
      id: docId,
      agentId: json['agentId'] ?? '',
      agentName: json['agentName'] ?? '',
      agentEmail: json['agentEmail'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      country: json['country'] ?? '',
      date: json['date'] ?? '',
      note: json['note'] ?? '',
      grandTotal: (json['grandTotal'] ?? 0).toDouble(),
      tax: (json['tax'] ?? 0).toDouble(),
      shippingCost: (json['shippingCost'] ?? 0).toDouble(),
      submitted: json['submitted'] ?? false,
      status: json['status'] ?? 'draft',
      items: List<Map<String, dynamic>>.from(json['items'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'agentName': agentName,
      'agentEmail': agentEmail,
      'customerId': customerId,
      'customerName': customerName,
      'country': country,
      'date': date,
      'note': note,
      'grandTotal': grandTotal,
      'tax': tax,
      'shippingCost': shippingCost,
      'submitted': submitted,
      'status': status,
      'items': items,
    };
  }
}