class AttendanceModel {
  final String id;
  final String userId;
  final String date;
  final String status; // Present, Absent, Late, etc.
  final String markedBy;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.status,
    required this.markedBy,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json, String docId) {
    return AttendanceModel(
      id: docId,
      userId: json['userId'] ?? '',
      date: json['date'] ?? '',
      status: json['status'] ?? 'Absent',
      markedBy: json['markedBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'date': date,
      'status': status,
      'markedBy': markedBy,
    };
  }
}
