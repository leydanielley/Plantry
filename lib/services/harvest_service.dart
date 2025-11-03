// =============================================
// GROWLOG - Harvest Service
// =============================================

import '../models/plant.dart';
import '../models/harvest.dart';
import '../repositories/harvest_repository.dart';

class HarvestService {
  final HarvestRepository _harvestRepo = HarvestRepository();

  /// Lädt die Ernte für eine Pflanze
  Future<Harvest?> getHarvestForPlant(Plant plant) async {
    if (plant.id == null) return null;

    try {
      return await _harvestRepo.getHarvestByPlantId(plant.id!);
    } catch (e) {
      // Error loading harvest
      return null;
    }
  }
}