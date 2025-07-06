class LeaveModel {
  final String id;
  final String userId;
  final String startDate;
  final String endDate;
  final String reason;
  final String status;
  final String type;

  LeaveModel({
    required this.id,
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    required this.type,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json, String docId) {
    return LeaveModel(
      id: docId,
      userId: json['userId'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      type: json['type'] ?? 'casual',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'startDate': startDate,
      'endDate': endDate,
      'reason': reason,
      'status': status,
      'type': type,
    };
  }
}
