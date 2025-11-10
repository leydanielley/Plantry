// =============================================
// GROWLOG - FertilizerRepository Interface
// =============================================

import '../../models/fertilizer.dart';

abstract class IFertilizerRepository {
  Future<List<Fertilizer>> findAll();
  Future<Fertilizer?> findById(int id);
  Future<Fertilizer> save(Fertilizer fertilizer);
  Future<bool> isInUse(int id);
  Future<Map<String, int>> getUsageDetails(int id);
  Future<int> delete(int id);
  Future<int> count();
}
