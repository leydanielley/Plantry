import 'package:flutter_test/flutter_test.dart';
import '../helpers/app_driver.dart';

void growFlowTests() {
  group('Grow Flow', () {
    testWidgets('Grow anlegen – gültige Eingabe', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ANBAUTEN');
      await d.tapFAB();
      d.expectText('Name *');

      await d.enterTextAt(0, 'Test-Grow #1');
      await d.scrollToText('Grow erstellen');
      await d.tapText('Grow erstellen');
      await d.settle(const Duration(seconds: 3));

      d.expectText('Test-Grow #1');
    });

    testWidgets('Grow anlegen – Pflichtfeld leer → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ANBAUTEN');
      await d.tapFAB();

      await d.scrollToText('Grow erstellen');
      await d.tapText('Grow erstellen');

      d.expectText('ist erforderlich');
    });

    testWidgets('Grow anlegen – sehr langer Name (Grenzwert)', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ANBAUTEN');
      await d.tapFAB();

      final longName = 'A' * 200;
      await d.enterTextAt(0, longName);
      await d.scrollToText('Grow erstellen');
      await d.tapText('Grow erstellen');
      await d.settle(const Duration(seconds: 3));

      expect(find.byType(Exception), findsNothing);
    });
  });
}
