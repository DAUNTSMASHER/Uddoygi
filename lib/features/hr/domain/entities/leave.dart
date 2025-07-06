class LeaveModel {
  final String id;
  final String employeeId;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // e.g., Sick Leave, Casual Leave
  final String reason;
  final String status; // Pending, Approved, Rejected
  final DateTime requestDate;
  final String approvedBy;

  LeaveModel({
    required this.id,
    required this.employeeId,
    required this.startDate,
    required this.endDate,
    required this.type,
    required this.reason,
    required this.status,
    required this.requestDate,
    required this.approvedBy,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json, String docId) {
    return LeaveModel(
      id: docId,
      employeeId: json['employeeId'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      type: json['type'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'Pending',
      requestDate: DateTime.parse(json['requestDate']),
      approvedBy: json['approvedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'type': type,
      'reason': reason,
      'status': status,
      'requestDate': requestDate.toIso8601String(),
      'approvedBy': approvedBy,
    };
  }
}
