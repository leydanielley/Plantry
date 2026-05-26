// =============================================
// GROWLOG - HarvestService Phase-Transition Tests (QA-007)
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/services/harvest_service.dart';

/// Minimaler In-Memory-Mock für `IHarvestRepository`. Nur die für die
/// Phase-Transition-Tests benötigten Methoden sind implementiert; alle
/// anderen werfen `UnimplementedError`.
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

/// Helfer: baut einen Harvest in einer bestimmten logischen Phase.
Harvest _harvestInPhase(HarvestPhase phase) {
  final base = DateTime(2026, 1, 1);
  switch (phase) {
    case HarvestPhase.harvested:
      return Harvest(plantId: 1, harvestDate: base);
    case HarvestPhase.drying:
      return Harvest(
        plantId: 1,
        harvestDate: base,
        dryingStartDate: base.add(const Duration(days: 1)),
      );
    case HarvestPhase.dried:
      return Harvest(
        plantId: 1,
        harvestDate: base,
        dryingStartDate: base.add(const Duration(days: 1)),
        dryingEndDate: base.add(const Duration(days: 10)),
        dryWeight: 100.0,
      );
    case HarvestPhase.curing:
      return Harvest(
        plantId: 1,
        harvestDate: base,
        dryingStartDate: base.add(const Duration(days: 1)),
        dryingEndDate: base.add(const Duration(days: 10)),
        curingStartDate: base.add(const Duration(days: 11)),
        dryWeight: 100.0,
      );
    case HarvestPhase.cured:
      return Harvest(
        plantId: 1,
        harvestDate: base,
        dryingStartDate: base.add(const Duration(days: 1)),
        dryingEndDate: base.add(const Duration(days: 10)),
        curingStartDate: base.add(const Duration(days: 11)),
        curingEndDate: base.add(const Duration(days: 30)),
        dryWeight: 100.0,
      );
  }
}

void main() {
  group('HarvestService.phaseOf', () {
    test('returns harvested when only harvestDate is set', () {
      final h = _harvestInPhase(HarvestPhase.harvested);
      expect(HarvestService.phaseOf(h), HarvestPhase.harvested);
    });

    test('returns drying when dryingStartDate is set without end', () {
      final h = _harvestInPhase(HarvestPhase.drying);
      expect(HarvestService.phaseOf(h), HarvestPhase.drying);
    });

    test('returns dried when dryingEndDate is set without curing', () {
      final h = _harvestInPhase(HarvestPhase.dried);
      expect(HarvestService.phaseOf(h), HarvestPhase.dried);
    });

    test('returns curing when curingStartDate is set without end', () {
      final h = _harvestInPhase(HarvestPhase.curing);
      expect(HarvestService.phaseOf(h), HarvestPhase.curing);
    });

    test('returns cured when curingEndDate is set', () {
      final h = _harvestInPhase(HarvestPhase.cured);
      expect(HarvestService.phaseOf(h), HarvestPhase.cured);
    });
  });

  group('HarvestService.validateTransition - legal forward', () {
    test('harvested → drying is legal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.harvested,
          HarvestPhase.drying,
        ),
        isTrue,
      );
    });

    test('drying → dried is legal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.drying,
          HarvestPhase.dried,
        ),
        isTrue,
      );
    });

    test('dried → curing is legal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.dried,
          HarvestPhase.curing,
        ),
        isTrue,
      );
    });

    test('curing → cured is legal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.curing,
          HarvestPhase.cured,
        ),
        isTrue,
      );
    });

    test('harvested → dried is legal (skip drying — start+end same edit)', () {
      // Some screens record start+end in one step.
      expect(
        HarvestService.validateTransition(
          HarvestPhase.harvested,
          HarvestPhase.dried,
        ),
        isTrue,
      );
    });

    test('dried → cured is legal (skip curing — start+end same edit)', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.dried,
          HarvestPhase.cured,
        ),
        isTrue,
      );
    });
  });

  group('HarvestService.validateTransition - same-state', () {
    test('same-state harvested → harvested is allowed (notes edits)', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.harvested,
          HarvestPhase.harvested,
        ),
        isTrue,
      );
    });

    test('same-state cured → cured is allowed (rating/notes edits)', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.cured,
          HarvestPhase.cured,
        ),
        isTrue,
      );
    });
  });

  group('HarvestService.validateTransition - illegal backward', () {
    test('cured → curing is illegal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.cured,
          HarvestPhase.curing,
        ),
        isFalse,
      );
    });

    test('cured → drying is illegal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.cured,
          HarvestPhase.drying,
        ),
        isFalse,
      );
    });

    test('cured → harvested is illegal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.cured,
          HarvestPhase.harvested,
        ),
        isFalse,
      );
    });

    test('curing → drying is illegal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.curing,
          HarvestPhase.drying,
        ),
        isFalse,
      );
    });

    test('dried → drying is illegal (un-finishing drying)', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.dried,
          HarvestPhase.drying,
        ),
        isFalse,
      );
    });

    test('drying → harvested is illegal', () {
      expect(
        HarvestService.validateTransition(
          HarvestPhase.drying,
          HarvestPhase.harvested,
        ),
        isFalse,
      );
    });

    test('harvested → curing is illegal (drying skipped entirely)', () {
      // Cannot start curing without any drying record.
      expect(
        HarvestService.validateTransition(
          HarvestPhase.harvested,
          HarvestPhase.curing,
        ),
        isFalse,
      );
    });
  });

  group('HarvestService.updateHarvestWithValidation', () {
    late _MockHarvestRepository repo;
    late HarvestService service;

    setUp(() {
      repo = _MockHarvestRepository();
      service = HarvestService(repo);
    });

    test('forwards legal transition to repository', () async {
      final current = _harvestInPhase(HarvestPhase.drying);
      final next = _harvestInPhase(HarvestPhase.dried);

      final result = await service.updateHarvestWithValidation(current, next);

      expect(result, 1);
      expect(repo.updateCount, 1);
      expect(repo.lastUpdated, isNotNull);
      expect(HarvestService.phaseOf(repo.lastUpdated!), HarvestPhase.dried);
    });

    test('forwards same-state edit (weight/notes) to repository', () async {
      final current = _harvestInPhase(HarvestPhase.cured);
      final next = current.copyWith(rating: 5, overallNotes: 'great');

      final result = await service.updateHarvestWithValidation(current, next);

      expect(result, 1);
      expect(repo.updateCount, 1);
    });

    test('throws HarvestTransitionException on backward transition', () async {
      final current = _harvestInPhase(HarvestPhase.cured);
      final next = _harvestInPhase(HarvestPhase.drying);

      expect(
        () => service.updateHarvestWithValidation(current, next),
        throwsA(
          isA<HarvestTransitionException>()
              .having((e) => e.from, 'from', HarvestPhase.cured)
              .having((e) => e.to, 'to', HarvestPhase.drying),
        ),
      );
      expect(repo.updateCount, 0, reason: 'repository must not be hit');
    });

    test('throws on harvested → curing (drying skipped)', () async {
      final current = _harvestInPhase(HarvestPhase.harvested);
      final next = _harvestInPhase(HarvestPhase.curing);

      expect(
        () => service.updateHarvestWithValidation(current, next),
        throwsA(isA<HarvestTransitionException>()),
      );
      expect(repo.updateCount, 0);
    });

    test(
      'throws HarvestOrderException when dryingEndDate is before '
      'dryingStartDate (chronological order violated)',
      () async {
        final base = DateTime(2026, 1, 1);
        final current = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 5)),
        );
        // dryingEndDate VOR dryingStartDate — Reihenfolge verletzt.
        final next = current.copyWith(
          dryingEndDate: base.add(const Duration(days: 2)),
          dryWeight: 100.0,
        );

        expect(
          () => service.updateHarvestWithValidation(current, next),
          throwsA(isA<HarvestOrderException>()),
        );
        expect(repo.updateCount, 0, reason: 'repository must not be hit');
      },
    );

    test(
      'order check runs before transition check: chronologically broken '
      'curing dates throw HarvestOrderException (not transition)',
      () async {
        final base = DateTime(2026, 1, 1);
        final current = Harvest(
          plantId: 1,
          harvestDate: base,
          dryingStartDate: base.add(const Duration(days: 1)),
          dryingEndDate: base.add(const Duration(days: 10)),
          dryWeight: 100.0,
        );
        // curingEndDate VOR curingStartDate.
        final next = current.copyWith(
          curingStartDate: base.add(const Duration(days: 20)),
          curingEndDate: base.add(const Duration(days: 15)),
        );

        expect(
          () => service.updateHarvestWithValidation(current, next),
          throwsA(isA<HarvestOrderException>()),
        );
        expect(repo.updateCount, 0);
      },
    );
  });
}
