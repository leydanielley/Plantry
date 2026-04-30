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

      // Felder per Key — robust gegen Lazy-ListView, scrollt sich selbst sichtbar
      await d.enterTextByKey('field_room_name', 'Testzelt');
      await d.enterTextByKey('field_room_width', '120');
      await d.enterTextByKey('field_room_depth', '120');
      await d.enterTextByKey('field_room_height', '200');
      await d.enterTextByKey('field_room_watts', '400');

      await d.scrollToKey('save_room');
      await d.tapKey('save_room');
      await d.settle(const Duration(seconds: 3));

      d.expectText('Testzelt');
    });

    testWidgets('Raum anlegen – Pflichtfeld leer → Fehlermeldung', (
      tester,
    ) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('RÄUME');
      await d.tapFAB();

      // Zum Speichern-Button scrollen und direkt drücken (kein Name)
      await d.scrollToKey('save_room');
      await d.tapKey('save_room');

      d.expectText('ist erforderlich');
    });

    testWidgets('Raum anlegen – Buchstaben in Zahlenfeld → kein Crash', (
      tester,
    ) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('RÄUME');
      await d.tapFAB();

      await d.enterTextByKey('field_room_name', 'Buchstaben-Test');
      await d.enterTextByKey('field_room_width', 'abc');
      await d.scrollToKey('save_room');
      await d.tapKey('save_room');
      await d.settle(const Duration(seconds: 3));

      expect(find.byType(Exception), findsNothing);
    });
  });
}
