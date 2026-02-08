// =============================================
// GROWLOG - Mock Plant Repository (for testing)
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';

class MockPlantRepository implements IPlantRepository {
  final Map<int, Plant> _plants = {};
  int _nextId = 1;

  @override
  Future<List<Plant>> findAll({int? limit, int? offset}) async {
    final plants = _plants.values.where((p) => !p.archived).toList()
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    if (offset != null) {
      final start = offset < plants.length ? offset : plants.length;
      final end = limit != null && (start + limit) < plants.length
          ? start + limit
          : plants.length;
      return plants.sublist(start, end);
    }

    if (limit != null && limit < plants.length) {
      return plants.sublist(0, limit);
    }

    return plants;
  }

  @override
  Future<Plant?> findById(int id) async {
    return _plants[id];
  }

  @override
  Future<List<Plant>> findByRoom(int roomId) async {
    return _plants.values
        .where((p) => p.roomId == roomId && !p.archived)
        .toList();
  }

  @override
  Future<List<Plant>> findByGrow(int growId) async {
    return _plants.values
        .where((p) => p.growId == growId && !p.archived)
        .toList();
  }

  @override
  Future<Plant> save(Plant plant) async {
    if (plant.id == null) {
      final id = _nextId++;
      final saved = plant.copyWith(id: id);
      _plants[id] = saved;
      return saved;
    } else {
      _plants[plant.id!] = plant;
      return plant;
    }
  }

  @override
  Future<int> delete(int id) async {
    _plants.remove(id);
    return 1;
  }

  @override
  Future<int> archive(int id) async {
    final plant = _plants[id];
    if (plant != null) {
      _plants[id] = plant.copyWith(archived: true);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> update(Plant plant) async {
    if (plant.id != null) {
      _plants[plant.id!] = plant;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> count() async {
    return _plants.values.where((p) => !p.archived).length;
  }

  @override
  Future<int> getLogCount(int plantId) async {
    return 0; // Mock implementation
  }

  @override
  Future<List<Plant>> findByRdwcSystem(int systemId) async {
    return _plants.values
        .where((p) => p.rdwcSystemId == systemId && !p.archived)
        .toList();
  }

  @override
  Future<int> countLogsToBeDeleted(int plantId, DateTime newSeedDate) async {
    return 0; // Mock implementation
  }

  @override
  Future<Map<String, int>> getRelatedDataCounts(int plantId) async {
    // Mock implementation - return zero counts
    return {'logs': 0, 'photos': 0, 'harvests': 0};
  }

  @override
  Future<List<Plant>> findOrphans() async {
    // Mock implementation - find plants without grow_id AND room_id
    return _plants.values
        .where((p) => p.growId == null && p.roomId == null && !p.archived)
        .toList();
  }

  /// ✅ FIX #5: Mock implementation for bucket uniqueness check
  @override
  Future<bool> isBucketOccupied(
    int systemId,
    int bucketNumber, {
    int? excludePlantId,
  }) async {
    // Mock implementation - check if bucket is occupied
    return _plants.values.any((p) =>
        p.rdwcSystemId == systemId &&
        p.bucketNumber == bucketNumber &&
        p.id != excludePlantId &&
        !p.archived);
  }

  // Helper methods for testing
  void clear() {
    _plants.clear();
    _nextId = 1;
  }
}
