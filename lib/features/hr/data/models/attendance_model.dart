class AttendanceModel {
  final String id;
  final String userId;
  final String date; // Format: YYYY-MM-DD
  final String status; // present, absent, leave

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json, String docId) {
    return AttendanceModel(
      id: docId,
      userId: json['userId'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'absent',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'date': date,
      'status': status,
    };
  }
}