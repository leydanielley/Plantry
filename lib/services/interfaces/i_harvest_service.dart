// =============================================
// GROWLOG - HarvestService Interface
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';

abstract class IHarvestService {
  /// Lädt die Ernte für eine Pflanze
  Future<Harvest?> getHarvestForPlant(Plant plant);
}
