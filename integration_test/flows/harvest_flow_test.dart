import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/app_driver.dart';

void harvestFlowTests() {
  group('Harvest Flow – Vollständiger Lifecycle', () {
    Future<void> createHarvest(AppDriver d) async {
      await d.tapText('PFLANZEN');
      await d.settle(const Duration(seconds: 2));
      await d.tapText('Test-Pflanze Bloom');

      expect(find.text('Ernte'), findsOneWidget,
          reason: 'Ernte-Button fehlt – Pflanze nicht im Bloom-Status');
      await d.tapText('Ernte');

      // AddHarvestScreen: Nassgewicht (Index 0 in dieser ListView)
      // Erstes TextFormField ist das Gewichtsfeld
      await d.enterTextAt(0, '150');

      // Speichern-Button in ListView → scrollen
      await d.scrollToText('Speichern');
      await d.tapText('Speichern');
      await d.settle(const Duration(seconds: 3));
    }

    testWidgets('Trocknung beenden – gültiges Gewicht', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await createHarvest(d);

      // Direkt auf HarvestDetailScreen (pushAndRemoveUntil)
      await d.scrollToText('Trocknung bearbeiten');
      d.expectText('Trocknung bearbeiten');
      await d.tapText('Trocknung bearbeiten');

      // HarvestDryingScreen: Trocknung wurde beim Anlegen gestartet
      d.expectText('Trocknung beenden');
      await d.tapText('Trocknung beenden');

      expect(find.byType(AlertDialog), findsOneWidget);
      await d.enterTextAt(0, '80');
      await d.tapText('Beenden');
      await d.settle(const Duration(seconds: 3));

      d.expectText('Abgeschlossen');
      d.expectText('Weiter zum Curing');
    });

    testWidgets('Trocknung beenden – leeres Gewicht → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ERNTEN');
      await d.settle(const Duration(seconds: 2));

      // Erste Ernte antippen (PlantryListTile)
      final tiles = find.byType(InkWell);
      if (tiles.evaluate().isNotEmpty) {
        await d.t.tap(tiles.first);
        await d.settle();
      }

      if (!d.hasText('Trocknung bearbeiten')) return;
      await d.tapText('Trocknung bearbeiten');
      if (!d.hasText('Trocknung beenden')) return;
      await d.tapText('Trocknung beenden');

      expect(find.byType(AlertDialog), findsOneWidget);
      await d.tapText('Beenden');
      d.expectText('Ungültiges Gewicht');
    });

    testWidgets('Trocknung beenden – negatives Gewicht → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ERNTEN');
      await d.settle(const Duration(seconds: 2));
      final tiles = find.byType(InkWell);
      if (tiles.evaluate().isNotEmpty) {
        await d.t.tap(tiles.first);
        await d.settle();
      }

      if (!d.hasText('Trocknung bearbeiten')) return;
      await d.tapText('Trocknung bearbeiten');
      if (!d.hasText('Trocknung beenden')) return;
      await d.tapText('Trocknung beenden');

      expect(find.byType(AlertDialog), findsOneWidget);
      await d.enterTextAt(0, '-50');
      await d.tapText('Beenden');
      d.expectText('Ungültiges Gewicht');
    });

    testWidgets('Trocknung beenden – Text statt Zahl → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ERNTEN');
      await d.settle(const Duration(seconds: 2));
      final tiles = find.byType(InkWell);
      if (tiles.evaluate().isNotEmpty) {
        await d.t.tap(tiles.first);
        await d.settle();
      }

      if (!d.hasText('Trocknung bearbeiten')) return;
      await d.tapText('Trocknung bearbeiten');
      if (!d.hasText('Trocknung beenden')) return;
      await d.tapText('Trocknung beenden');

      expect(find.byType(AlertDialog), findsOneWidget);
      await d.enterTextAt(0, 'abc');
      await d.tapText('Beenden');
      d.expectText('Ungültiges Gewicht');
    });
  });

  group('Curing Flow', () {
    testWidgets('Curing starten und beenden', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ERNTEN');
      await d.settle(const Duration(seconds: 2));
      final tiles = find.byType(InkWell);
      if (tiles.evaluate().isNotEmpty) {
        await d.t.tap(tiles.first);
        await d.settle();
      }

      // Curing-Button nur sichtbar wenn Trocknung abgeschlossen
      if (!d.hasText('Curing bearbeiten')) {
        if (d.hasText('Trocknung bearbeiten')) {
          await d.tapText('Trocknung bearbeiten');
          if (d.hasText('Trocknung beenden')) {
            await d.tapText('Trocknung beenden');
            await d.enterTextAt(0, '75');
            await d.tapText('Beenden');
            await d.settle(const Duration(seconds: 2));
          }
          await d.tapBack();
        }
      }

      if (!d.hasText('Curing bearbeiten')) return;
      await d.tapText('Curing bearbeiten');

      d.expectText('Curing jetzt starten');
      await d.tapText('Curing jetzt starten');

      expect(find.byType(AlertDialog), findsOneWidget);
      await d.tapText('Starten');
      await d.settle(const Duration(seconds: 2));

      d.expectText('In Curing');
      d.expectText('Curing beenden');
      await d.tapText('Curing beenden');

      await d.confirmDatePicker();
      await d.settle(const Duration(seconds: 2));

      d.expectText('Abgeschlossen');
      d.expectText('Weiter zur Quality Control');
    });
  });
}
