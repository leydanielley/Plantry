// =============================================
// GROWLOG - Test Data Factory
// =============================================
// Erstellt realistische Test-Daten für verschiedene Szenarien

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/enums.dart';

class TestDataFactory {
  // ====================================
  // Realistic Plant Strains
  // ====================================

  static final List<String> popularStrains = [
    'Northern Lights',
    'OG Kush',
    'White Widow',
    'Blue Dream',
    'Girl Scout Cookies',
    'Gorilla Glue',
    'Sour Diesel',
    'Amnesia Haze',
    'Purple Haze',
    'Jack Herer',
  ];

  static final List<String> fertilizerBrands = [
    'BioBizz',
    'Advanced Nutrients',
    'General Hydroponics',
    'Canna',
    'Plagron',
    'House & Garden',
  ];

  // ====================================
  // Create realistic plants
  // ====================================

  static Plant createPlant({
    String? name,
    String? strain,
    SeedType? seedType,
    Medium? medium,
    PlantPhase? phase,
    DateTime? seedDate,
    int? roomId,
    int? growId,
  }) {
    final defaultStrain = strain ?? _randomStrain();
    return Plant(
      name: name ?? '$defaultStrain #1',
      strain: defaultStrain,
      seedType: seedType ?? SeedType.photo,
      medium: medium ?? Medium.erde,
      phase: phase ?? PlantPhase.seedling,
      seedDate: seedDate ?? DateTime.now().subtract(const Duration(days: 7)),
      phaseStartDate: DateTime.now().subtract(const Duration(days: 3)),
      roomId: roomId,
      growId: growId,
    );
  }

  static Plant createVegPlant({int daysSinceSeed = 20}) {
    final seedDate = DateTime.now().subtract(Duration(days: daysSinceSeed));
    return Plant(
      name: '${_randomStrain()} #1',
      strain: _randomStrain(),
      seedType: SeedType.photo,
      medium: Medium.erde,
      phase: PlantPhase.veg,
      seedDate: seedDate,
      phaseStartDate: seedDate.add(const Duration(days: 10)),
      vegDate: seedDate.add(const Duration(days: 10)),
    );
  }

  static Plant createBloomPlant({int daysSinceSeed = 50}) {
    final seedDate = DateTime.now().subtract(Duration(days: daysSinceSeed));
    return Plant(
      name: '${_randomStrain()} #1',
      strain: _randomStrain(),
      seedType: SeedType.photo,
      medium: Medium.coco,
      phase: PlantPhase.bloom,
      seedDate: seedDate,
      phaseStartDate: seedDate.add(const Duration(days: 35)),
      vegDate: seedDate.add(const Duration(days: 15)),
      bloomDate: seedDate.add(const Duration(days: 35)),
    );
  }

  // ====================================
  // Create realistic logs
  // ====================================

  static PlantLog createWateringLog(Plant plant, {DateTime? date}) {
    final logDate = date ?? DateTime.now();
    final dayNumber = logDate.difference(plant.seedDate!).inDays + 1;
    final phaseDayNumber = plant.phaseStartDate != null
        ? logDate.difference(plant.phaseStartDate!).inDays + 1
        : null;

    return PlantLog(
      plantId: plant.id!,
      dayNumber: dayNumber,
      logDate: logDate,
      actionType: ActionType.water,
      phase: plant.phase,
      phaseDayNumber: phaseDayNumber,
      waterAmount: _realisticWaterAmount(plant),
      phIn: _realisticPh(),
      temperature: _realisticTemperature(),
      humidity: _realisticHumidity(plant.phase),
      note: 'Reguläres Gießen',
    );
  }

  static PlantLog createFeedingLog(Plant plant, {DateTime? date}) {
    final logDate = date ?? DateTime.now();
    final dayNumber = logDate.difference(plant.seedDate!).inDays + 1;
    final phaseDayNumber = plant.phaseStartDate != null
        ? logDate.difference(plant.phaseStartDate!).inDays + 1
        : null;

    return PlantLog(
      plantId: plant.id!,
      dayNumber: dayNumber,
      logDate: logDate,
      actionType: ActionType.feed,
      phase: plant.phase,
      phaseDayNumber: phaseDayNumber,
      waterAmount: _realisticWaterAmount(plant),
      ecIn: _realisticEc(plant.phase),
      phIn: _realisticPh(),
      temperature: _realisticTemperature(),
      humidity: _realisticHumidity(plant.phase),
      note: 'Düngen mit ${_realisticFertilizerNote(plant.phase)}',
    );
  }

  // ====================================
  // Create rooms and grows
  // ====================================

  static Room createGrowRoom({String? name}) {
    return Room(
      name: name ?? 'Growzelt 120x120',
      width: 120.0,
      depth: 120.0,
      height: 200.0,
      description: 'Standard Homegrow Setup',
    );
  }

  static Grow createGrow({String? name, DateTime? startDate}) {
    return Grow(
      name: name ?? 'Grow ${DateTime.now().year}',
      startDate: startDate ?? DateTime.now(),
      description: 'Test Grow',
    );
  }

  // ====================================
  // Create fertilizers
  // ====================================

  static Fertilizer createGrowFertilizer() {
    return Fertilizer(
      name: 'Bio Grow',
      brand: fertilizerBrands[0],
      npk: '4-3-6',
      type: 'liquid',
      description: 'Für Wachstumsphase',
    );
  }

  static Fertilizer createBloomFertilizer() {
    return Fertilizer(
      name: 'Bio Bloom',
      brand: fertilizerBrands[0],
      npk: '2-6-6',
      type: 'liquid',
      description: 'Für Blütephase',
    );
  }

  // ====================================
  // Realistic value generators
  // ====================================

  static String _randomStrain() {
    return popularStrains[DateTime.now().millisecond % popularStrains.length];
  }

  static double _realisticWaterAmount(Plant plant) {
    // Größere Pflanzen brauchen mehr Wasser
    switch (plant.phase) {
      case PlantPhase.seedling:
        return 100.0;
      case PlantPhase.veg:
        return 500.0;
      case PlantPhase.bloom:
        return 1000.0;
      case PlantPhase.harvest:
        return 0.0;
      case PlantPhase.archived:
        return 0.0;
    }
  }

  static double _realisticEc(PlantPhase phase) {
    // EC steigt während des Grows
    switch (phase) {
      case PlantPhase.seedling:
        return 0.4 + (DateTime.now().millisecond % 20) / 100; // 0.4-0.6
      case PlantPhase.veg:
        return 1.0 + (DateTime.now().millisecond % 40) / 100; // 1.0-1.4
      case PlantPhase.bloom:
        return 1.6 + (DateTime.now().millisecond % 40) / 100; // 1.6-2.0
      default:
        return 0.8;
    }
  }

  static double _realisticPh() {
    // pH sollte zwischen 5.8 und 6.5 liegen
    return 5.8 + (DateTime.now().millisecond % 70) / 100; // 5.8-6.5
  }

  static double _realisticTemperature() {
    // 22-26°C ist ideal
    return 22.0 + (DateTime.now().millisecond % 40) / 10; // 22-26°C
  }

  static double _realisticHumidity(PlantPhase phase) {
    // Luftfeuchtigkeit sinkt in Blüte
    switch (phase) {
      case PlantPhase.seedling:
        return 65.0 + (DateTime.now().millisecond % 100) / 10; // 65-75%
      case PlantPhase.veg:
        return 55.0 + (DateTime.now().millisecond % 100) / 10; // 55-65%
      case PlantPhase.bloom:
        return 45.0 + (DateTime.now().millisecond % 100) / 10; // 45-55%
      default:
        return 60.0;
    }
  }

  static String _realisticFertilizerNote(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.veg:
        return 'Bio Grow 2ml/L';
      case PlantPhase.bloom:
        return 'Bio Bloom 3ml/L + TopMax 2ml/L';
      default:
        return 'Light Feeding';
    }
  }
}
