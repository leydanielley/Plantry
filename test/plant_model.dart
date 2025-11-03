// =============================================
// GROWLOG - Plant Model Tests
// Unit Tests für Business Logic
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/enums.dart';

void main() {
  group('Plant Model Unit Tests', () {

    test('Plant Creation - Minimale Parameter', () {
      // ARRANGE & ACT
      final plant = Plant(
        name: 'Test Plant',
        seedType: SeedType.photo,
        medium: Medium.coco,
      );

      // ASSERT
      expect(plant.name, equals('Test Plant'));
      expect(plant.seedType, equals(SeedType.photo));
      expect(plant.medium, equals(Medium.coco));
      expect(plant.phase, equals(PlantPhase.seedling));
      expect(plant.feminized, isTrue);
      expect(plant.archived, isFalse);
    });

    test('Plant Creation - Alle Parameter', () {
      final plant = Plant(
        name: 'Gorilla Glue #4',
        breeder: 'Original Sensible',
        strain: 'GG4',
        feminized: true,
        seedType: SeedType.photo,
        medium: Medium.coco,
        phase: PlantPhase.bloom,
        roomId: 1,
        growId: 5,
        seedDate: DateTime(2025, 1, 1),
        phaseStartDate: DateTime(2025, 2, 15),
        currentContainerSize: 11.0,
      );

      expect(plant.name, equals('Gorilla Glue #4'));
      expect(plant.breeder, equals('Original Sensible'));
      expect(plant.strain, equals('GG4'));
      expect(plant.phase, equals(PlantPhase.bloom));
    });

    test('copyWith - Einzelne Werte ändern', () {
      final original = Plant(
        name: 'Original',
        seedType: SeedType.photo,
        medium: Medium.coco,
        phase: PlantPhase.seedling,
      );

      final updated = original.copyWith(
        phase: PlantPhase.veg,
        phaseStartDate: DateTime.now(),
      );

      expect(updated.phase, equals(PlantPhase.veg));
      expect(updated.phaseStartDate, isNotNull);
      expect(updated.name, equals('Original'));
    });

    test('totalDays - Berechnung seit Seed-Datum', () {
      final seedDate = DateTime.now().subtract(const Duration(days: 45));
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.coco,
        seedDate: seedDate,
      );

      expect(plant.totalDays, equals(45));
    });

    test('containerInfo - Topf für Coco', () {
      final plant = Plant(
        name: 'Test',
        seedType: SeedType.photo,
        medium: Medium.coco,
        currentContainerSize: 11.0,
      );

      expect(plant.containerInfo, equals('11L Topf'));
    });
  });
}