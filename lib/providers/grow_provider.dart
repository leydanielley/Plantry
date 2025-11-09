// =============================================
// GROWLOG - Grow Provider (State Management)
// =============================================

import 'package:flutter/foundation.dart';
import '../models/grow.dart';
import '../repositories/interfaces/i_grow_repository.dart';
import '../utils/app_logger.dart';
import '../utils/async_value.dart';

/// Provider for managing grow state across the app
///
/// Usage:
/// ```dart
/// // In main.dart, add to MultiProvider:
/// ChangeNotifierProvider(
///   create: (_) => GrowProvider(getIt<GrowRepository>()),
///   child: MaterialApp(...),
/// )
///
/// // In screens:
/// final provider = context.watch<GrowProvider>();
/// final grows = provider.grows;
///
/// // Or with Consumer:
/// Consumer<GrowProvider>(
///   builder: (context, provider, child) {
///     return switch (provider.grows) {
///       Loading() => CircularProgressIndicator(),
///       Success(:final data) => GrowList(data),
///       Error(:final message) => ErrorView(message),
///     };
///   },
/// )
/// ```
class GrowProvider with ChangeNotifier {
  final IGrowRepository _repository;

  GrowProvider(this._repository);

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  /// List of all grows
  AsyncValue<List<Grow>> _grows = const Loading();

  /// Currently selected/viewed grow
  AsyncValue<Grow> _currentGrow = const Loading();

  /// Plant counts for grows (growId -> count)
  Map<int, int> _plantCounts = {};

  // ═══════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════

  AsyncValue<List<Grow>> get grows => _grows;
  AsyncValue<Grow> get currentGrow => _currentGrow;
  Map<int, int> get plantCounts => _plantCounts;

  // ═══════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════

  /// Load all grows (not archived by default)
  Future<void> loadGrows({bool includeArchived = false}) async {
    AppLogger.debug(
      'GrowProvider',
      'Loading grows',
      'includeArchived=$includeArchived',
    );

    _grows = const Loading();
    notifyListeners();

    try {
      final growList = await _repository.getAll(includeArchived: includeArchived);
      _grows = Success(growList);

      // Load plant counts for all grows
      if (growList.isNotEmpty) {
        final growIds = growList.map((g) => g.id!).toList();
        _plantCounts = await _repository.getPlantCountsForGrows(growIds);
      }

      AppLogger.info('GrowProvider', 'Loaded ${growList.length} grows');
    } catch (e, stack) {
      _grows = Error('Failed to load grows', e, stack);
      AppLogger.error('GrowProvider', 'Failed to load grows', e, stack);
    }

    notifyListeners();
  }

  /// Load a single grow by ID
  Future<void> loadGrow(int id) async {
    AppLogger.debug('GrowProvider', 'Loading grow', id);

    _currentGrow = const Loading();
    notifyListeners();

    try {
      final grow = await _repository.getById(id);
      if (grow == null) {
        _currentGrow = Error('Grow not found with ID: $id');
      } else {
        _currentGrow = Success(grow);
        AppLogger.info('GrowProvider', 'Loaded grow', grow.name);
      }
    } catch (e, stack) {
      _currentGrow = Error('Failed to load grow', e, stack);
      AppLogger.error('GrowProvider', 'Failed to load grow', e, stack);
    }

    notifyListeners();
  }

  /// Create a new grow
  Future<bool> createGrow(Grow grow) async {
    AppLogger.debug('GrowProvider', 'Creating grow', grow.name);

    try {
      final id = await _repository.create(grow);
      final createdGrow = grow.copyWith(id: id);
      _currentGrow = Success(createdGrow);

      // Reload grows list to reflect changes
      await loadGrows();

      AppLogger.info('GrowProvider', '✅ Grow created', grow.name);
      return true;
    } catch (e, stack) {
      AppLogger.error('GrowProvider', 'Failed to create grow', e, stack);
      return false;
    }
  }

  /// Update an existing grow
  Future<bool> updateGrow(Grow grow) async {
    AppLogger.debug('GrowProvider', 'Updating grow', grow.name);

    try {
      await _repository.update(grow);

      // Update current grow if it's the same one
      if (_currentGrow case Success(:final data)) {
        if (data.id == grow.id) {
          _currentGrow = Success(grow);
        }
      }

      // Reload grows list to reflect changes
      await loadGrows();

      AppLogger.info('GrowProvider', '✅ Grow updated', grow.name);
      return true;
    } catch (e, stack) {
      AppLogger.error('GrowProvider', 'Failed to update grow', e, stack);
      return false;
    }
  }

  /// Delete a grow
  Future<bool> deleteGrow(int id) async {
    AppLogger.debug('GrowProvider', 'Deleting grow', id);

    try {
      await _repository.delete(id);

      // Clear current grow if it was deleted
      if (_currentGrow case Success(:final data)) {
        if (data.id == id) {
          _currentGrow = const Loading();
        }
      }

      // Reload grows list
      await loadGrows();

      AppLogger.info('GrowProvider', '✅ Grow deleted', id);
      return true;
    } catch (e, stack) {
      AppLogger.error('GrowProvider', 'Failed to delete grow', e, stack);
      return false;
    }
  }

  /// Archive a grow
  Future<bool> archiveGrow(int id) async {
    AppLogger.debug('GrowProvider', 'Archiving grow', id);

    try {
      await _repository.archive(id);

      // Reload to reflect changes
      await loadGrows();

      AppLogger.info('GrowProvider', '✅ Grow archived', id);
      return true;
    } catch (e, stack) {
      AppLogger.error('GrowProvider', 'Failed to archive grow', e, stack);
      return false;
    }
  }

  /// Unarchive a grow
  Future<bool> unarchiveGrow(int id) async {
    AppLogger.debug('GrowProvider', 'Unarchiving grow', id);

    try {
      await _repository.unarchive(id);

      // Reload to reflect changes
      await loadGrows();

      AppLogger.info('GrowProvider', '✅ Grow unarchived', id);
      return true;
    } catch (e, stack) {
      AppLogger.error('GrowProvider', 'Failed to unarchive grow', e, stack);
      return false;
    }
  }

  /// Update phase for all plants in a grow
  Future<bool> updatePhaseForAllPlants(int growId, String newPhase) async {
    AppLogger.debug(
      'GrowProvider',
      'Updating phase for all plants in grow',
      'growId=$growId, phase=$newPhase',
    );

    try {
      await _repository.updatePhaseForAllPlants(growId, newPhase);

      // Reload current grow if it matches
      if (_currentGrow case Success(:final data)) {
        if (data.id == growId) {
          await loadGrow(growId);
        }
      }

      AppLogger.info(
        'GrowProvider',
        '✅ Updated phase for all plants in grow',
        newPhase,
      );
      return true;
    } catch (e, stack) {
      AppLogger.error(
        'GrowProvider',
        'Failed to update phase for plants',
        e,
        stack,
      );
      return false;
    }
  }

  /// Get plant count for a specific grow
  int getPlantCountForGrow(int growId) {
    return _plantCounts[growId] ?? 0;
  }

  /// Refresh all data
  Future<void> refresh() async {
    AppLogger.debug('GrowProvider', 'Refreshing all grow data');
    await loadGrows();
  }

  /// Clear current grow selection
  void clearCurrentGrow() {
    _currentGrow = const Loading();
    notifyListeners();
  }
}
