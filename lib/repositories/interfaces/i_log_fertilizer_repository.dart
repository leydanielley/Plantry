// =============================================
// GROWLOG - LogFertilizerRepository Interface
// =============================================

import '../../models/log_fertilizer.dart';

abstract class ILogFertilizerRepository {
  Future<int> save(LogFertilizer logFertilizer);
  Future<void> saveForLog(int logId, List<LogFertilizer> fertilizers);
  Future<void> saveForLogs(List<int> logIds, Map<int, List<LogFertilizer>> fertilizersPerLog);
  Future<List<LogFertilizer>> findByLog(int logId);
  Future<Map<int, List<LogFertilizer>>> findByLogs(List<int> logIds);
  Future<void> delete(int id);
  Future<void> deleteByLog(int logId);
  Future<void> deleteByLogs(List<int> logIds);
}
