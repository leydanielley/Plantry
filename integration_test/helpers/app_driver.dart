import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/main.dart' as app;

/// Hilfsmethoden für Integration Tests — wraps common tester actions.
class AppDriver {
  final WidgetTester tester;

  AppDriver(this.tester);

  /// Direktzugriff auf tester für komplexere Finder-Operationen
  WidgetTester get t => tester;

  /// App starten und auf Dashboard warten.
  /// `app.main()` ist `Future<void> async` — vor `runApp` laufen mehrere awaits
  /// (SharedPreferences, ServiceLocator). Das Future muss explizit awaited
  /// werden, sonst race condition zwischen Init und erstem Frame-Polling.
  /// SplashScreen hat Future.delayed(2s) → pumpAndSettle reicht nicht.
  /// Wir pumpen in Echtzeit bis "Räume" sichtbar ist (max 15s).
  Future<void> launch() async {
    // GetIt ist Process-Singleton. Beim zweiten testWidgets-Aufruf würde
    // setupServiceLocator() in app.main() crashen, weil DatabaseHelper bereits
    // registriert ist. reset() ist auf leerer Registry ein No-Op — sicher
    // beim ersten Launch.
    await getIt.reset();
    await app.main();
    // Dashboard GridTile labels are .toUpperCase() → wait for "RÄUME"
    await waitForText('RÄUME', timeout: const Duration(seconds: 15));
  }

  /// Wartet bis ein Text auf dem Screen erscheint (Polling mit pump-Frames).
  Future<void> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text(text).evaluate().isNotEmpty) return;
    }
    // Letzter Versuch + verständliche Fehlermeldung
    expect(
      find.text(text),
      findsAtLeastNWidgets(1),
      reason: 'Waited ${timeout.inSeconds}s but "$text" never appeared',
    );
  }

  /// Pump mit großzügigem Timeout für DB-Operationen
  Future<void> settle([Duration d = const Duration(seconds: 3)]) async {
    await tester.pumpAndSettle(d);
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> tapText(String text) async {
    final finder = find.text(text);
    expect(
      finder,
      findsAtLeastNWidgets(1),
      reason: 'Text "$text" not found on screen',
    );
    await tester.tap(finder.first);
    await settle();
  }

  Future<void> tapTextIfExists(String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await settle();
    }
  }

  Future<void> tapIcon(IconData icon) async {
    final finder = find.byIcon(icon);
    expect(
      finder,
      findsAtLeastNWidgets(1),
      reason: 'Icon $icon not found on screen',
    );
    await tester.tap(finder.first);
    await settle();
  }

  Future<void> tapFAB() async {
    await tester.tap(find.byType(FloatingActionButton));
    await settle();
  }

  /// Tippt ein Widget mit dem angegebenen `Key('name')`.
  /// Bevorzugt gegenüber `tapText` für UI-Elemente, deren sichtbarer Text
  /// sich durch i18n oder UI-Refactor ändern kann (z.B. Save-Buttons).
  Future<void> tapKey(String name) async {
    final finder = find.byKey(Key(name));
    expect(
      finder,
      findsAtLeastNWidgets(1),
      reason: 'Key("$name") not found on screen',
    );
    // ensureVisible eliminiert Hit-Test-Failures bei Widgets hinter Tastatur
    // oder unterhalb des Viewports. Pump-Spacer danach lässt Stretching-
    // Overscroll auslaufen, bevor der Tap an einen GestureDetector geht
    // (z.B. PlantryButton mit onTapDown/onTapUp — der Tap könnte sonst
    // als Cancel interpretiert werden).
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder.first);
    await settle();
  }

  Future<void> tapBack() async {
    final nav = find.byType(BackButton);
    if (nav.evaluate().isNotEmpty) {
      await tester.tap(nav.first);
    } else {
      // Drawer-Close or system back
      final backIcon = find.byIcon(Icons.arrow_back);
      if (backIcon.evaluate().isNotEmpty) {
        await tester.tap(backIcon.first);
      }
    }
    await settle();
  }

  // ── Text Input ─────────────────────────────────────────────────────────────

  /// Erstes TextFormField befüllen
  Future<void> enterTextAt(int index, String text) async {
    final fields = find.byType(TextFormField);
    await tester.tap(fields.at(index));
    await settle();
    await tester.enterText(fields.at(index), text);
    await settle();
  }

  /// Befüllt das `TextFormField` innerhalb des Widgets mit `Key('name')`.
  /// Bevorzugt gegenüber `enterTextAt` für Form-Felder mit potenziell
  /// off-screen-Positionen (Tastatur-Overlay, Viewport-Bottom).
  /// Scrollt das Ziel-Feld immer in den sichtbaren Bereich, bevor getappt
  /// wird — verhindert Hit-Test-Failures.
  Future<void> enterTextByKey(
    String name,
    String text, {
    Type withinType = Form,
  }) async {
    final container = find.byKey(Key(name));
    if (container.evaluate().isEmpty) {
      // Field nicht im Tree — scrollen bis es erscheint
      final scrollable = find.descendant(
        of: find.byType(withinType),
        matching: find.byType(Scrollable),
      );
      final anchor = scrollable.evaluate().isNotEmpty
          ? scrollable.first
          : find.byType(Scrollable).first;
      await tester.scrollUntilVisible(container, 200, scrollable: anchor);
      await settle();
    }
    // Auch wenn Field bereits im Tree ist: ensureVisible scrollt es in den
    // sichtbaren Bereich (oberhalb der Soft-Tastatur). Idempotent für bereits
    // sichtbare Widgets.
    await tester.ensureVisible(container.first);
    await tester.pump(const Duration(milliseconds: 200));
    final field = find.descendant(
      of: container,
      matching: find.byType(TextFormField),
    );
    expect(
      field,
      findsOneWidget,
      reason:
          'Expected exactly one TextFormField inside Key("$name"), but found ${field.evaluate().length}',
    );
    await tester.tap(field);
    await settle();
    await tester.enterText(field, text);
    await settle();
  }

  /// TextFormField nach Label-Text finden und befüllen
  Future<void> enterTextByLabel(String label, String text) async {
    // PlantryFormField hat einen Text-Widget als Label direkt über dem Field.
    // Wir suchen das TextFormField, das auf den Label-Text folgt.
    final labelFinder = find.text(label);
    expect(
      labelFinder,
      findsAtLeastNWidgets(1),
      reason: 'Label "$label" not found',
    );

    // Nächstes TextFormField nach dem Label
    // Erstes TextFormField in der Nähe des Labels via ancestor
    await tester.enterText(
      find
          .descendant(
            of: find.ancestor(
              of: labelFinder.first,
              matching: find.byType(Column),
            ),
            matching: find.byType(TextFormField),
          )
          .first,
      text,
    );
    await settle();
  }

  Future<void> clearAndEnterText(Finder finder, String text) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.enterText(finder, text);
    await settle();
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────

  /// Scrollt bis `text` sichtbar ist.
  ///
  /// `withinType` engt den Scrollable-Anker ein (Default: `Form`). Auf Screens
  /// mit mehreren Scrollables (z.B. Dashboard mit SingleChildScrollView und
  /// Form-ListView) muss explizit der richtige Anker gesetzt werden, sonst
  /// trifft `find.byType(Scrollable).first` den falschen Container.
  Future<void> scrollToText(String text, {Type withinType = Form}) async {
    final scrollable = find.descendant(
      of: find.byType(withinType),
      matching: find.byType(Scrollable),
    );
    final anchor = scrollable.evaluate().isNotEmpty
        ? scrollable.first
        : find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: anchor);
    await settle();
  }

  /// Scrollt bis zum Widget mit `Key('name')`. Nutzt denselben Form-Anker
  /// wie `scrollToText`, fällt auf den ersten Scrollable zurück wenn
  /// keiner gefunden wird.
  Future<void> scrollToKey(String name, {Type withinType = Form}) async {
    final scrollable = find.descendant(
      of: find.byType(withinType),
      matching: find.byType(Scrollable),
    );
    final anchor = scrollable.evaluate().isNotEmpty
        ? scrollable.first
        : find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(Key(name)),
      200,
      scrollable: anchor,
    );
    await settle();
  }

  Future<void> scrollToTextInListView(String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await settle();
  }

  // ── Assertions ─────────────────────────────────────────────────────────────

  void expectText(String text) {
    expect(
      find.text(text),
      findsAtLeastNWidgets(1),
      reason: 'Expected to find text: "$text"',
    );
  }

  void expectNoText(String text) {
    expect(
      find.text(text),
      findsNothing,
      reason: 'Expected NOT to find text: "$text"',
    );
  }

  /// Prüft, dass `text` in einer aktuell sichtbaren `SnackBar` lebt.
  /// Verhindert False-Positives durch identische Texte außerhalb der SnackBar
  /// (z.B. Validator-Tooltip + SnackBar zeigen denselben String).
  void expectSnackBar(String text) {
    expect(
      find.descendant(of: find.byType(SnackBar), matching: find.text(text)),
      findsAtLeastNWidgets(1),
      reason: 'Expected SnackBar to contain text: "$text"',
    );
  }

  bool hasText(String text) => find.text(text).evaluate().isNotEmpty;

  // ── Date Picker ─────────────────────────────────────────────────────────────

  /// DatePicker-OK-Button tippen (Standard-Material-DatePicker)
  Future<void> confirmDatePicker() async {
    // Material 3 date picker hat "OK" Button
    final ok = find.text('OK');
    if (ok.evaluate().isNotEmpty) {
      await tester.tap(ok.first);
    } else {
      // Fallback: "Fertig" oder "Bestätigen"
      final done = find.text('Fertig');
      if (done.evaluate().isNotEmpty) {
        await tester.tap(done.first);
      }
    }
    await settle();
  }
}
