import 'package:uddoygi/features/hr/domain/entities/benefit.dart';

abstract class BenefitRepository {
  Future<void> addBenefit(BenefitModel benefit);
  Future<void> updateBenefit(String id, BenefitModel benefit);
  Future<void> deleteBenefit(String id);
  Future<List<BenefitModel>> getAllBenefits();
  Future<List<BenefitModel>> getBenefitsByUser(String userId);
}
