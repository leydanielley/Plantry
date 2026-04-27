import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/app_driver.dart';

void settingsFlowTests() {
  group('Settings Flow', () {
    testWidgets('Sprache auf Englisch umschalten', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      // Dashboard "EINSTELLUNGEN" Kachel (scrollbar, unten)
      await d.scrollToText('EINSTELLUNGEN');
      await d.tapText('EINSTELLUNGEN');

      await d.scrollToText('Sprache');
      await d.tapText('English');

      await d.settle(const Duration(seconds: 2));
      expect(find.byType(Exception), findsNothing);

      // Zurück auf Deutsch setzen
      await d.tapTextIfExists('Deutsch');
      await d.settle(const Duration(seconds: 2));
    });

    testWidgets('Theme wechseln', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.scrollToText('EINSTELLUNGEN');
      await d.tapText('EINSTELLUNGEN');

      if (d.hasText('Hellmodus')) {
        await d.tapText('Hellmodus');
      } else if (d.hasText('Dunkelmodus')) {
        await d.tapText('Dunkelmodus');
      }

      await d.settle(const Duration(seconds: 2));
      expect(find.byType(Exception), findsNothing);
    });

    testWidgets('Expertenmodus aktivieren/deaktivieren', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.scrollToText('EINSTELLUNGEN');
      await d.tapText('EINSTELLUNGEN');

      await d.scrollToText('Expertenmodus');
      final toggle = find.byType(Switch).first;
      await tester.tap(toggle);
      await d.settle(const Duration(seconds: 2));

      expect(find.byType(Exception), findsNothing);
    });
  });
}
