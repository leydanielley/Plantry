// =============================================
// GROWLOG - HarvestService Screen-Wiring Tests (QA-007 follow-up)
// =============================================
// Bestätigt, dass die typische Aufrufsequenz der Harvest-Screens
// (lade aktuellen Harvest → konstruiere `updated` via copyWith → rufe
// `updateHarvestWithValidation(current, updated)`) genau das Verhalten
// liefert, das die Screens erwarten:
//   - legale Vorwärts-Transitions schreiben in das Repository
//   - Same-State-Edits (Gewicht/Notizen) schreiben
//   - illegale Rückwärts-Transitions werfen HarvestTransitionException
//     und das Repository wird NICHT aufgerufen
//
// Echte Widget-Tests der Screens würden vollen GetIt-Setup + Mock-DB
// erfordern (siehe test/widget/add_plant_screen_test.dart: bewusst
// vereinfacht). Diese Service-Level-Tests decken die Wiring-Garantie
// (Service statt Repo direkt) ab.

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/services/harvest_service.dart';

class _MockHarvestRepository implements IHarvestRepository {
  Harvest? lastUpdated;
  int updateCount = 0;

  @override
  Future<int> updateHarvest(Harvest harvest) async {
    lastUpdated = harvest;
    updateCount++;
    return 1;
  }

  @override
  Future<int> createHarvest(Harvest harvest) async =>
      throw UnimplementedError();

  @override
  Future<int> deleteHarvest(int id) async => throw UnimplementedError();

  @override
  Future<Harvest?> getHarvestById(int id) async => throw UnimplementedError();

  @override
  Future<Harvest?> getHarvestByPlantId(int plantId) async =>
      throw UnimplementedError();

  @override
  Future<List<Harvest>> getAllHarvests() async => throw UnimplementedError();

  @override
  Future<List<Harvest>> getHarvestsByGrowId(int growId) async =>
      throw UnimplementedError();

  @override
  Future<List<Harvest>> getDryingHarvests() async =>
      throw UnimplementedError();

  @override
  Future<List<Harvest>> getCuringHarvests() async =>
      throw UnimplementedError();

  @override
  Future<List<Harvest>> getCompletedHarvests() async =>
      throw UnimplementedError();

  @override
  Future<double> getTotalYield() async => throw UnimplementedError();

  @override
  Future<double> getAverageYield() async => throw UnimplementedError();

  @override
  Future<int> getHarvestCount() async => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getHarvestWithPlant(int harvestId) async =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllHarvestsWithPlants() async =>
      throw UnimplementedError();
}

void main() {
  group('Screen wiring → HarvestService', () {
    late _MockHarvestRepository repo;
    late HarvestService service;
    final base = DateTime(2026, 1, 1);

    setUp(() {
      repo = _MockHarvestRepository();
      service = HarvestService(repo);
    });

    test(
      'HarvestDryingScreen._startDrying flow: harvested → drying writes',
      () async {
        // Screen-Aufrufpattern: _harvest!.copyWith(dryingStartDate: ...)
        final current = Harvest(plantId: 1, harvestDate: base);
        final updated = current.copyWith(
          dryingStartDate: base.add(const Duration(days: 1)),
          updatedAt: DateTime.now(),
        );

        await service.updateHarvestWithValidation(current, updated);

        expect(repo.updateCount, 1);
        expect(repo.lastUpdated?.dryingStartDate, isNotNull);
      },
    );

    test(
      'HarvestDryingScreen._endDrying flow: drying → dried writes',
      () async {
        final current = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 1)),
        );
        final updated = current.copyWith(
          dryingEndDate: base.add(const Duration(days: 10)),
          dryWeight: 95.5,
          updatedAt: DateTime.now(),
        );

        await service.updateHarvestWithValidation(current, updated);

        expect(repo.updateCount, 1);
        expect(repo.lastUpdated?.dryingEndDate, isNotNull);
        expect(repo.lastUpdated?.dryWeight, 95.5);
      },
    );

    test(
      'HarvestCuringScreen._startCuring flow: dried → curing writes',
      () async {
        final current = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 1)),
          dryingEndDate: base.add(const Duration(days: 10)),
          dryWeight: 100.0,
        );
        final updated = current.copyWith(
          curingStartDate: base.add(const Duration(days: 11)),
          curingMethod: 'Glass Jars',
          updatedAt: DateTime.now(),
        );

        await service.updateHarvestWithValidation(current, updated);

        expect(repo.updateCount, 1);
        expect(repo.lastUpdated?.curingMethod, 'Glass Jars');
      },
    );

    test(
      'EditHarvestQualityScreen flow: same-state cured → cured writes '
      '(rating/notes edits)',
      () async {
        final current = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 1)),
          dryingEndDate: base.add(const Duration(days: 10)),
          curingStartDate: base.add(const Duration(days: 11)),
          curingEndDate: base.add(const Duration(days: 30)),
          dryWeight: 100.0,
        );
        final updated = current.copyWith(
          rating: 5,
          overallNotes: 'Top harvest',
          updatedAt: DateTime.now(),
        );

        await service.updateHarvestWithValidation(current, updated);

        expect(repo.updateCount, 1);
        expect(repo.lastUpdated?.rating, 5);
        expect(repo.lastUpdated?.overallNotes, 'Top harvest');
      },
    );

    test(
      'EditHarvestDryingScreen flow: illegal backward edit (clear endDate '
      'on cured harvest) throws and does NOT write',
      () async {
        // Simuliert: User editiert eine Drying-Phase auf einer Ernte,
        // die bereits cured ist, und versucht dryingEndDate auf null
        // zu setzen → würde Phase auf "drying" zurückwerfen.
        final current = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 1)),
          dryingEndDate: base.add(const Duration(days: 10)),
          curingStartDate: base.add(const Duration(days: 11)),
          curingEndDate: base.add(const Duration(days: 30)),
          dryWeight: 100.0,
        );
        // copyWith mit null-Reset wäre nötig — hier simulieren wir mit
        // einem neuen Harvest-Objekt, das die alten End-Daten verliert.
        final updated = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 1)),
          dryWeight: 100.0,
        );

        expect(
          () => service.updateHarvestWithValidation(current, updated),
          throwsA(isA<HarvestTransitionException>()),
        );
        expect(repo.updateCount, 0, reason: 'illegal transition must not hit DB');
      },
    );
  });
}
