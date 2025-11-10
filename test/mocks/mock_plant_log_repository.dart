// =============================================
// GROWLOG - Mock Plant Log Repository (for testing)
// =============================================

import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';

class MockPlantLogRepository implements IPlantLogRepository {
  final Map<int, PlantLog> _logs = {};
  int _nextId = 1;

  @override
  Future<List<PlantLog>> findByPlant(int plantId, {int? limit, int? offset}) async {
    final logs = _logs.values
        .where((log) => log.plantId == plantId)
        .toList()
      ..sort((a, b) => b.logDate.compareTo(a.logDate));

    if (offset != null) {
      final start = offset < logs.length ? offset : logs.length;
      final end = limit != null && (start + limit) < logs.length
          ? start + limit
          : logs.length;
      return logs.sublist(start, end);
    }

    if (limit != null && limit < logs.length) {
      return logs.sublist(0, limit);
    }

    return logs;
  }

  @override
  Future<PlantLog?> findById(int id) async {
    return _logs[id];
  }

  @override
  Future<List<PlantLog>> findByIds(List<int> ids) async {
    return ids.map((id) => _logs[id]).whereType<PlantLog>().toList();
  }

  @override
  Future<PlantLog> save(PlantLog log) async {
    if (log.id == null) {
      final id = _nextId++;
      final saved = log.copyWith(id: id);
      _logs[id] = saved;
      return saved;
    } else {
      _logs[log.id!] = log;
      return log;
    }
  }

  @override
  Future<int> delete(int id) async {
    _logs.remove(id);
    return 1;
  }

  @override
  Future<PlantLog?> findLastLog(int plantId) async {
    final logs = await findByPlant(plantId, limit: 1);
    return logs.isEmpty ? null : logs.first;
  }

  @override
  Future<PlantLog?> getLastLogForPlant(int plantId) async {
    return findLastLog(plantId);
  }

  @override
  Future<int> getNextDayNumber(int plantId, {DateTime? forDate}) async {
    final logs = _logs.values.where((log) => log.plantId == plantId).toList();
    if (logs.isEmpty) return 1;

    final maxDay = logs.map((log) => log.dayNumber).reduce((a, b) => a > b ? a : b);
    return maxDay + 1;
  }

  @override
  Future<int> countByPlant(int plantId) async {
    return _logs.values.where((log) => log.plantId == plantId).length;
  }

  @override
  Future<List<PlantLog>> getRecentActivity({int limit = 10}) async {
    final logs = _logs.values.toList()
      ..sort((a, b) => b.logDate.compareTo(a.logDate));
    return logs.take(limit).toList();
  }

  @override
  Future<List<PlantLog>> getRecentActivityByAction({
    required List<String> actionTypes,
    int limit = 10,
  }) async {
    final logs = _logs.values
        .where((log) => actionTypes.contains(log.actionType.name))
        .toList()
      ..sort((a, b) => b.logDate.compareTo(a.logDate));
    return logs.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLogsWithDetails(int plantId) async {
    final logs = await findByPlant(plantId);
    return logs.map((log) => {
      'log': log,
      'fertilizers': [],
      'photos': [],
    }).toList();
  }

  @override
  Future<List<int>> saveBatch(List<PlantLog> logs) async {
    final ids = <int>[];
    for (final log in logs) {
      final saved = await save(log);
      if (saved.id != null) {
        ids.add(saved.id!);
      }
    }
    return ids;
  }

  @override
  Future<void> deleteBatch(List<int> ids) async {
    for (final id in ids) {
      _logs.remove(id);
    }
  }

  // Helper methods for testing
  void clear() {
    _logs.clear();
    _nextId = 1;
  }
}
