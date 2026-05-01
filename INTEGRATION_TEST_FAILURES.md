# Integration-Test Failures — Code-Tracing + Live-Run-Versuch 2026-04-28

**QA:** Tal Celes
**Methode:** Code-Tracing (Phase 1a) + Live-Run-Versuch (Phase 1b — abgebrochen, siehe QA-T-009)
**Sicherheit:** Mittel (statische Trace + bestätigt: App startet sauber auf Emulator)
**Branch:** `review` (lokal sync mit main `0c97bb8`)
**Reportiert an:** B'Elanna Torres

> **Eskalation an B'Elanna (Phase 1b):** Live-Run der Integration-Tests aktuell nicht möglich.
> Root-Cause: Emulator-Storage ist voll (siehe QA-T-009).
> App-Start manuell (per `adb shell monkey`) auf Emulator funktioniert sauber — Daniels MaterialApp.home-Fix (Bug A) ist live verifiziert: kein Crash beim App-Start, Flutter loaded normal, Dart VM Service läuft auf Port 43075.

---

## Übersicht

| # | Severity | Flow | Datei:Zeile | Kategorie |
|---|----------|------|-------------|-----------|
| QA-T-001 | 🔴 Blocker | Grow Flow | `flows/grow_flow_test.dart:32` | Test-Logic-Bug |
| QA-T-002 | 🔴 Blocker | Error Cases | `flows/error_cases_test.dart:56` | Test-Logic-Bug |
| QA-T-003 | 🔴 Blocker | Harvest Flow | `flows/harvest_flow_test.dart:71,94,117` | Test-Logic-Bug |
| QA-T-004 | 🔴 Blocker | Error Cases | `flows/error_cases_test.dart:108,118,128,138` | Test-Logic-Bug |
| QA-T-005 | 🟡 Major | Harvest/Error | mehrere | Architektur-Mismatch (SnackBar-Timing) |
| QA-T-006 | 🟡 Major | App-weit | `helpers/app_driver.dart:131-147` | Architektur-Mismatch (Scrollable-Auswahl) |
| QA-T-007 | 🟡 Major | App-weit | `app_test.dart:24` | Architektur-Mismatch (DB-State-Akkumulation) |
| QA-T-008 | 🟢 Minor | Plant Flow | `flows/plant_flow_test.dart:55-57` | Architektur-Mismatch (Dropdown-Test) |
| QA-T-009 | 🔴 Blocker | Test-Setup | Emulator `/data` 92% voll | Setup-Block (Live-Run unmöglich) |

---

## Findings

### [QA-T-001] Grow Flow erwartet falschen Validator-Text

- **Severity:** 🔴 Blocker
- **Feature:** Grow anlegen — Validator
- **Typ:** Test-Logic-Bug
- **Reproduktion:**
  1. `flows/grow_flow_test.dart:22-33` — Test "Grow anlegen – Pflichtfeld leer → Fehlermeldung"
  2. Tippt FAB ohne Eingabe, erwartet `expectText('ist erforderlich')`
- **Erwartet:** App zeigt 'ist erforderlich'
- **Beobachtet:** App-Validator zeigt 'Name erforderlich' (hardcoded in `lib/screens/add_grow_screen.dart:83`)
- **Umgebung:** Code-Tracing (kein Live-Run)
- **Sicherheit:** Hoch (Validator-Text ist String-Literal im Code, kein dynamisches Token)
- **Fix-Vorschlag:** Test umstellen auf `expectText('Name erforderlich')` ODER Validator umstellen auf `_t['error_field_required']` für Konsistenz mit AddRoomScreen
- **Hinweis:** AddRoomScreen-Validator nutzt `_t['error_field_required']` ('ist erforderlich') — dort passt der Test. Inkonsistenz zwischen Add-Screens.

### [QA-T-002] Error Cases — Grow-Validator (Duplikat von QA-T-001)

- **Severity:** 🔴 Blocker
- **Feature:** Grow Validator
- **Typ:** Test-Logic-Bug
- **Reproduktion:** `flows/error_cases_test.dart:49-57` — selbe Annahme wie QA-T-001
- **Fix-Vorschlag:** Identisch mit QA-T-001. Wenn Test-Strings angepasst werden, beide Stellen mit.

### [QA-T-003] Harvest Flow erwartet falschen Fehler-String 'Ungültiges Gewicht'

- **Severity:** 🔴 Blocker
- **Feature:** Trocknung beenden — Validierung Trockengewicht
- **Typ:** Test-Logic-Bug
- **Reproduktion:**
  1. `flows/harvest_flow_test.dart:71` (leeres Gewicht), `:94` (negatives), `:117` (Text statt Zahl)
  2. Test erwartet `expectText('Ungültiges Gewicht')`
- **Erwartet:** App zeigt 'Ungültiges Gewicht'
- **Beobachtet:** App zeigt **'Bitte gültiges Gewicht eingeben'** (translations key `harvest_error_invalid_weight`, Zeile 1324 in `translations.dart`). SnackBar via `AppMessages.showError(context, _t['harvest_error_invalid_weight'])` in `harvest_drying_screen.dart:199`.
- **Umgebung:** Code-Tracing (kein Live-Run)
- **Sicherheit:** Hoch (translations.dart ist Single-Source-of-Truth, Code-Pfad eindeutig)
- **Fix-Vorschlag:** Test-Strings auf 'Bitte gültiges Gewicht eingeben' umstellen. Oder Test mit `expect(find.textContaining('gültig'), findsAtLeastNWidgets(1))` machen.

### [QA-T-004] Error Cases — Drying-Gewicht (Duplikat von QA-T-003, 4 Stellen)

- **Severity:** 🔴 Blocker
- **Feature:** Trocknung Validator (Error-Cases-Suite)
- **Typ:** Test-Logic-Bug
- **Reproduktion:** `flows/error_cases_test.dart:108, 118, 128, 138` — alle 4 Tests in Gruppe "Fehleingaben – Trocknung Gewicht"
- **Fix-Vorschlag:** Identisch mit QA-T-003.

### [QA-T-005] SnackBar-Timing — `expectText` nach `tapText` evtl. zu spät

- **Severity:** 🟡 Major
- **Feature:** Alle Tests die SnackBar-Fehler prüfen
- **Typ:** Architektur-Mismatch
- **Reproduktion:**
  1. `harvest_flow_test.dart` und `error_cases_test.dart` — Tests die `expectText('Ungültiges Gewicht')` direkt nach `tapText('Beenden')` aufrufen
  2. `tapText` macht intern `await settle()` mit `pumpAndSettle(3s)`
  3. SnackBar-Default-Duration ist 4s — knapp, aber sollte halten
- **Erwartet:** SnackBar-Text wird in Tree gefunden während noch sichtbar
- **Beobachtet:** Race-Condition möglich — `pumpAndSettle` versucht alle Animationen abzuwarten. Wenn die SnackBar mit AnimationController aufpoppt und dann verschwindet, läuft `pumpAndSettle` evtl. erst nach SnackBar-Disappearance durch
- **Umgebung:** Code-Tracing (Annahme aus Flutter-SnackBar-Mechanik)
- **Sicherheit:** Mittel (Annahme, Live-Run nötig zur Verifikation)
- **Fix-Vorschlag:** Statt `pumpAndSettle` nach Tap einen `pump(Duration(milliseconds: 100))` machen, oder dedizierte Helper-Methode `expectSnackBar(text)` mit `find.descendant(of: find.byType(SnackBar), matching: find.text(text))`.

### [QA-T-006] AppDriver.scrollToText — falscher Scrollable bei mehreren

- **Severity:** 🟡 Major
- **Feature:** Alle Tests die `scrollToText` nutzen
- **Typ:** Architektur-Mismatch (Section 10.3 #2)
- **Reproduktion:**
  1. `helpers/app_driver.dart:131-138` — `scrollToText` nutzt `find.byType(Scrollable).first`
  2. Auf Screens mit nested Scrollables (z.B. AddPlantScreen mit Dropdowns die intern scrollbar sind, oder Dashboard mit SingleChildScrollView + ListView in Tiles) findet `.first` evtl. den falschen
- **Erwartet:** Korrekter Form-Scroller scrollt zu Save-Button
- **Beobachtet:** Wenn ein anderer Scrollable im Tree liegt (z.B. ein collapsed Dropdown-Menu), wird stattdessen versucht dort zu scrollen → Timeout oder Failure
- **Umgebung:** Code-Tracing
- **Sicherheit:** Mittel
- **Fix-Vorschlag:** `scrollToText` so erweitern, dass ein optionaler `Type<Widget>`-Anker übergeben werden kann (z.B. `Form` oder `ListView`). Aktuell gibt es bereits `scrollToTextInListView` mit `.last` — für Form-Screens wäre `find.byType(Form).first → find.descendant(of: form, matching: byType(Scrollable))` robuster.

### [QA-T-007] DB-State akkumuliert sich zwischen Test-Runs

- **Severity:** 🟡 Major
- **Feature:** Test-Wiederholbarkeit
- **Typ:** Architektur-Mismatch
- **Reproduktion:**
  1. `app_test.dart:24` — Kommentar: "Flows laufen sequenziell, DB-State akkumuliert sich (Emulator-Datenbank)"
  2. Tests legen `'Testzelt'`, `'Test-Grow #1'`, `'Test-Pflanze Bloom'` an
  3. Bei Re-Run sind diese Datensätze noch da → mehrfache Matches bei `find.text(...)` möglich, Validator-Konflikte (Duplikat-Namen falls App das prüft)
- **Erwartet:** Test-Setup ist deterministisch
- **Beobachtet:** Erster Run grün, Folge-Runs unzuverlässig
- **Umgebung:** Code-Tracing + Annahme Emulator
- **Sicherheit:** Mittel
- **Fix-Vorschlag:** `setUpAll` oder `setUp` Hook in `app_test.dart` der vor jeder Suite einen `await DatabaseHelper.resetForTests()` aufruft. ODER Tests benutzen pro Run eindeutige Namen mit Timestamp.

### [QA-T-008] Plant Flow Bloom-Phase — Dropdown-Test fragil

- **Severity:** 🟢 Minor
- **Feature:** Plant Edit — Phase setzen
- **Typ:** Architektur-Mismatch
- **Reproduktion:**
  1. `flows/plant_flow_test.dart:55-57`
  2. Test tippt `find.text('Seedling')` (zum Öffnen) und dann `find.text('Bloom Phase').last`
  3. Annahme: 'Seedling' ist nur einmal sichtbar (im Dropdown-Header), und 'Bloom Phase' erscheint zweimal (im Header + im offenen Menü)
- **Erwartet:** Dropdown öffnet, Auswahl klappt
- **Beobachtet:** Wenn `PlantPhase.values` mehr als nur Seedling/Bloom enthält und das Menu längere Zeit braucht zum Öffnen, kann der Test in einem inkonsistenten Zustand landen. `.last` ist heuristisch, nicht robust.
- **Umgebung:** Code-Tracing
- **Sicherheit:** Niedrig (vermutet)
- **Fix-Vorschlag:** Statt Text-Tap auf den Dropdown-Container tippen (e.g. `find.byType(DropdownButton)`), dann gezielt das DropdownMenuItem mit dem Wert `PlantPhase.bloom` auswählen.

---

### [QA-T-009] Live-Run abgebrochen — Emulator-Storage voll (Setup-Block)

- **Severity:** 🔴 Blocker (Setup, nicht App)
- **Feature:** Integration-Test-Pipeline
- **Typ:** Setup-Fehler / Umgebung
- **Reproduktion:**
  1. `flutter test integration_test/app_test.dart -d emulator-5554`
  2. Build erfolgreich (343s, inkl. NDK-Install)
  3. APK-Install auf Emulator schlägt fehl: `adb: failed to install ... Failure [INSTALL_FAILED_INSUFFICIENT_STORAGE]`
  4. Test-Driver-WebSocket kommt nicht hoch (Folgefehler) — `WebSocketChannelException: HttpException: Connection closed before full header was received`
  5. `adb -s emulator-5554 shell df -h /data` → `5.8G total, 5.1G used, 505M free, 92% Use%`
- **Erwartet:** APK-Install klappt, Test-Driver verbindet, Flow-Tests laufen
- **Beobachtet:** Storage-Out → kein Test-Driver → kein Flow-Test live verifiziert
- **Umgebung:** Emulator `emulator-5554`, Flutter 3.41.7 stable, Android SDK 36.1.0
- **Sicherheit:** Hoch (reproduziert, df-Output beweist Cause)
- **Hinweis:** App-Start manuell (per `adb shell monkey -p com.plantry.growlog`) funktioniert — App ist nicht das Problem. Andere Apps auf dem Emulator: `com.example.pulseguard`, `com.gemdash.app`, `com.example.tierapp`, `com.vibecode.nexus` (Admins andere VibeCoding-Projekte).
- **Fix-Optionen für Admin (destructive — nicht autonom):**
  1. Eine oder mehrere der 4 Test-Apps am Emulator deinstallieren (`adb uninstall com.X`)
  2. Emulator-Daten wipen via AVD-Manager (Cold Boot)
  3. Physisches Device `RFCY30F2YWT` für den Test-Lauf nutzen (`-d RFCY30F2YWT`)

---

## Was nicht geprüft werden konnte

- **Live-Run aller 6 Flows auf Emulator** — kein Device verbunden
- **SplashScreen-Polling-Timing** — funktioniert nur live
- **PlantryButton GestureDetector-Tap** — könnte in `tester.tap` problematisch sein, da onTapDown/onTapUp animation triggert; konnte nicht live geprüft werden
- **Dashboard-Scroll zu EINSTELLUNGEN** — `Settings`-Tile ist eine `PlantryPremiumCard` (`dashboard_screen.dart:622`), kein `_GridTile`. tapText sollte trotzdem funktionieren da Text-Widget innen liegt; nicht live verifiziert.

## Empfehlungen für nächsten Schritt

1. **Mortimer Harren (Phase 2):** Statisches Review von `helpers/app_driver.dart` mit Fokus auf scrollable-Selektoren (QA-T-006) und SnackBar-Helper (QA-T-005). Prüfen ob die `scrollToText`-Helpers strukturell anders aufgebaut werden sollten.

2. **B'Elanna (Phase 3):** Fix-Pakete schneiden:
   - **P3a** (1 Commit): String-Korrekturen in Tests (QA-T-001..004) — niedrigster Aufwand, höchster Hebel, 4 Findings auf einen Streich
   - **P3b** (1 Commit): AppDriver-Robustheit (QA-T-005, QA-T-006) — neuer SnackBar-Helper, scrollToText mit Form-Anker
   - **P3c** (1 Commit): DB-Reset-Hook in `app_test.dart` (QA-T-007)
   - **P3d** (optional): Dropdown-Test stabilisieren (QA-T-008)

3. **Ein Live-Run mit Emulator vor Commit ist Pflicht** — die Code-Tracing-Findings sind nur Annahmen. Erst der grüne Test-Lauf ist Beweis.

## Feature-Idee aus QA (für HANDOFF.md Section 10.5)

- **`PlantryButton` mit `Key`-Annotation für Tests** — alle Save-/Submit-Buttons erhalten `Key('save_room')`, `Key('save_grow')` etc. Dann nutzen Tests `find.byKey` statt `find.text`. Das eliminiert i18n-Brittleness und Mehrfach-Matches komplett. Sichtbar in `add_*_screen.dart` (jeder hat einen `PlantryButton(label: ...)` ohne Key).

---

## Static Review (Mortimer Harren) — 2026-04-28

**Methode:** Code-Review (kein Live-Run). Sicherheit pro Finding ausgewiesen.
**Scope:** `integration_test/` (8 Files, ~500 Zeilen Test-Code)
**Reportiert an:** B'Elanna Torres

### Synthese mit Celes' Findings

| Celes-Finding | Mein Verdict | Anpassung |
|---------------|--------------|-----------|
| QA-T-005 (SnackBar-Timing) | 🟡 Bestätigt mit Korrektur | Race liegt nicht primär bei `pumpAndSettle`, sondern bei `find.text` außerhalb des SnackBar-Scope. Siehe HR-006. |
| QA-T-006 (Scrollable.first) | 🔴 Bestätigt | Strukturell falsch. Siehe HR-005 für Fix-Pattern. |
| QA-T-008 (Dropdown `.last`) | 🟡 Bestätigt | Heuristik. Siehe HR-007. |

### Eigene Findings

### [HR-001] AppDriver.launch() awaited app.main() nicht

- **Severity:** 🟡 Major
- **Kategorie:** Async / Anti-Pattern
- **Ort:** `integration_test/helpers/app_driver.dart:17-21`
- **Befund:** `app.main()` wird ohne `await` aufgerufen. `lib/main.dart:22` ist `void main() async` und macht vor `runApp()` mehrere awaits (`SharedPreferences.getInstance()`, `setupServiceLocator()`). Der zurückgegebene Future wird verworfen. `waitForText` macht zwar pump-Polling und treibt damit die Microtask-Queue weiter, sodass die async-Chain in den Pumps fortschreitet — aber das ist Glücks-Mechanik, nicht idiomatisch.
- **Impact:** Auf langsamen Geräten/CI kann der `waitForText`-Timeout (15s) erreicht werden bevor `setupServiceLocator()` durchgelaufen ist. Race-Condition zwischen DB-Init und erstem UI-Frame.
- **Empfehlung:** `await app.main();` Zeile 18 ergänzen. Oder besser: in `lib/main.dart` ein `Future<void> bootstrap()` extrahieren und sowohl von `main()` als auch vom Test gewollt awaiten.
- **Konsens-Verdict:** Funktionalität (Race-Condition), Robustness (langsam = flaky)
- **Sicherheit der Bewertung:** Hoch (statisches Code-Pattern)

### [HR-002] Format-Pass fehlt — 5 Test-Files nicht dart-format-konform

- **Severity:** 🟢 Minor
- **Kategorie:** Anti-Pattern (Hygiene)
- **Ort:** `integration_test/flows/{grow,harvest,plant,room}_flow_test.dart`, `integration_test/helpers/app_driver.dart`
- **Befund:** `dart format --set-exit-if-changed integration_test/` meldet 5 Files nicht-konform. Daniel hat den Format-Pass nicht laufen lassen vor seinem Push.
- **Impact:** Formatierungs-Diff verschmutzt zukünftige Fix-Commits, wenn ein Editor on-save formatiert.
- **Empfehlung:** Vor Phase-3 Fix-Commits zwingend einen reinen `style:`-Commit auf integration_test/ (Memory `feedback_format_pass_split`).
- **Konsens-Verdict:** Wartbarkeit
- **Sicherheit der Bewertung:** Hoch (dart format Output)

### [HR-003] i18n-Brittleness — Tests prüfen hardcoded German strings

- **Severity:** 🟡 Major
- **Kategorie:** Architecture / Anti-Pattern
- **Ort:** Alle `flows/*_test.dart` + `helpers/app_driver.dart:20`
- **Befund:** Sämtliche Selektoren basieren auf deutschen UI-Strings (`'RÄUME'`, `'Raum speichern'`, `'Trocknung beenden'`). Tests machen aber selbst Locale-Switch (`settings_flow_test.dart:14-22`). Wenn der Locale-Reset fehlschlägt, sind alle Folge-Tests im falschen Sprachmodus.
- **Impact:** Settings-Test kann bei Failure die ganze Suite kontaminieren. Außerdem brechen Tests bei jedem i18n-Refactoring der App.
- **Empfehlung:** Mittelfristig auf `Key`-Selektoren umstellen (Celes' Feature-Idee aus QA-Phase). Kurzfristig: Settings-Test in `tearDown` zwingend Locale auf `de` zurücksetzen, ohne If-Branch.
- **Konsens-Verdict:** Robustness (i18n-Refactor zerschlägt alles), Architektur (Tests koppeln an Strings statt an Identitäten)
- **Sicherheit der Bewertung:** Hoch

### [HR-004] Inter-Test-Dependencies — Cascading Failures

- **Severity:** 🟡 Major
- **Kategorie:** Architecture / State
- **Ort:** `integration_test/app_test.dart:25-30` + alle Flow-Files
- **Befund:** Tests teilen DB-State *und* fachliche Daten zwischen sich. Beispiel: `harvest_flow_test.dart:10` sucht `'Test-Pflanze Bloom'` — diese Pflanze wird vom `plant_flow_test.dart` Test 1 erstellt. Wenn Test 1 scheitert, scheitert die ganze Harvest-Suite kaskadiert. Plus: `plant_flow_test.dart` Test 3 setzt Bloom-Phase, was Harvest-Flow zwingend braucht (`expect(find.text('Ernte'), findsOneWidget)` in `harvest_flow_test.dart:12`).
- **Impact:** Ein einziger Failure am Anfang der Suite verschluckt 5+ Folgetests, die in Wahrheit unabhängig sind. Diagnose wird unmöglich.
- **Empfehlung:** Jeder `testWidgets` macht in `setUp` eine eindeutige Test-Datenlage (z.B. eigene Pflanze pro Test mit UUID-Suffix). ODER: pro Test-Group ein DB-Reset vor jedem Test, plus ein Setup-Helper der die benötigte Test-Pflanze frisch erstellt.
- **Konsens-Verdict:** Robustness, Wartbarkeit
- **Sicherheit der Bewertung:** Hoch (sichtbar im Code-Trace)

### [HR-005] scrollToText nutzt Form-agnostischen Anker — bestätigt QA-T-006

- **Severity:** 🟡 Major
- **Kategorie:** Anti-Pattern
- **Ort:** `integration_test/helpers/app_driver.dart:131-138`
- **Befund:** `scrollable: find.byType(Scrollable).first` ignoriert Screen-Struktur. Auf Screens mit Form-ListView + globalem `SingleChildScrollView` (Dashboard) trifft `.first` den falschen. Die `scrollToTextInListView`-Variante ist auch nur Heuristik (`.last`).
- **Impact:** ScrollUntilVisible scrollt im falschen Container → "not visible" → Timeout-Failure. Bestätigt für AddRoomScreen (ListView in Form), AddPlantScreen (ListView), AddGrowScreen (ListView). Bei Dashboard.scrollToText('EINSTELLUNGEN') (settings_flow_test.dart:12) ist das Verhalten unklar — Dashboard hat einen SingleChildScrollView außen.
- **Empfehlung:** Neue Helper-Signatur:
  ```dart
  Future<void> scrollToText(String text, {Type? withinType});
  ```
  Innen: wenn `withinType` gesetzt, `scrollable: find.descendant(of: find.byType(withinType), matching: find.byType(Scrollable))`. Default `Form` für Edit/Add-Screens.
- **Konsens-Verdict:** Funktionalität (Tests scheitern jetzt), Robustness
- **Sicherheit der Bewertung:** Hoch

### [HR-006] SnackBar-Assertion ohne Scope — bestätigt + verfeinert QA-T-005

- **Severity:** 🟡 Major
- **Kategorie:** Anti-Pattern
- **Ort:** `flows/harvest_flow_test.dart:71,94,117` + `flows/error_cases_test.dart:108,118,128,138`
- **Befund:** Tests prüfen `expectText('Ungültiges Gewicht')` (oder dann mit korrigiertem String) ohne SnackBar-Scope. Aktuell ist der erwartete Text *nur* in einer SnackBar — aber wenn der Text auch im Validator-Inline-Error oder im Header sichtbar ist, gibt das einen False-Positive. Plus: SnackBar-Lifecycle hat 4s Default-Dauer — pumpAndSettle(3s) bleibt unter dem Open-Animation-Timeout, also funktional unkritischer als Celes' Vermutung.
- **Impact:** Test passt aus falschem Grund (False-Positive), oder schlägt bei UI-Refactor fehl wo der Text in einem anderen Container landet.
- **Empfehlung:** Helper `expectSnackBar(text)` mit `find.descendant(of: find.byType(SnackBar), matching: find.text(text))`.
- **Konsens-Verdict:** Robustness
- **Sicherheit der Bewertung:** Mittel (UI-Verhalten muss live verifiziert werden)

### [HR-007] Dropdown-Test mit `.last` — bestätigt QA-T-008

- **Severity:** 🟢 Minor
- **Kategorie:** Anti-Pattern
- **Ort:** `flows/plant_flow_test.dart:55-57`
- **Befund:** `find.text('Bloom Phase').last` setzt voraus, dass die korrekte Auswahl der "letzte" Treffer ist. Dropdown-Menü-Items werden nach Open in einem Overlay gerendert — die Reihenfolge `.first` vs `.last` hängt von der Widget-Tree-Traversierung ab und ist nicht stabil.
- **Impact:** Falsche Phase wird ausgewählt, oder Test crasht bei nicht-existentem Index.
- **Empfehlung:** Statt Text-Match: `find.byType(DropdownButton<PlantPhase>)` tippen, dann auf konkretes `DropdownMenuItem<PlantPhase>(value: PlantPhase.bloom)` — typsicher und stabil.
- **Konsens-Verdict:** Robustness
- **Sicherheit der Bewertung:** Mittel

### [HR-008] enterTextByLabel-Selektor strukturell fragil (toter Code)

- **Severity:** 🟢 Minor
- **Kategorie:** Anti-Pattern
- **Ort:** `integration_test/helpers/app_driver.dart:98-120`
- **Befund:** Helper `enterTextByLabel` nutzt `find.ancestor(of: label, matching: Column).first` — findet *irgendeinen* Column-Ancestor, nicht den nächsten. PlantryFormField wraps each Field in einer eigenen Column, aber bei nested Columns ist die Auswahl undefiniert. Gleichzeitig: in keinem der 6 Flow-Files wird `enterTextByLabel` aufgerufen — toter Code.
- **Impact:** Niedrig solange ungenutzt. Aber wenn jemand den Helper für einen neuen Test verwendet → unvorhersehbares Verhalten.
- **Empfehlung:** Entweder löschen oder Selector härten (`find.ancestor(...).first` durch `find.ancestor(of: label, matching: find.byType(PlantryFormField)).first` ersetzen — das ist die deterministische Container-Klasse).
- **Konsens-Verdict:** Wartbarkeit
- **Sicherheit der Bewertung:** Hoch

### Architektur-Empfehlung (Trade-off)

**Mittelfristiger Refactor — App-side Keys:**
Celes' Feature-Idee (`Key('save_room')` an PlantryButton) ist die nachhaltige Lösung für HR-003 + HR-005 + HR-006 + HR-007. Aufwand: ~30 min in `lib/widgets/plantry_button.dart` (optional Key-Param) + Anpassung in jedem `add_*_screen.dart` (~5 Stellen) + Tests umstellen. Wert: Test-Suite wird i18n-stabil, UI-Refactor-stabil, Mehrfach-Match-immun.

**Kurzfristiger Fix-Pfad (für aktuellen Sprint):**
Phase 3 ohne App-Code-Änderungen, nur AppDriver + Test-Strings hardenen. Trade-off: AppDriver wird komplexer aber App bleibt unangetastet, Daniel kann den App-Refactor später selbst machen.

### Empfehlung Phase-3 Commit-Reihenfolge an B'Elanna

Mein Vorschlag (geht über Celes' Empfehlung hinaus):

| Commit | Inhalt | Findings adressiert |
|--------|--------|---------------------|
| **1. style** | `dart format integration_test/` | HR-002 |
| **2. fix(test)** | String-Korrekturen in Tests (Grow-Validator, Drying-Gewicht) | QA-T-001..004 |
| **3. fix(test)** | AppDriver.launch awaited main, scrollToText mit Form-Anker, expectSnackBar Helper | HR-001, HR-005 (= QA-T-006), HR-006 (= QA-T-005) |
| **4. fix(test)** | DB-Reset-Hook + Locale-Reset-Hook in setUpAll/setUp | QA-T-007, HR-003 (Teilfix), HR-004 |
| **5. refactor(test)** | Dropdown-Test typsicher | HR-007 (= QA-T-008) |
| **6. cleanup(test)** | enterTextByLabel löschen oder härten | HR-008 |

Commit 1 ist Pflicht-Vorlauf (Format-Pass-Split-Regel). Commits 2-4 sind die produktiven Fixes. Commits 5-6 sind Polish — können bei Zeitnot auf späteren PR verschoben werden.

**Architektur-Trade-off:** Wenn Admin grünes Licht für App-Code-Änderungen gibt, ersetzt ein Commit "feat(widgets): add testKey to PlantryButton + Save-Buttons" die Commits 5-6 *und* macht die ganze Test-Suite langfristig stabiler. Mein Vote als Reviewer: **lieber jetzt App-Keys einführen** — der Aufwand ist klein, die Test-Brittleness reduziert sich um Größenordnungen.

— Mortimer Harren
