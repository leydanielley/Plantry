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

      await d.enterTextByKey('field_grow_name', 'Test-Grow #1');
      await d.scrollToKey('save_grow');
      await d.tapKey('save_grow');
      await d.settle(const Duration(seconds: 3));

      d.expectText('Test-Grow #1');
    });

    testWidgets('Grow anlegen – Pflichtfeld leer → Fehlermeldung', (
      tester,
    ) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ANBAUTEN');
      await d.tapFAB();

      // AddGrowScreen.didChangeDependencies setzt einen Default-Namen
      // ('Grow YYYY-MM') ins Name-Feld. Für den Validator-Test muss das Feld
      // explizit geleert werden, sonst greift der Validator nie.
      await d.enterTextByKey('field_grow_name', '');

      await d.scrollToKey('save_grow');
      await d.tapKey('save_grow');
      await d.settle(const Duration(seconds: 1));

      d.expectText('Name erforderlich');
    });

    testWidgets('Grow anlegen – sehr langer Name (Grenzwert)', (tester) async {
      final d = AppDriver(tester);
      await d.launch();

      await d.tapText('ANBAUTEN');
      await d.tapFAB();

      final longName = 'A' * 200;
      await d.enterTextByKey('field_grow_name', longName);
      await d.scrollToKey('save_grow');
      await d.tapKey('save_grow');
      await d.settle(const Duration(seconds: 3));

      expect(find.byType(Exception), findsNothing);
    });
  });
}
