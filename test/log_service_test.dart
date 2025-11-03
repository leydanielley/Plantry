// =============================================
// GROWLOG - Log Service Tests
// =============================================

import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/enums.dart';

void main() {
  group('LogService Validation Tests', () {
    test('PlantLog - Gültige Werte', () {
      final log = PlantLog(
        plantId: 1,
        dayNumber: 15,
        logDate: DateTime.now(),
        actionType: ActionType.feed,
        waterAmount: 2.0,
        phIn: 5.8,
        ecIn: 1.2,
      );

      expect(log.plantId, equals(1));
      expect(log.dayNumber, equals(15));
      expect(log.phIn, equals(5.8));
    });

    test('PlantLog - Serialisierung', () {
      final log = PlantLog(
        plantId: 1,
        dayNumber: 10,
        logDate: DateTime(2025, 10, 21),
        actionType: ActionType.water,
        waterAmount: 1.5,
      );

      final map = log.toMap();
      expect(map['plant_id'], equals(1));
      expect(map['day_number'], equals(10));
      expect(map['action_type'], equals('WATER'));

      final reconstructed = PlantLog.fromMap(map);
      expect(reconstructed.plantId, equals(log.plantId));
      expect(reconstructed.actionType, equals(log.actionType));
    });

    test('Verschiedene ActionTypes', () {
      final actions = [
        ActionType.water,
        ActionType.feed,
        ActionType.transplant,
        ActionType.phaseChange,
        ActionType.harvest,
      ];

      for (final action in actions) {
        final log = PlantLog(
          plantId: 1,
          dayNumber: 1,
          logDate: DateTime.now(),
          actionType: action,
        );

        expect(log.actionType, equals(action));
      }
    });
  });
}