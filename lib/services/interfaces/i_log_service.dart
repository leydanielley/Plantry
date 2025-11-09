// =============================================
// GROWLOG - LogService Interface
// =============================================

import '../../models/plant.dart';
import '../../models/plant_log.dart';
import '../../models/enums.dart';

abstract class ILogService {
  /// Single Log speichern mit allen Relationen (Fertilizers + Photos)
  Future<PlantLog> saveSingleLog({
    required Plant plant,
    required PlantLog log,
    required Map<int, double> fertilizers,
    required List<String> photoPaths,
    PlantPhase? newPhase,
  });

  /// Bulk Log speichern für mehrere Pflanzen
  Future<List<int>> saveBulkLog({
    required List<int> plantIds,
    required DateTime logDate,
    required ActionType actionType,
    double? waterAmount,
    double? phIn,
    double? ecIn,
    double? phOut,
    double? ecOut,
    double? temperature,
    double? humidity,
    bool runoff = false,
    bool cleanse = false,
    String? note,
    required Map<int, double> fertilizers,
    required List<String> photoPaths,
    PlantPhase? newPhase,
  });

  /// Log mit allen Details laden (inkl. Fertilizers + Photos)
  Future<Map<String, dynamic>?> getLogWithDetails(int logId);

  /// Log kopieren (mit allen Relationen)
  Future<PlantLog?> copyLog({
    required int sourceLogId,
    required int targetPlantId,
    required DateTime newDate,
  });

  /// Log löschen (mit allen Relationen)
  Future<void> deleteLog(int logId);

  /// Mehrere Logs löschen (Batch)
  Future<void> deleteLogs(List<int> logIds);
}
