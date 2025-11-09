// =============================================
// GROWLOG - RDWC Fix Verification Test
// Vereinfachter Test für die behobenen Bugs
// =============================================

import 'package:flutter_test/flutter_test.dart';
import '../lib/models/rdwc_log.dart';
import '../lib/models/rdwc_log_fertilizer.dart';
import '../lib/models/plant_log.dart';
import '../lib/models/enums.dart';

void main() {
  group('RDWC Log Bug Fixes Verification', () {
    test('1. RdwcLogType.fullChange konvertiert korrekt zu FULLCHANGE', () {
      final log = RdwcLog(
        systemId: 1,
        logType: RdwcLogType.fullChange,
        levelAfter: 100.0,
      );

      final map = log.toMap();

      // Der Bug war: logType.name.toUpperCase() => "FULLCHANGE" (falsch)
      // Korrekt: "FULLCHANGE" (mit switch-case)
      expect(map['log_type'], 'FULLCHANGE');
    });

    test('2. RdwcLogType.addback konvertiert korrekt zu ADDBACK', () {
      final log = RdwcLog(
        systemId: 1,
        logType: RdwcLogType.addback,
        levelAfter: 90.0,
      );

      final map = log.toMap();
      expect(map['log_type'], 'ADDBACK');
    });

    test('3. RdwcLogType.measurement konvertiert korrekt zu MEASUREMENT', () {
      final log = RdwcLog(
        systemId: 1,
        logType: RdwcLogType.measurement,
        levelAfter: 85.0,
      );

      final map = log.toMap();
      expect(map['log_type'], 'MEASUREMENT');
    });

    test('4. RdwcLogType.maintenance konvertiert korrekt zu MAINTENANCE', () {
      final log = RdwcLog(
        systemId: 1,
        logType: RdwcLogType.maintenance,
        note: 'Cleaned pumps',
      );

      final map = log.toMap();
      expect(map['log_type'], 'MAINTENANCE');
    });

    test('5. FertilizerAmountType.perLiter konvertiert korrekt zu PER_LITER', () {
      final fertLog = RdwcLogFertilizer(
        rdwcLogId: 1,
        fertilizerId: 1,
        amount: 5.0,
        amountType: FertilizerAmountType.perLiter,
      );

      final map = fertLog.toMap();

      // Der Bug war: .replaceAll('PERLITER', 'PER_LITER') funktionierte nicht für total
      // Korrekt: switch-case für beide Werte
      expect(map['amount_type'], 'PER_LITER');
    });

    test('6. FertilizerAmountType.total konvertiert korrekt zu TOTAL', () {
      final fertLog = RdwcLogFertilizer(
        rdwcLogId: 1,
        fertilizerId: 1,
        amount: 100.0,
        amountType: FertilizerAmountType.total,
      );

      final map = fertLog.toMap();
      expect(map['amount_type'], 'TOTAL');
    });

    test('7. ActionType.phaseChange konvertiert korrekt zu PHASE_CHANGE', () {
      final plantLog = PlantLog(
        plantId: 1,
        dayNumber: 30,
        logDate: DateTime.now(),
        actionType: ActionType.phaseChange,
      );

      final map = plantLog.toMap();

      // Der Bug war: .replaceAll('CHANGE', '_CHANGE') war fehleranfällig
      // Korrekt: explizite switch-case
      expect(map['action_type'], 'PHASE_CHANGE');
    });

    test('8. ActionType.water konvertiert korrekt zu WATER', () {
      final plantLog = PlantLog(
        plantId: 1,
        dayNumber: 1,
        logDate: DateTime.now(),
        actionType: ActionType.water,
      );

      final map = plantLog.toMap();
      expect(map['action_type'], 'WATER');
    });

    test('9. ActionType.feed konvertiert korrekt zu FEED', () {
      final plantLog = PlantLog(
        plantId: 1,
        dayNumber: 1,
        logDate: DateTime.now(),
        actionType: ActionType.feed,
      );

      final map = plantLog.toMap();
      expect(map['action_type'], 'FEED');
    });

    test('10. Alle RdwcLogType Werte sind abgedeckt', () {
      // Teste alle Enum-Werte
      final testCases = {
        RdwcLogType.addback: 'ADDBACK',
        RdwcLogType.fullChange: 'FULLCHANGE',
        RdwcLogType.maintenance: 'MAINTENANCE',
        RdwcLogType.measurement: 'MEASUREMENT',
      };

      for (final entry in testCases.entries) {
        final log = RdwcLog(
          systemId: 1,
          logType: entry.key,
          levelAfter: 100.0,
        );
        expect(log.toMap()['log_type'], entry.value,
            reason: 'Failed for ${entry.key}');
      }
    });

    test('11. Alle ActionType Werte sind abgedeckt', () {
      // Teste alle Enum-Werte
      final testCases = {
        ActionType.water: 'WATER',
        ActionType.feed: 'FEED',
        ActionType.trim: 'TRIM',
        ActionType.transplant: 'TRANSPLANT',
        ActionType.training: 'TRAINING',
        ActionType.note: 'NOTE',
        ActionType.phaseChange: 'PHASE_CHANGE',
        ActionType.harvest: 'HARVEST',
        ActionType.other: 'OTHER',
      };

      for (final entry in testCases.entries) {
        final log = PlantLog(
          plantId: 1,
          dayNumber: 1,
          logDate: DateTime.now(),
          actionType: entry.key,
        );
        expect(log.toMap()['action_type'], entry.value,
            reason: 'Failed for ${entry.key}');
      }
    });
  });

  group('Model Serialization Roundtrip Tests', () {
    test('12. RdwcLog roundtrip (toMap -> fromMap)', () {
      final original = RdwcLog(
        id: 1,
        systemId: 10,
        logType: RdwcLogType.fullChange,
        levelBefore: 80.0,
        waterAdded: 20.0,
        levelAfter: 100.0,
        waterConsumed: 10.0,
        phBefore: 6.0,
        phAfter: 6.2,
        ecBefore: 1.5,
        ecAfter: 1.8,
        note: 'Test note',
        loggedBy: 'Claude',
        logDate: DateTime(2025, 1, 1, 12, 0),
        createdAt: DateTime(2025, 1, 1, 12, 0),
      );

      final map = original.toMap();
      final reconstructed = RdwcLog.fromMap(map);

      expect(reconstructed.id, original.id);
      expect(reconstructed.systemId, original.systemId);
      expect(reconstructed.logType, original.logType);
      expect(reconstructed.levelBefore, original.levelBefore);
      expect(reconstructed.waterAdded, original.waterAdded);
      expect(reconstructed.levelAfter, original.levelAfter);
      expect(reconstructed.note, original.note);
    });

    test('13. RdwcLogFertilizer roundtrip (toMap -> fromMap)', () {
      final original = RdwcLogFertilizer(
        id: 1,
        rdwcLogId: 10,
        fertilizerId: 5,
        amount: 7.5,
        amountType: FertilizerAmountType.perLiter,
        createdAt: DateTime(2025, 1, 1, 12, 0),
      );

      final map = original.toMap();
      final reconstructed = RdwcLogFertilizer.fromMap(map);

      expect(reconstructed.id, original.id);
      expect(reconstructed.rdwcLogId, original.rdwcLogId);
      expect(reconstructed.fertilizerId, original.fertilizerId);
      expect(reconstructed.amount, original.amount);
      expect(reconstructed.amountType, original.amountType);
    });
  });
}
