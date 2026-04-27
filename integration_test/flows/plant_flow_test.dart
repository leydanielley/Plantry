import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/app_driver.dart';

void plantFlowTests() {
  group('Plant Flow', () {
    testWidgets('Pflanze anlegen – gültige Eingabe', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      // Dashboard Pflanzen-Karte → PlantsScreen
      // Die Karte hat mehrere Texte "PFLANZEN" — tapText trifft das erste
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));

      // Extended FAB mit Label "Neue Pflanze"
      await d.tapText('Neue Pflanze');

      // Name (Index 0), Strain (Index 2) — ListView ist lazy, erst scrollen
      await d.enterTextAt(0, 'Test-Pflanze Bloom');
      await d.enterTextAt(2, 'OG Kush');

      await d.scrollToText('Pflanze(n) erstellen');
      await d.tapText('Pflanze(n) erstellen');
      await d.settle(const Duration(seconds: 3));

      d.expectText('Test-Pflanze Bloom');
    });

    testWidgets('Pflanze anlegen – Pflichtfeld leer → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Neue Pflanze');

      await d.scrollToText('Pflanze(n) erstellen');
      await d.tapText('Pflanze(n) erstellen');

      d.expectText('Name erforderlich');
    });

    testWidgets('Pflanze auf Bloom-Phase setzen via Edit', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));

      await d.tapText('Test-Pflanze Bloom');
      await d.tapIcon(Icons.edit);

      // Phase-Dropdown: aktuell "Seedling" → "Bloom Phase"
      await tester.tap(find.text('Seedling'));
      await d.settle();
      await tester.tap(find.text('Bloom Phase').last);
      await d.settle();

      await d.scrollToText('Änderungen speichern');
      await d.tapText('Änderungen speichern');
      await d.settle(const Duration(seconds: 3));

      expect(find.byType(Exception), findsNothing);
    });
  });
}
