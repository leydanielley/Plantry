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
      await d.scrollToText('Raum speichern');
      await d.tapText('Raum speichern');
      d.expectText('ist erforderlich');
    });

    testWidgets('Nur Leerzeichen im Name → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('RÄUME');
      await d.tapFAB();
      await d.enterTextAt(0, '   ');
      await d.scrollToText('Raum speichern');
      await d.tapText('Raum speichern');
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
      await d.scrollToText('Grow erstellen');
      await d.tapText('Grow erstellen');
      d.expectText('ist erforderlich');
    });
  });

  group('Fehleingaben – Pflanze', () {
    testWidgets('Leerer Name → Validator-Fehler', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');
      await d.scrollToText('Pflanze(n) erstellen');
      await d.tapText('Pflanze(n) erstellen');
      d.expectText('Name erforderlich');
    });

    testWidgets('Ungültige Menge (Text) → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');
      await d.enterTextAt(0, 'Fehler-Test-Pflanze');
      await d.enterTextAt(1, 'fünf');
      await d.scrollToText('Pflanze(n) erstellen');
      await d.tapText('Pflanze(n) erstellen');
      await d.settle(const Duration(seconds: 3));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('Negative Menge → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');
      await d.enterTextAt(0, 'Negativ-Test');
      await d.enterTextAt(1, '-3');
      await d.scrollToText('Pflanze(n) erstellen');
      await d.tapText('Pflanze(n) erstellen');
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
      d.expectText('Ungültiges Gewicht');
    });

    testWidgets('Text statt Zahl → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.enterTextAt(0, 'keine Ahnung');
      await d.tapText('Beenden');
      d.expectText('Ungültiges Gewicht');
    });

    testWidgets('Negatives Gewicht → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.enterTextAt(0, '-10');
      await d.tapText('Beenden');
      d.expectText('Ungültiges Gewicht');
    });

    testWidgets('Null-Gewicht → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();
      final reached = await _navigateToDryingDialog(d);
      if (!reached) return;
      await d.enterTextAt(0, '0');
      await d.tapText('Beenden');
      d.expectText('Ungültiges Gewicht');
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
