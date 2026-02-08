// =============================================
// GROWLOG - PlantLogRepository Interface
// =============================================

import 'package:growlog_app/models/plant_log.dart';

abstract class IPlantLogRepository {
  Future<List<PlantLog>> findByPlant(
    int plantId, {
    int? limit,
    int? offset,
    bool includeArchived = false,
  });
  Future<PlantLog?> findById(int id);
  Future<PlantLog?> findByPlantAndDayNumber(
    int plantId,
    int dayNumber, {
    int? excludeLogId,
  });
  Future<List<PlantLog>> findByIds(List<int> ids);
  Future<PlantLog> save(PlantLog log);
  Future<int> delete(int id);
  Future<PlantLog?> findLastLog(int plantId, {bool includeArchived = false});
  Future<PlantLog?> getLastLogForPlant(int plantId);
  Future<int> getNextDayNumber(int plantId, {DateTime? forDate});
  Future<int> countByPlant(int plantId, {bool includeArchived = false});
  Future<List<PlantLog>> getRecentActivity({
    int limit = 20,
    bool includeArchived = false,
  });
  Future<List<PlantLog>> getRecentActivityByAction({
    required List<String> actionTypes,
    int limit = 20,
    bool includeArchived = false,
  });
  Future<List<Map<String, dynamic>>> getLogsWithDetails(
    int plantId, {
    bool includeArchived = false,
  });
  Future<List<int>> saveBatch(List<PlantLog> logs);
  Future<void> deleteBatch(List<int> logIds);
}
