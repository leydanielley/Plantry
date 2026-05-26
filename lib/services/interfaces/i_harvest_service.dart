// =============================================
// GROWLOG - HarvestService Interface
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';

abstract class IHarvestService {
  /// Lädt die Ernte für eine Pflanze
  Future<Harvest?> getHarvestForPlant(Plant plant);

  /// Aktualisiert eine Ernte mit Validierung der Phasenübergänge (QA-007)
  /// und der chronologischen Reihenfolge der Datumsfelder.
  ///
  /// Wirft `HarvestOrderException` bei verletzter Datumsreihenfolge
  /// (z.B. `dryingEndDate` vor `dryingStartDate`) und
  /// `HarvestTransitionException` bei illegalem Rückwärts-Übergang.
  Future<int> updateHarvestWithValidation(Harvest current, Harvest next);
}
