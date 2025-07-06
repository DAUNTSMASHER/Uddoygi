import 'package:uddoygi/features/hr/domain/entities/attendance.dart';

abstract class AttendanceRepository {
  Future<void> addAttendance(AttendanceModel attendance);
  Future<void> updateAttendance(String id, AttendanceModel attendance);
  Future<void> deleteAttendance(String id);
  Future<List<AttendanceModel>> getAllAttendances();
  Future<List<AttendanceModel>> getAttendancesByUser(String userId);
}
