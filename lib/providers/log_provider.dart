// =============================================
// GROWLOG - Log Provider (State Management)
// =============================================

import 'package:flutter/foundation.dart';
import '../models/plant_log.dart';
import '../repositories/plant_log_repository.dart';
import '../utils/app_logger.dart';
import '../utils/async_value.dart';

/// Provider for managing plant log state across the app
///
/// Usage:
/// ```dart
/// // In main.dart, add to MultiProvider:
/// ChangeNotifierProvider(
///   create: (_) => LogProvider(getIt<PlantLogRepository>()),
///   child: MaterialApp(...),
/// )
///
/// // In screens:
/// final provider = context.watch<LogProvider>();
/// final logs = provider.logsForPlant;
///
/// // Or with Consumer:
/// Consumer<LogProvider>(
///   builder: (context, provider, child) {
///     return switch (provider.logsForPlant) {
///       Loading() => CircularProgressIndicator(),
///       Success(:final data) => LogList(data),
///       Error(:final message) => ErrorView(message),
///     };
///   },
/// )
/// ```
class LogProvider with ChangeNotifier {
  final PlantLogRepository _repository;

  LogProvider(this._repository);

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  /// Logs for a specific plant
  AsyncValue<List<PlantLog>> _logsForPlant = const Loading();

  /// Currently selected/viewed log
  AsyncValue<PlantLog> _currentLog = const Loading();

  /// Recent activity across all plants
  AsyncValue<List<PlantLog>> _recentActivity = const Loading();

  /// Logs with details (includes fertilizers/photos)
  AsyncValue<List<Map<String, dynamic>>> _logsWithDetails = const Loading();

  /// Current plant ID being viewed
  int? _currentPlantId;

  // ═══════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════

  AsyncValue<List<PlantLog>> get logsForPlant => _logsForPlant;
  AsyncValue<PlantLog> get currentLog => _currentLog;
  AsyncValue<List<PlantLog>> get recentActivity => _recentActivity;
  AsyncValue<List<Map<String, dynamic>>> get logsWithDetails => _logsWithDetails;
  int? get currentPlantId => _currentPlantId;

  // ═══════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════

  /// Load logs for a specific plant
  Future<void> loadLogsForPlant(int plantId, {int? limit, int? offset}) async {
    AppLogger.debug(
      'LogProvider',
      'Loading logs for plant',
      'plantId=$plantId, limit=$limit, offset=$offset',
    );

    _currentPlantId = plantId;
    _logsForPlant = const Loading();
    notifyListeners();

    try {
      final logs = await _repository.findByPlant(
        plantId,
        limit: limit,
        offset: offset,
      );
      _logsForPlant = Success(logs);
      AppLogger.info('LogProvider', 'Loaded ${logs.length} logs for plant $plantId');
    } catch (e, stack) {
      _logsForPlant = Error('Failed to load logs', e, stack);
      AppLogger.error('LogProvider', 'Failed to load logs', e, stack);
    }

    notifyListeners();
  }

  /// Load logs with full details (includes fertilizers/photos)
  Future<void> loadLogsWithDetails(int plantId) async {
    AppLogger.debug('LogProvider', 'Loading logs with details', plantId);

    _logsWithDetails = const Loading();
    notifyListeners();

    try {
      final logs = await _repository.getLogsWithDetails(plantId);
      _logsWithDetails = Success(logs);
      AppLogger.info(
        'LogProvider',
        'Loaded ${logs.length} logs with details for plant $plantId',
      );
    } catch (e, stack) {
      _logsWithDetails = Error('Failed to load logs with details', e, stack);
      AppLogger.error('LogProvider', 'Failed to load logs with details', e, stack);
    }

    notifyListeners();
  }

  /// Load a single log by ID
  Future<void> loadLog(int id) async {
    AppLogger.debug('LogProvider', 'Loading log', id);

    _currentLog = const Loading();
    notifyListeners();

    try {
      final log = await _repository.findById(id);
      if (log == null) {
        _currentLog = Error('Log not found with ID: $id');
      } else {
        _currentLog = Success(log);
        AppLogger.info('LogProvider', 'Loaded log', 'day=${log.dayNumber}');
      }
    } catch (e, stack) {
      _currentLog = Error('Failed to load log', e, stack);
      AppLogger.error('LogProvider', 'Failed to load log', e, stack);
    }

    notifyListeners();
  }

  /// Load recent activity across all plants
  Future<void> loadRecentActivity({int limit = 20}) async {
    AppLogger.debug('LogProvider', 'Loading recent activity', 'limit=$limit');

    _recentActivity = const Loading();
    notifyListeners();

    try {
      final logs = await _repository.getRecentActivity(limit: limit);
      _recentActivity = Success(logs);
      AppLogger.info('LogProvider', 'Loaded ${logs.length} recent activities');
    } catch (e, stack) {
      _recentActivity = Error('Failed to load recent activity', e, stack);
      AppLogger.error('LogProvider', 'Failed to load recent activity', e, stack);
    }

    notifyListeners();
  }

  /// Save a log (create or update)
  Future<bool> saveLog(PlantLog log) async {
    AppLogger.debug('LogProvider', 'Saving log', 'day=${log.dayNumber}');

    try {
      final savedLog = await _repository.save(log);

      // Update current log if it's the same one
      if (_currentLog case Success(:final data)) {
        if (data.id == savedLog.id) {
          _currentLog = Success(savedLog);
        }
      }

      // Reload logs list if we're viewing the same plant
      if (_currentPlantId == log.plantId) {
        await loadLogsForPlant(_currentPlantId!);
      }

      AppLogger.info('LogProvider', '✅ Log saved', 'id=${savedLog.id}');
      return true;
    } catch (e, stack) {
      AppLogger.error('LogProvider', 'Failed to save log', e, stack);
      return false;
    }
  }

  /// Save multiple logs in a batch
  Future<bool> saveBatch(List<PlantLog> logs) async {
    AppLogger.debug('LogProvider', 'Saving batch of logs', 'count=${logs.length}');

    try {
      final ids = await _repository.saveBatch(logs);

      // Reload if any log belongs to current plant
      if (_currentPlantId != null &&
          logs.any((log) => log.plantId == _currentPlantId)) {
        await loadLogsForPlant(_currentPlantId!);
      }

      AppLogger.info('LogProvider', '✅ Batch saved', '${ids.length} logs');
      return true;
    } catch (e, stack) {
      AppLogger.error('LogProvider', 'Failed to save batch', e, stack);
      return false;
    }
  }

  /// Delete a log
  Future<bool> deleteLog(int id, {int? plantId}) async {
    AppLogger.debug('LogProvider', 'Deleting log', id);

    try {
      await _repository.delete(id);

      // Clear current log if it was deleted
      if (_currentLog case Success(:final data)) {
        if (data.id == id) {
          _currentLog = const Loading();
        }
      }

      // Reload logs list if we know the plant ID
      if (plantId != null && _currentPlantId == plantId) {
        await loadLogsForPlant(plantId);
      }

      AppLogger.info('LogProvider', '✅ Log deleted', id);
      return true;
    } catch (e, stack) {
      AppLogger.error('LogProvider', 'Failed to delete log', e, stack);
      return false;
    }
  }

  /// Delete multiple logs in a batch
  Future<bool> deleteBatch(List<int> logIds, {int? plantId}) async {
    AppLogger.debug('LogProvider', 'Deleting batch of logs', 'count=${logIds.length}');

    try {
      await _repository.deleteBatch(logIds);

      // Reload if we know the plant ID
      if (plantId != null && _currentPlantId == plantId) {
        await loadLogsForPlant(plantId);
      }

      AppLogger.info('LogProvider', '✅ Batch deleted', '${logIds.length} logs');
      return true;
    } catch (e, stack) {
      AppLogger.error('LogProvider', 'Failed to delete batch', e, stack);
      return false;
    }
  }

  /// Get last log for a plant
  Future<PlantLog?> getLastLogForPlant(int plantId) async {
    try {
      return await _repository.findLastLog(plantId);
    } catch (e) {
      AppLogger.error('LogProvider', 'Failed to get last log', e);
      return null;
    }
  }

  /// Get next day number for a plant
  Future<int> getNextDayNumber(int plantId, {DateTime? forDate}) async {
    try {
      return await _repository.getNextDayNumber(plantId, forDate: forDate);
    } catch (e) {
      AppLogger.error('LogProvider', 'Failed to get next day number', e);
      return 1;
    }
  }

  /// Get log count for a plant
  Future<int> getLogCountForPlant(int plantId) async {
    try {
      return await _repository.countByPlant(plantId);
    } catch (e) {
      AppLogger.error('LogProvider', 'Failed to get log count', e);
      return 0;
    }
  }

  /// Refresh current plant logs
  Future<void> refresh() async {
    if (_currentPlantId != null) {
      AppLogger.debug('LogProvider', 'Refreshing logs for plant', _currentPlantId);
      await loadLogsForPlant(_currentPlantId!);
    }
  }

  /// Clear current log selection
  void clearCurrentLog() {
    _currentLog = const Loading();
    notifyListeners();
  }

  /// Clear all logs state
  void clearAll() {
    _logsForPlant = const Loading();
    _currentLog = const Loading();
    _recentActivity = const Loading();
    _logsWithDetails = const Loading();
    _currentPlantId = null;
    notifyListeners();
  }
}
