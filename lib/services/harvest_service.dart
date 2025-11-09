// =============================================
// GROWLOG - Harvest Service
// =============================================

import '../models/plant.dart';
import '../models/harvest.dart';
import '../repositories/interfaces/i_harvest_repository.dart';
import 'interfaces/i_harvest_service.dart';

class HarvestService implements IHarvestService {
  final IHarvestRepository _harvestRepo;

  HarvestService(this._harvestRepo);

  /// Lädt die Ernte für eine Pflanze
  @override
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