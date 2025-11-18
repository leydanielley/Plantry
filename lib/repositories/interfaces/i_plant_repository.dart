// =============================================
// GROWLOG - PlantRepository Interface
// =============================================

import 'package:growlog_app/models/plant.dart';

abstract class IPlantRepository {
  Future<List<Plant>> findAll({int? limit, int? offset});
  Future<Plant?> findById(int id);
  Future<List<Plant>> findByRoom(int roomId);
  Future<List<Plant>> findByGrow(
    int growId,
  ); // ✅ FIX: Added missing method for provider
  Future<Plant> save(Plant plant);
  Future<int> delete(int id);
  Future<int> archive(int id);
  Future<int> update(Plant plant);
  Future<int> count();
  Future<int> getLogCount(int plantId);
  Future<List<Plant>> findByRdwcSystem(int systemId);
  Future<bool> isBucketOccupied(
    int systemId,
    int bucketNumber, {
    int? excludePlantId,
  });
  Future<int> countLogsToBeDeleted(int plantId, DateTime newSeedDate);

  // ✅ DATA LOSS PREVENTION: Find orphaned plants
  /// Returns plants that have no grow_id AND no room_id (orphaned)
  /// These plants may have been "lost" when their grow/room was deleted
  Future<List<Plant>> findOrphans();

  // ✅ SOFT-DELETE: Get counts of related data for warning dialog
  Future<Map<String, int>> getRelatedDataCounts(int plantId);
}
