import 'package:uddoygi/features/hr/data/models/shift_model.dart';

abstract class ShiftRepository {
  Future<void> addShift(ShiftModel shift);
  Future<void> updateShift(String id, ShiftModel shift);
  Future<void> deleteShift(String id);
  Future<List<ShiftModel>> getAllShifts();
  Future<List<ShiftModel>> getShiftsByUser(String userId);
}
