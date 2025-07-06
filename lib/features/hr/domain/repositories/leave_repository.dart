import 'package:uddoygi/features/hr/domain/entities/leave.dart';

abstract class LeaveRepository {
  Future<void> addLeave(LeaveModel leave);
  Future<void> updateLeave(String id, LeaveModel leave);
  Future<void> deleteLeave(String id);
  Future<LeaveModel?> getLeaveById(String id);
  Future<List<LeaveModel>> getAllLeaves();
  Future<List<LeaveModel>> getLeavesByUser(String userId);
}
