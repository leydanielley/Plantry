// =============================================
// GROWLOG - HarvestService Interface
// =============================================

import '../../models/plant.dart';
import '../../models/harvest.dart';

abstract class IHarvestService {
  /// Lädt die Ernte für eine Pflanze
  Future<Harvest?> getHarvestForPlant(Plant plant);
}
