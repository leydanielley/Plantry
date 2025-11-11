// =============================================
// GROWLOG - Harvest Service
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/services/interfaces/i_harvest_service.dart';

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