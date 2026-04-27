import 'package:flutter_test/flutter_test.dart';
import '../helpers/app_driver.dart';

void roomFlowTests() {
  group('Room Flow', () {
    testWidgets('Raum anlegen – gültige Eingabe', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('RÄUME');
      await d.tapFAB();
      d.expectText('Name *');

      // Name und Felder befüllen
      await d.enterTextAt(0, 'Testzelt');
      // ListView ist lazy → erst scrollen damit die unteren Felder aufgebaut werden
      await d.scrollToText('Raum speichern');
      await d.enterTextAt(2, '120');
      await d.enterTextAt(3, '120');
      await d.enterTextAt(4, '200');
      await d.enterTextAt(5, '400');

      await d.tapText('Raum speichern');
      await d.settle(const Duration(seconds: 3));

      d.expectText('Testzelt');
    });

    testWidgets('Raum anlegen – Pflichtfeld leer → Fehlermeldung', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('RÄUME');
      await d.tapFAB();

      // Zum Speichern-Button scrollen und direkt drücken (kein Name)
      await d.scrollToText('Raum speichern');
      await d.tapText('Raum speichern');

      d.expectText('ist erforderlich');
    });

    testWidgets('Raum anlegen – Buchstaben in Zahlenfeld → kein Crash', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('RÄUME');
      await d.tapFAB();

      await d.enterTextAt(0, 'Buchstaben-Test');
      await d.scrollToText('Raum speichern');
      await d.enterTextAt(2, 'abc');
      await d.tapText('Raum speichern');
      await d.settle(const Duration(seconds: 3));

      expect(find.byType(Exception), findsNothing);
    });
  });
}
