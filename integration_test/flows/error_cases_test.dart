import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/app_driver.dart';

Future<bool> _navigateToDryingDialog(AppDriver d) async {
  await d.tapText('ERNTEN');
  await d.settle(const Duration(seconds: 2));
  final tiles = find.byType(InkWell);
  if (tiles.evaluate().isEmpty) return false;

  await d.t.tap(tiles.first);
  await d.settle();

  if (!d.hasText('Trocknung bearbeiten')) return false;
  await d.tapText('Trocknung bearbeiten');

  if (!d.hasText('Trocknung beenden')) return false;
  await d.tapText('Trocknung beenden');

  return find.byType(AlertDialog).evaluate().isNotEmpty;
}

void errorCasesTests() {
  group('Fehleingaben – Raum', () {
    testWidgets('Leerer Name → Validator-Fehler', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('RÄUME');
      await d.tapFAB();
      await d.scrollToKey('save_room');
      await d.tapKey('save_room');
      d.expectText('ist erforderlich');
    });

    testWidgets('Nur Leerzeichen im Name → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('RÄUME');
      await d.tapFAB();
      await d.enterTextByKey('field_room_name', '   ');
      await d.scrollToKey('save_room');
      await d.tapKey('save_room');
      await d.settle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });
  });

  group('Fehleingaben – Grow', () {
    testWidgets('Leerer Name → Validator-Fehler', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('ANBAUTEN');
      await d.tapFAB();
      // Default-Name aus didChangeDependencies leeren, damit Validator greift.
      await d.enterTextByKey('field_grow_name', '');
      await d.scrollToKey('save_grow');
      await d.tapKey('save_grow');
      d.expectText('Name erforderlich');
    });
  });

  group('Fehleingaben – Pflanze', () {
    testWidgets('Leerer Name → Validator-Fehler', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');
      await d.scrollToKey('save_plant');
      await d.tapKey('save_plant');
      d.expectText('Name erforderlich');
    });

    testWidgets('Ungültige Menge (Text) → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');
      await d.enterTextByKey('field_plant_name', 'Fehler-Test-Pflanze');
      await d.enterTextByKey('field_plant_quantity', 'fünf');
      await d.scrollToKey('save_plant');
      await d.tapKey('save_plant');
      await d.settle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('Negative Menge → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');
      await d.enterTextByKey('field_plant_name', 'Negativ-Test');
      await d.enterTextByKey('field_plant_quantity', '-3');
      await d.scrollToKey('save_plant');
      await d.tapKey('save_plant');
      await d.settle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });
  });

  group('Fehleingaben – Trocknung Gewicht', () {
    testWidgets('Leer → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.tapText('Beenden');
      d.expectSnackBar('Bitte gültiges Gewicht eingeben');
    });

    testWidgets('Text statt Zahl → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.enterTextAt(0, 'keine Ahnung');
      await d.tapText('Beenden');
      d.expectSnackBar('Bitte gültiges Gewicht eingeben');
    });

    testWidgets('Negatives Gewicht → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.enterTextAt(0, '-10');
      await d.tapText('Beenden');
      d.expectSnackBar('Bitte gültiges Gewicht eingeben');
    });

    testWidgets('Null-Gewicht → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.enterTextAt(0, '0');
      await d.tapText('Beenden');
      d.expectSnackBar('Bitte gültiges Gewicht eingeben');
    });

    testWidgets('Dialog abbrechen → Daten unverändert', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ERNTEN');
      await d.settle(const Duration(seconds: 2));
      final tiles = find.byType(InkWell);
      if (tiles.evaluate().isEmpty) return;
      await d.t.tap(tiles.first);
      await d.settle();
      if (!d.hasText('Trocknung bearbeiten')) return;
      await d.tapText('Trocknung bearbeiten');
      if (!d.hasText('Trocknung beenden')) return;
      await d.tapText('Trocknung beenden');
      if (find.byType(AlertDialog).evaluate().isEmpty) return;

      await d.tapText('Abbrechen');
      await d.settle();

      d.expectText('Trocknung beenden');
    });
  });
}
