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
  Future<int> countLogsToBeDeleted(int plantId, DateTime newSeedDate);
}
