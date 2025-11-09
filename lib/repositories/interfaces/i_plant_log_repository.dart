// =============================================
// GROWLOG - PlantLogRepository Interface
// =============================================

import '../../models/plant_log.dart';

abstract class IPlantLogRepository {
  Future<List<PlantLog>> findByPlant(int plantId, {int? limit, int? offset});
  Future<PlantLog?> findById(int id);
  Future<List<PlantLog>> findByIds(List<int> ids);
  Future<PlantLog> save(PlantLog log);
  Future<int> delete(int id);
  Future<PlantLog?> findLastLog(int plantId);
  Future<PlantLog?> getLastLogForPlant(int plantId);
  Future<int> getNextDayNumber(int plantId, {DateTime? forDate});
  Future<int> countByPlant(int plantId);
  Future<List<PlantLog>> getRecentActivity({int limit = 20});
  Future<List<PlantLog>> getRecentActivityByAction({
    required List<String> actionTypes,
    int limit = 20,
  });
  Future<List<Map<String, dynamic>>> getLogsWithDetails(int plantId);
  Future<List<int>> saveBatch(List<PlantLog> logs);
  Future<void> deleteBatch(List<int> logIds);
}
