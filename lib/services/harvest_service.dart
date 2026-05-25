// =============================================
// GROWLOG - Harvest Service
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/services/interfaces/i_harvest_service.dart';

/// Logische Ernte-Phasen, abgeleitet aus den gesetzten Datumsfeldern eines
/// [Harvest]-Eintrags. Diese werden nicht in der Datenbank gespeichert, sondern
/// dienen als State-Machine-Knoten für die Übergangs-Validierung (QA-007).
///
/// Reihenfolge: harvested → drying → dried → curing → cured
enum HarvestPhase {
  /// Ernte angelegt, Trocknung noch nicht begonnen.
  harvested,

  /// Trocknung läuft (dryingStartDate gesetzt, dryingEndDate null).
  drying,

  /// Trocknung abgeschlossen, Curing noch nicht begonnen.
  dried,

  /// Curing läuft (curingStartDate gesetzt, curingEndDate null).
  curing,

  /// Curing abgeschlossen — End-Zustand.
  cured,
}

/// Wird geworfen, wenn ein illegaler Phasenübergang versucht wird
/// (z.B. von [HarvestPhase.cured] zurück zu [HarvestPhase.drying]).
class HarvestTransitionException implements Exception {
  final HarvestPhase from;
  final HarvestPhase to;
  final String message;

  HarvestTransitionException({
    required this.from,
    required this.to,
    required this.message,
  });

  @override
  String toString() =>
      'HarvestTransitionException: $message (from: ${from.name}, to: ${to.name})';
}

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

  /// Leitet die logische Phase aus den Datumsfeldern eines [Harvest] ab.
  ///
  /// Priorität (von "spätester Phase" zu "frühester"):
  /// 1. curingEndDate gesetzt   → cured
  /// 2. curingStartDate gesetzt → curing
  /// 3. dryingEndDate gesetzt   → dried
  /// 4. dryingStartDate gesetzt → drying
  /// 5. sonst                   → harvested
  static HarvestPhase phaseOf(Harvest harvest) {
    if (harvest.curingEndDate != null) return HarvestPhase.cured;
    if (harvest.curingStartDate != null) return HarvestPhase.curing;
    if (harvest.dryingEndDate != null) return HarvestPhase.dried;
    if (harvest.dryingStartDate != null) return HarvestPhase.drying;
    return HarvestPhase.harvested;
  }

  /// Erlaubte Vorwärts-Übergänge im Erntelebenszyklus.
  /// Same-state (z.B. drying → drying beim Editieren von Gewicht/Notizen) ist
  /// generell erlaubt; nur Rückwärts-Sprünge werden blockiert.
  static const Map<HarvestPhase, Set<HarvestPhase>> _legalForwardTransitions = {
    HarvestPhase.harvested: {HarvestPhase.drying, HarvestPhase.dried},
    HarvestPhase.drying: {HarvestPhase.dried},
    HarvestPhase.dried: {HarvestPhase.curing, HarvestPhase.cured},
    HarvestPhase.curing: {HarvestPhase.cured},
    HarvestPhase.cured: {},
  };

  /// Prüft, ob ein Übergang von [from] nach [to] legal ist.
  ///
  /// Regeln:
  /// - Gleicher Zustand ist immer erlaubt (Edits an Gewicht / Notizen).
  /// - Vorwärts gemäß [_legalForwardTransitions].
  /// - Rückwärts (z.B. cured → drying) ist niemals erlaubt.
  static bool validateTransition(HarvestPhase from, HarvestPhase to) {
    if (from == to) return true;
    final allowed = _legalForwardTransitions[from] ?? const <HarvestPhase>{};
    return allowed.contains(to);
  }

  /// Aktualisiert einen Harvest-Eintrag und prüft dabei die Phasen-
  /// Übergangsregeln. Wirft [HarvestTransitionException] bei illegalem
  /// Übergang. Same-state-Updates (Gewicht/Notizen editieren) sind erlaubt.
  @override
  Future<int> updateHarvestWithValidation(
    Harvest current,
    Harvest next,
  ) async {
    final from = phaseOf(current);
    final to = phaseOf(next);

    if (!validateTransition(from, to)) {
      throw HarvestTransitionException(
        from: from,
        to: to,
        message:
            'Illegaler Phasenübergang: ${from.name} → ${to.name}. '
            'Rückwärts-Übergänge sind nicht erlaubt.',
      );
    }

    return _harvestRepo.updateHarvest(next);
  }
}
