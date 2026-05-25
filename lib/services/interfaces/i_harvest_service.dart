// =============================================
// GROWLOG - HarvestService Interface
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';

abstract class IHarvestService {
  /// Lädt die Ernte für eine Pflanze
  Future<Harvest?> getHarvestForPlant(Plant plant);

  /// Aktualisiert eine Ernte mit Validierung der Phasenübergänge (QA-007).
  /// Wirft `HarvestTransitionException` bei illegalem Rückwärts-Übergang.
  Future<int> updateHarvestWithValidation(Harvest current, Harvest next);
}
