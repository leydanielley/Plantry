// =============================================
// GROWLOG - GrowRepository Interface
// =============================================

import '../../models/grow.dart';

abstract class IGrowRepository {
  Future<List<Grow>> getAll({bool includeArchived = false});
  Future<Grow?> getById(int id);
  Future<int> create(Grow grow);
  Future<int> update(Grow grow);
  Future<int> delete(int id);
  Future<int> archive(int id);
  Future<int> unarchive(int id);
  Future<int> getPlantCount(int growId);
  Future<Map<int, int>> getPlantCountsForGrows(List<int> growIds);
  Future<void> updatePhaseForAllPlants(int growId, String newPhase);
}
