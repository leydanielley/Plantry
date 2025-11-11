// =============================================
// GROWLOG - Daily Routine User Journey Test
// =============================================
// Simuliert die tägliche Routine eines Users
// der mehrere Pflanzen gleichzeitig pflegt

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import '../mocks/mock_plant_repository.dart';
import '../mocks/mock_plant_log_repository.dart';

void main() {
  group('User Journey: Daily Plant Care Routine', () {
    late IPlantRepository plantRepo;
    late IPlantLogRepository logRepo;

    setUp(() {
      plantRepo = MockPlantRepository();
      logRepo = MockPlantLogRepository();
    });

    test('Scenario: User checks and waters 4 plants every morning', () async {
      // ====================================
      // SETUP: User hat 4 Pflanzen im Zelt
      // ====================================

      final today = DateTime.now();
      final plants = <Plant>[];

      // Pflanze 1: Veg Phase
      plants.add(
        await plantRepo.save(
          Plant(
            name: 'Purple Haze #1',
            strain: 'Purple Haze',
            seedType: SeedType.photo,
            medium: Medium.erde,
            phase: PlantPhase.veg,
            seedDate: today.subtract(const Duration(days: 20)),
            phaseStartDate: today.subtract(const Duration(days: 10)),
          ),
        ),
      );

      // Pflanze 2: Veg Phase (ältere Pflanze)
      plants.add(
        await plantRepo.save(
          Plant(
            name: 'Purple Haze #2',
            strain: 'Purple Haze',
            seedType: SeedType.photo,
            medium: Medium.erde,
            phase: PlantPhase.veg,
            seedDate: today.subtract(const Duration(days: 25)),
            phaseStartDate: today.subtract(const Duration(days: 15)),
          ),
        ),
      );

      // Pflanze 3: Bloom Phase
      plants.add(
        await plantRepo.save(
          Plant(
            name: 'OG Kush #1',
            strain: 'OG Kush',
            seedType: SeedType.photo,
            medium: Medium.coco,
            phase: PlantPhase.bloom,
            seedDate: today.subtract(const Duration(days: 60)),
            phaseStartDate: today.subtract(const Duration(days: 20)),
            bloomDate: today.subtract(const Duration(days: 20)),
          ),
        ),
      );

      // Pflanze 4: Bloom Phase (kurz vor Ernte)
      plants.add(
        await plantRepo.save(
          Plant(
            name: 'OG Kush #2',
            strain: 'OG Kush',
            seedType: SeedType.photo,
            medium: Medium.coco,
            phase: PlantPhase.bloom,
            seedDate: today.subtract(const Duration(days: 85)),
            phaseStartDate: today.subtract(const Duration(days: 45)),
            bloomDate: today.subtract(const Duration(days: 45)),
          ),
        ),
      );

      expect(plants.length, 4);

      // ====================================
      // MORNING ROUTINE: 9:00 Uhr
      // User öffnet App und checkt Pflanzen
      // ====================================

      // User öffnet Dashboard und sieht alle Pflanzen
      final allPlants = await plantRepo.findAll();
      expect(allPlants.length, 4);

      // ====================================
      // ACTION 1: Bulk-Watering für Veg-Pflanzen
      // User wässert beide Veg-Pflanzen gleichzeitig
      // ====================================

      final vegPlants = allPlants
          .where((p) => p.phase == PlantPhase.veg)
          .toList();
      expect(vegPlants.length, 2);

      // User nutzt "Mehrere Pflanzen gießen" Feature
      for (final plant in vegPlants) {
        final waterLog = PlantLog(
          plantId: plant.id!,
          dayNumber: today.difference(plant.seedDate!).inDays + 1,
          logDate: today,
          actionType: ActionType.water,
          phase: plant.phase,
          phaseDayNumber: today.difference(plant.phaseStartDate!).inDays + 1,
          waterAmount: 500.0,
          phIn: 6.3,
          temperature: 24.0,
          humidity: 60.0,
          note: 'Morgendliches Gießen',
        );
        await logRepo.save(waterLog);
      }

      // ====================================
      // ACTION 2: Individual Bloom Plant Care
      // Bloom-Pflanzen brauchen unterschiedliche Pflege
      // ====================================

      final bloomPlant1 = plants[2]; // OG Kush #1
      final bloomPlant2 = plants[3]; // OG Kush #2

      // OG Kush #1: Normales Feeding
      final feedLog1 = PlantLog(
        plantId: bloomPlant1.id!,
        dayNumber: today.difference(bloomPlant1.seedDate!).inDays + 1,
        logDate: today,
        actionType: ActionType.feed,
        phase: PlantPhase.bloom,
        phaseDayNumber:
            today.difference(bloomPlant1.phaseStartDate!).inDays + 1,
        waterAmount: 1000.0,
        ecIn: 1.8,
        phIn: 6.0,
        temperature: 23.5,
        humidity: 50.0,
        note: 'Bloom Dünger, Buds werden dicker',
      );
      await logRepo.save(feedLog1);

      // OG Kush #2: Nur Wasser (Flushing für Ernte)
      final flushLog = PlantLog(
        plantId: bloomPlant2.id!,
        dayNumber: today.difference(bloomPlant2.seedDate!).inDays + 1,
        logDate: today,
        actionType: ActionType.water,
        phase: PlantPhase.bloom,
        phaseDayNumber:
            today.difference(bloomPlant2.phaseStartDate!).inDays + 1,
        waterAmount: 2000.0,
        cleanse: true,
        note: 'Tag 7 vom Spülen, Trichome werden bernsteinfarben',
      );
      await logRepo.save(flushLog);

      // ====================================
      // ACTION 3: User macht Fotos
      // Wöchentliches Foto-Update
      // ====================================

      // User macht Notiz über Purple Haze #1 (beste Entwicklung)
      final observationLog1 = PlantLog(
        plantId: plants[0].id!,
        dayNumber: today.difference(plants[0].seedDate!).inDays + 1,
        logDate: today,
        actionType: ActionType.note,
        phase: PlantPhase.veg,
        phaseDayNumber: today.difference(plants[0].phaseStartDate!).inDays + 1,
        note: 'Wöchentliches Update - Wachstum ist super!',
      );
      await logRepo.save(observationLog1);

      // ====================================
      // ACTION 4: User notiert Beobachtungen
      // Probleme oder besondere Ereignisse
      // ====================================

      // User bemerkt leichte gelbe Blätter bei Purple Haze #2
      final observationLog2 = PlantLog(
        plantId: plants[1].id!,
        dayNumber: today.difference(plants[1].seedDate!).inDays + 1,
        logDate: today,
        actionType: ActionType.note,
        phase: PlantPhase.veg,
        phaseDayNumber: today.difference(plants[1].phaseStartDate!).inDays + 1,
        note:
            'Leichte Gelbfärbung untere Blätter - evtl. Stickstoffmangel? Nächstes Mal mehr Dünger.',
      );
      await logRepo.save(observationLog2);

      // ====================================
      // VERIFICATION: Tägliche Routine komplett
      // ====================================

      // User hat für alle 4 Pflanzen Logs erstellt
      final todaysLogs = <PlantLog>[];
      for (final plant in plants) {
        final plantLogs = await logRepo.findByPlant(plant.id!);
        final todayLogs = plantLogs.where((log) {
          return log.logDate.year == today.year &&
              log.logDate.month == today.month &&
              log.logDate.day == today.day;
        }).toList();
        todaysLogs.addAll(todayLogs);
      }

      expect(
        todaysLogs.length,
        6,
      ); // 2 Veg Water + 1 Bloom Feed + 1 Bloom Flush + 2 Notes

      // Statistiken für User-Dashboard
      final wateringCount = todaysLogs
          .where((l) => l.actionType == ActionType.water)
          .length;
      final feedingCount = todaysLogs
          .where((l) => l.actionType == ActionType.feed)
          .length;
      final noteCount = todaysLogs
          .where((l) => l.actionType == ActionType.note)
          .length;

      expect(wateringCount, 3); // 2 Veg + 1 Flush
      expect(feedingCount, 1);
      expect(noteCount, 2);

      debugPrint('✅ Daily Routine Complete!');
      debugPrint('🌿 4 Pflanzen gepflegt');
      debugPrint('💧 $wateringCount x gegossen');
      debugPrint('🥗 $feedingCount x gedüngt');
      debugPrint('📝 $noteCount x notiert');
      debugPrint('⏱️ Zeit: ~15 Minuten (realistic)');
    });

    test('Scenario: User copies last log for quick entry', () async {
      // Häufiger Use Case: User wiederholt gleiche Aktion wie gestern

      final plant = await plantRepo.save(
        Plant(
          name: 'Auto CBD #1',
          strain: 'CBD Auto',
          seedType: SeedType.auto,
          medium: Medium.hydro,
          phase: PlantPhase.veg,
          seedDate: DateTime.now().subtract(const Duration(days: 15)),
          phaseStartDate: DateTime.now().subtract(const Duration(days: 5)),
        ),
      );

      // Gestern: User hat gedüngt
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayLog = PlantLog(
        plantId: plant.id!,
        dayNumber: 15,
        logDate: yesterday,
        actionType: ActionType.feed,
        phase: PlantPhase.veg,
        phaseDayNumber: 5,
        waterAmount: 500.0,
        ecIn: 1.2,
        phIn: 6.2,
        temperature: 24.5,
        humidity: 58.0,
        note: 'Standard Feeding',
      );
      await logRepo.save(yesterdayLog);

      // Heute: User öffnet App, klickt "Letzten Log kopieren"
      final lastLog = await logRepo.getLastLogForPlant(plant.id!);
      expect(lastLog, isNotNull);

      // User passt nur Datum und Notiz an
      final todayLog = PlantLog(
        plantId: lastLog!.plantId,
        dayNumber: lastLog.dayNumber + 1,
        logDate: DateTime.now(),
        actionType: lastLog.actionType,
        phase: lastLog.phase,
        phaseDayNumber: lastLog.phaseDayNumber! + 1,
        waterAmount: lastLog.waterAmount,
        ecIn: lastLog.ecIn,
        phIn: lastLog.phIn,
        temperature: 24.0, // Leicht angepasst
        humidity: 60.0, // Leicht angepasst
        note: 'Standard Feeding (kopiert von gestern)',
      );
      await logRepo.save(todayLog);

      final allLogs = await logRepo.findByPlant(plant.id!);
      expect(allLogs.length, 2);
      expect(allLogs.last.waterAmount, 500.0); // Gleiche Menge
      expect(allLogs.last.ecIn, 1.2); // Gleicher EC

      debugPrint('✅ Quick Log Entry: User spart Zeit durch Kopieren!');
    });
  });
}
