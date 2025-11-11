// =============================================
// GROWLOG - Plant Provider (State Management)
// =============================================

import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';
import '../models/plant.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../utils/app_logger.dart';
import '../utils/async_value.dart';

/// Provider for managing plant state across the app
///
/// Usage:
/// ```dart
/// // In main.dart, wrap MaterialApp:
/// ChangeNotifierProvider(
///   create: (_) => PlantProvider(getIt<PlantRepository>()),
///   child: MaterialApp(...),
/// )
///
/// // In screens:
/// final provider = context.watch<PlantProvider>();
/// final plants = provider.plants;
///
/// // Or with Consumer:
/// Consumer<PlantProvider>(
///   builder: (context, provider, child) {
///     return switch (provider.plants) {
///       Loading() => CircularProgressIndicator(),
///       Success(:final data) => PlantList(data),
///       Error(:final message) => ErrorView(message),
///     };
///   },
/// )
/// ```
class PlantProvider with ChangeNotifier {
  final IPlantRepository _repository;

  PlantProvider(this._repository);

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  /// ✅ FIX: Track dispose state to prevent notifyListeners after dispose
  bool _disposed = false;

  /// ✅ CRITICAL FIX: Lock to prevent concurrent state modifications
  final _saveLock = Lock();

  /// List of all plants
  AsyncValue<List<Plant>> _plants = const Loading();

  /// Currently selected/viewed plant
  AsyncValue<Plant> _currentPlant = const Loading();

  /// Plants filtered by room
  AsyncValue<List<Plant>> _plantsByRoom = const Loading();

  /// Plants filtered by grow
  /// ✅ FIX: Changed from final to mutable so it can be updated
  AsyncValue<List<Plant>> _plantsByGrow = const Loading();

  // ═══════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════

  AsyncValue<List<Plant>> get plants => _plants;
  AsyncValue<Plant> get currentPlant => _currentPlant;
  AsyncValue<List<Plant>> get plantsByRoom => _plantsByRoom;
  AsyncValue<List<Plant>> get plantsByGrow => _plantsByGrow;

  // ═══════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════

  /// Load all plants (not archived)
  Future<void> loadPlants({int? limit, int? offset}) async {
    AppLogger.debug('PlantProvider', 'Loading plants', 'limit=$limit, offset=$offset');

    _plants = const Loading();
    _safeNotifyListeners();

    try {
      final plantList = await _repository.findAll(limit: limit, offset: offset);
      _plants = Success(plantList);
      AppLogger.info('PlantProvider', 'Loaded ${plantList.length} plants');
    } catch (e, stack) {
      _plants = Error('Failed to load plants', e, stack);
      AppLogger.error('PlantProvider', 'Failed to load plants', e, stack);
    }

    _safeNotifyListeners();
  }

  /// Load a single plant by ID
  Future<void> loadPlant(int id) async {
    AppLogger.debug('PlantProvider', 'Loading plant', id);

    _currentPlant = const Loading();
    _safeNotifyListeners();

    try {
      final plant = await _repository.findById(id);
      if (plant == null) {
        _currentPlant = Error('Plant not found with ID: $id');
      } else {
        _currentPlant = Success(plant);
        AppLogger.info('PlantProvider', 'Loaded plant', plant.name);
      }
    } catch (e, stack) {
      _currentPlant = Error('Failed to load plant', e, stack);
      AppLogger.error('PlantProvider', 'Failed to load plant', e, stack);
    }

    _safeNotifyListeners();
  }

  /// Load plants by room
  Future<void> loadPlantsByRoom(int roomId) async {
    AppLogger.debug('PlantProvider', 'Loading plants by room', roomId);

    _plantsByRoom = const Loading();
    _safeNotifyListeners();

    try {
      final plantList = await _repository.findByRoom(roomId);
      _plantsByRoom = Success(plantList);
      AppLogger.info('PlantProvider', 'Loaded ${plantList.length} plants for room');
    } catch (e, stack) {
      _plantsByRoom = Error('Failed to load plants by room', e, stack);
      AppLogger.error('PlantProvider', 'Failed to load plants by room', e, stack);
    }

    _safeNotifyListeners();
  }

  /// ✅ FIX: Added missing method to load plants by grow
  /// This method updates the _plantsByGrow state that was previously stuck in Loading
  Future<void> loadPlantsByGrow(int growId) async {
    AppLogger.debug('PlantProvider', 'Loading plants by grow', growId);

    _plantsByGrow = const Loading();
    _safeNotifyListeners();

    try {
      final plantList = await _repository.findByGrow(growId);
      _plantsByGrow = Success(plantList);
      AppLogger.info('PlantProvider', 'Loaded ${plantList.length} plants for grow');
    } catch (e, stack) {
      _plantsByGrow = Error('Failed to load plants by grow', e, stack);
      AppLogger.error('PlantProvider', 'Failed to load plants by grow', e, stack);
    }

    _safeNotifyListeners();
  }

  /// Save a plant (create or update)
  /// ✅ CRITICAL FIX: Wrapped in Lock to prevent concurrent save race conditions
  Future<bool> savePlant(Plant plant) async {
    AppLogger.debug('PlantProvider', 'Saving plant', plant.name);

    return await _saveLock.synchronized(() async {
      try {
        final savedPlant = await _repository.save(plant);

        // Update current plant if it's the same one
        if (_currentPlant case Success(:final data)) {
          if (data.id == savedPlant.id) {
            _currentPlant = Success(savedPlant);
          }
        }

        // Reload plants list to reflect changes
        await loadPlants();

        AppLogger.info('PlantProvider', '✅ Plant saved', savedPlant.name);
        return true;
      } catch (e, stack) {
        AppLogger.error('PlantProvider', 'Failed to save plant', e, stack);
        return false;
      }
    });
  }

  /// Delete a plant
  /// ✅ CRITICAL FIX: Wrapped in Lock to prevent concurrent delete race conditions
  Future<bool> deletePlant(int id) async {
    AppLogger.debug('PlantProvider', 'Deleting plant', id);

    return await _saveLock.synchronized(() async {
      try {
        await _repository.delete(id);

        // Clear current plant if it was deleted
        if (_currentPlant case Success(:final data)) {
          if (data.id == id) {
            _currentPlant = const Loading();
          }
        }

        // Reload plants list
        await loadPlants();

        AppLogger.info('PlantProvider', '✅ Plant deleted', id);
        return true;
      } catch (e, stack) {
        AppLogger.error('PlantProvider', 'Failed to delete plant', e, stack);
        return false;
      }
    });
  }

  /// Archive a plant
  /// ✅ CRITICAL FIX: Wrapped in Lock to prevent concurrent archive race conditions
  Future<bool> archivePlant(int id) async {
    AppLogger.debug('PlantProvider', 'Archiving plant', id);

    return await _saveLock.synchronized(() async {
      try {
        await _repository.archive(id);

        // Reload to reflect changes
        await loadPlants();

        AppLogger.info('PlantProvider', '✅ Plant archived', id);
        return true;
      } catch (e, stack) {
        AppLogger.error('PlantProvider', 'Failed to archive plant', e, stack);
        return false;
      }
    });
  }

  /// Refresh all data
  Future<void> refresh() async {
    AppLogger.debug('PlantProvider', 'Refreshing all plant data');
    await loadPlants();
  }

  /// Clear current plant selection
  void clearCurrentPlant() {
    _currentPlant = const Loading();
    _safeNotifyListeners();
  }

  /// Get plant count
  Future<int> getPlantCount() async {
    try {
      return await _repository.count();
    } catch (e) {
      AppLogger.error('PlantProvider', 'Failed to get plant count', e);
      return 0;
    }
  }

  // ═══════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════

  /// ✅ FIX: Override dispose to mark provider as disposed
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// ✅ FIX: Safe notifyListeners that checks dispose state
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
