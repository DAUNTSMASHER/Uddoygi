class ShiftModel {
  final String id;
  final String employeeId;
  final String shiftType; // e.g. Morning, Evening, Night
  final String startTime;
  final String endTime;
  final String date;
  final bool isPresent;

  ShiftModel({
    required this.id,
    required this.employeeId,
    required this.shiftType,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.isPresent,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json, String docId) {
    return ShiftModel(
      id: docId,
      employeeId: json['employeeId'] ?? '',
      shiftType: json['shiftType'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',
      date: json['date'] ?? '',
      isPresent: json['isPresent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'shiftType': shiftType,
      'startTime': startTime,
      'endTime': endTime,
      'date': date,
      'isPresent': isPresent,
    };
  }
}
