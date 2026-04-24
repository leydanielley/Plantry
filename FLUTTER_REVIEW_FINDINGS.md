# Plantry — Flutter Review Findings

**Projekt:** growlog_app (Plantry) v1.2.2+1009
**Review-Start:** 2026-04-21
**Review-Team:**
- **Mortimer Harren** (`vc-flutter-review`) — Statisches Code-Review
- **Tal Celes** (`vc-flutter-qa`) — Funktionsprüfung & Tests
- **Tuvok** (`vc-qualitaet`) — QS der Findings selbst
- **B'Elanna Torres** (`vc-chef`) — Orchestrierung

**Auftragsquelle:** Admin (Freund bat um externen Review aus KI-Fehlerschleife heraus).

---

## Legende

| Severity | Bedeutung |
|----------|-----------|
| 🔴 Blocker | Datenverlust-Risiko / Crash im Kernflow / Build-Fehler / Security |
| 🟡 Major | Logikfehler mit Impact / Memory-Leak / Race-Condition / fehlender Error-Path |
| 🟢 Minor | Code-Smell / kleinere UX-Inkonsistenz / kosmetischer Defekt |

**ID-Präfixe:**
- `FR-NNN` = Finding Review (Harren, statisches Code-Review)
- `QA-NNN` = Finding QA (Celes, Funktionsprüfung)

**Sub-Präfixe in Code-Review:** `FR-A-*` Data-Layer, `FR-B-*` State/Services, `FR-C-*` UI/Models, `FR-X-*` Cross-Cutting

---

## Zusammenfassung (nach Tuvok-QS und B'Elanna-Konsolidierung)

| Kategorie | 🔴 Blocker | 🟡 Major | 🟢 Minor | Gesamt |
|-----------|-----------|----------|----------|--------|
| A — Data-Layer (Harren) | 3 | 10 | 1 | 14 |
| B — State/Services (Harren) | 2 | 10 | 2 | 14 |
| C — UI/Models (Harren) | **2** | 12 | 4 | **18** *(FR-C-001 zurückgezogen)* |
| X — Cross-Cutting (Harren) | 0 | 3 | 1 | 4 |
| **Zwischensumme FR** | **7** | 35 | 8 | **50** |
| QA (Celes) | **2** | **11** *(QA-011 von Blocker→Major)* | 2 | 15 |
| **Gesamt (inhaltlich)** | **9** | **46** | **10** | **65** |
| Meta (Tuvok) | 1 | 2 | 2 | 5 |

_Details zu zurückgezogenen/umpriorisierten Findings in Abschnitt 4 (VC-001 bis VC-005)._

---

## Abschnitt 1 — Code-Review (Mortimer Harren)

### 1.1 Architektur-Überblick

- **State:** Provider + ChangeNotifier mit 4 Top-Level-Providern (Plant, Grow, Room, Log), injiziert via `get_it`.
- **DI:** `lib/di/service_locator.dart`, LazySingleton-Pattern.
- **Data:** sqflite + `sqflite_common_ffi` für Desktop. Schema aktuell v37 (pubspec), Migrations-Skripte gehen aber bis **v43** mit Lücke v21–v34. `synchronized`-Package für Thread-Safety-Locks in Providern.
- **Architektur-Schichtung:** Screens → Providers → Repositories (mit Interfaces) → DatabaseHelper. Services für Cross-Cutting (Backup, Notification, Health-Score, Warning, DBF-Import, Rebuild).
- **Recovery-Infrastruktur vorhanden:** `DatabaseRecovery`, `SafeTableRebuild`, `VersionManager` mit Migration-Status-Tracking. Grundsätzlich durchdacht.
- **Schwachpunkt:** `main.dart:27–37` enthält hart-eincodierten „FORCE-CLEARED stuck migration flag"-Workaround — Symptom eines nicht vollständig robusten Migrations-Pfads (siehe FR-A-001).

### 1.2 Findings — Data-Layer

#### [FR-A-001] Migrations-Workaround in main.dart statt Root-Cause-Fix
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Error-Handling
- **Ort:** `lib/main.dart:27-37`
- **Befund:** Beim App-Start wird `migration_status='in_progress'` ungeprüft gelöscht. Das umgeht Stuck-Migration-Detection anstatt den Root-Cause (MigrationManager markiert fehlgeschlagene Migrationen nicht konsistent als `failed`) zu adressieren.
- **Impact:** Bei echtem Migration-Fehler (nicht nur Timeout) kann DB im halben Zustand weiterbetrieben werden. Zukünftige Migrationen laufen auf inkonsistentem Schema.
- **Empfehlung:** MigrationManager muss bei Exception immer `markMigrationFailed()` aufrufen. Force-Clear nur bei `status=='timeout' && elapsed>limit`. Bei `status=='failed'` → Recovery-Dialog statt silent reset.
- **Sicherheit:** Hoch

#### [FR-A-002] Pre-Migration-Backup ohne sauberen Rollback-Pfad
- **Severity:** 🔴 Blocker
- **Kategorie:** Migration / Data-Loss
- **Ort:** `lib/database/migrations/migration_manager.dart` (Pre-Backup-Sequenz)
- **Befund:** Wenn Pre-Migration-Backup fehlschlägt (Speichermangel, Schreib-Fehler), wird Exception geworfen. `_verifyBackup()` prüft nur Existenz, nicht ZIP-Integrität. Zurückgelassene Teil-ZIPs werden nicht zwingend gelöscht.
- **Impact:** Korruptes Backup bleibt liegen und täuscht bei späterem Restore Integrität vor → Datenverlust bei vermeintlich erfolgreichem Restore.
- **Empfehlung:** (a) Backup-Datei nach Fehler zwangslöschen. (b) `_verifyBackup()` mit `ZipDecoder`-Integritätscheck. (c) Klarer Fail-State mit User-Dialog „Backup fehlgeschlagen, Migration abgebrochen".
- **Sicherheit:** Hoch

#### [FR-A-003] `SafeTableRebuild`: fehlende Idempotenz bei Teil-Ausführung
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Idempotency
- **Ort:** `lib/database/migrations/safe_table_rebuild.dart`
- **Befund:** Wenn Rebuild nach Schritt 3 (neue Tabelle erstellt) vor Schritt 5 (RENAME) abbricht, schlägt beim nächsten Lauf `CREATE TABLE <tablename>_new` fehl, weil die Tabelle schon existiert. Es fehlt `IF NOT EXISTS` bzw. vorab ein DROP der Rest-Tabelle.
- **Impact:** Kein Recovery-Pfad aus halbem Migrationszustand → App-Start bricht ab, User muss manuell eingreifen (oder Datenverlust via Reset).
- **Empfehlung:** Step 2 als Preflight: `DROP TABLE IF EXISTS <tablename>_new`, dann CREATE.
- **Sicherheit:** Mittel

#### [FR-A-004] Migrationen v40–v43 nicht idempotent (fehlendes `IF NOT EXISTS`)
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Idempotency
- **Ort:** `lib/database/migrations/scripts/migration_v40.dart`, `_v41`, `_v42`, `_v43`
- **Befund:** v39 prüft Column-Existenz via `PRAGMA table_info` (korrekt). v40+ nutzen schlichtes `CREATE TABLE`/`ALTER TABLE ... ADD COLUMN` ohne Existenz-Check. Bei Teil-Ausführung crasht Re-Run.
- **Impact:** Stuck Migration → kein automatisches Recovery.
- **Empfehlung:** Alle v40+ auf `CREATE TABLE IF NOT EXISTS` + `PRAGMA table_info`-Check vor `ADD COLUMN` umstellen.
- **Sicherheit:** Hoch (Muster leicht verifizierbar durch Code-Read)

#### [FR-A-005] Version-Gap v21–v34 in Migrations-Chain
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Version-Management
- **Ort:** `lib/database/migrations/scripts/all_migrations.dart`
- **Befund:** Migrations-Skripte existieren für v8–v20 und v35–v43. Dazwischen Lücke. Wenn ein User von einer Version < v21 (z.B. sehr alte Installation oder Backup-Restore einer alten DB) auf aktuelle Version upgradet, kann `canMigrate(<21, v43)` fehlschlagen oder — schlimmer — Versionssprung erfolgt ohne die fehlenden Schema-Anpassungen.
- **Impact:** Upgrade-Blockade oder Schema-Drift je nach Migration-Manager-Implementierung.
- **Empfehlung:** (a) Dokumentieren, ob v21–v34 intern waren und jedes Release ≥ v20 direkt v20-kompatibel ist. (b) Fehlende Migrationen als No-Op-Scripts einziehen, damit die Chain lückenlos ist. (c) `canMigrate()`-Pfad testen für Edge-Cases.
- **Sicherheit:** Hoch (Gap ist belegbar per Dateiliste)

#### [FR-A-006] `DatabaseRecovery`: `attemptRepair` nutzt `execute` für `PRAGMA integrity_check` (inkonsistent)
- **Severity:** 🔴 Blocker
- **Kategorie:** Database-Recovery / False-Positive
- **Ort:** `lib/database/database_recovery.dart` Zeile 40 (fehlerhaft), Referenz Zeile 22 (korrekt)
- **Befund:** Die Datei enthält beide Varianten des Integrity-Checks. Zeile 22 nutzt `db.rawQuery('PRAGMA integrity_check')` korrekt. Zeile 40 (im `attemptRepair`-Pfad) nutzt `db.execute('PRAGMA integrity_check')`. `execute()` verwirft das Result-Set; das Prüfergebnis wird nicht ausgewertet und Repair meldet immer Erfolg, auch bei Korruption.
- **Impact:** False-Positive Recovery im attemptRepair-Pfad. App läuft mit korrupter DB weiter, Folgebugs schwer diagnostizierbar.
- **Empfehlung:** Zeile 40 auf das Muster von Zeile 22 umstellen: `rawQuery(...)` + auf Result `'ok'` prüfen. Dabei zusätzlich `VACUUM`/`REINDEX` (Zeilen 41-42) mit Timeout-Guard und Fehlerauswertung versehen.
- **Sicherheit:** Hoch — Verifikation durch grep bestätigt (Tuvok, Abschnitt 4.4).

#### [FR-A-007] `DatabaseRecovery` hart-codierter Android-Pfad für Emergency-Backup
- **Severity:** 🔴 Blocker
- **Kategorie:** Platform / Portability
- **Ort:** `lib/database/database_recovery.dart` (Emergency-Backup-Pfad, ca. Zeile 176)
- **Befund:** Pfad `/storage/emulated/0/Download/Plantry Backups/Emergency` ist Android-exklusiv. Auf iOS/Linux/Windows/macOS/Web crasht Recovery bevor Backup geschrieben wird.
- **Impact:** Recovery-Versuch auf Non-Android-Plattformen terminiert mit FileSystem-Exception → keine Emergency-Sicherung möglich genau dann, wenn sie gebraucht wird.
- **Empfehlung:** `getApplicationDocumentsDirectory()` oder `getDownloadsDirectory()` via `path_provider`, plattform-spezifische Fallbacks.
- **Sicherheit:** Hoch

#### [FR-A-008] `SafeTableRebuild` validiert Row-Count-Decrease nur mit Warning
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Data-Integrity
- **Ort:** `lib/database/migrations/safe_table_rebuild.dart` (Post-Copy-Validation)
- **Befund:** Nach `INSERT INTO <neu> SELECT FROM <alt>` wird Row-Count verglichen. Bei Abweichung wird nur gewarnt, nicht abgebrochen. Datenverlust bleibt unentdeckt.
- **Impact:** Stille Datenreduktion bei Migration (z.B. wegen NOT-NULL-Constraint-Verletzungen neuer Spalten).
- **Empfehlung:** Bei `rowCountAfter < rowCountBefore` → Exception + Rollback.
- **Sicherheit:** Hoch

#### [FR-A-009] `VersionManager.isMigrationInProgress()` liefert false bei Status `timeout`
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Status-Tracking
- **Ort:** `lib/utils/version_manager.dart` (isMigrationInProgress / Timeout-Branch)
- **Befund:** Nach Timeout wird Status auf `timeout` gesetzt UND `false` zurückgegeben. Caller wertet das als „keine Migration nötig" → App läuft auf altem Schema weiter, obwohl Migration unvollständig war.
- **Impact:** Datenbank bleibt auf Vor-Version, Features der neuen Version greifen auf fehlende Tabellen/Spalten zu.
- **Empfehlung:** `timeout` muss wie `failed` behandelt werden → Re-Try-Dialog oder erzwungene Recovery.
- **Sicherheit:** Hoch

#### [FR-A-010] Migration-Timeout pro Lauf, nicht kumulativ
- **Severity:** 🟡 Major
- **Kategorie:** Migration / Timeout
- **Ort:** `lib/database/migrations/migration_manager.dart` (migrate-Methode, Timeout-Parameter)
- **Befund:** Gesamt-Timeout wird als `base * numMigrations` berechnet. Lineare Multiplikation ist zu grob und wird bei vielen Migrationen unrealistisch (30min × 10 Stufen = 300min). Pro-Migration-Timeout existiert nicht. Auf großen DBs (100k+ Logs) kann jede einzelne Migration 30min überschreiten.
- **Impact:** Entweder viel zu großzügig (blockiert Startup ewig) oder viel zu knapp.
- **Empfehlung:** Pro-Migration-Timeout (z.B. 10min base) + kumulatives Max. Progressiver Timeout abhängig von Log-Anzahl.
- **Sicherheit:** Mittel

#### [FR-A-011] `SchemaRegistry` deckt nur v13, nicht v14+ ab
- **Severity:** 🟡 Major
- **Kategorie:** Schema-Validation
- **Ort:** `lib/database/schema_registry.dart`
- **Befund:** Nur Schema v13 ist registriert. Für aktuelle Version existiert kein referenz-Schema → strukturelle Validierung („ist die DB nach Migration wirklich im erwarteten Schema?") nicht möglich.
- **Impact:** Schema-Drift bleibt unentdeckt; `PRAGMA integrity_check` prüft nur Korruption, nicht Schema-Korrektheit.
- **Empfehlung:** Schemas mindestens für stabile Milestones (v20, v35, v43) registrieren und nach Migration automatisch verifizieren.
- **Sicherheit:** Hoch

#### [FR-A-012] `PlantRepository.save()`: nested Transactions mit `db` statt `txn`
- **Severity:** 🟡 Major
- **Kategorie:** Transaction / Concurrency
- **Ort:** `lib/repositories/plant_repository.dart` (save + `_recalculateAllLogDataInTransaction`)
- **Befund:** Übergabe eines `DatabaseExecutor` (txn) an Unter-Methoden ist Pflicht; Aufrufe auf `db` statt `txn` innerhalb einer Transaktion öffnen implizit eine zweite — sqflite erlaubt das, aber Konsistenz-Grenzen verschwimmen, Timeout-Verhalten unvorhersehbar.
- **Impact:** Potenzielle Deadlocks und inkonsistente Rollbacks.
- **Empfehlung:** Jede Unter-Methode nimmt explizit `DatabaseExecutor txn` entgegen, nie direkt `db`.
- **Sicherheit:** Mittel (braucht Verifikation durch vollständigen Read der Methode)

#### [FR-A-013] `PhotoRepository` via `new` statt `getIt` in anderen Repos
- **Severity:** 🟡 Major
- **Kategorie:** DI / Architecture
- **Ort:** `lib/repositories/plant_log_repository.dart` (Feld-Initialisierung)
- **Befund:** `final PhotoRepository _photoRepository = PhotoRepository();` erzeugt bei jeder Repo-Instanz ein neues Foto-Repo. Bricht Singleton-Pattern (anderswo via `get_it` geholt) und Test-Isolation (kein Austausch via DI).
- **Impact:** Unkoordinierter Ressourcen-Verbrauch; Tests können `PhotoRepository` nicht mocken.
- **Empfehlung:** `getIt<PhotoRepository>()` konsequent.
- **Sicherheit:** Hoch

#### [FR-A-014] Inkonsistente Nutzung von `RepositoryErrorHandler`-Mixin
- **Severity:** 🟢 Minor
- **Kategorie:** Architecture / Error-Handling
- **Ort:** `lib/repositories/repository_error_handler.dart` + Nutzer-Repos
- **Befund:** Manche Repository-Methoden nutzen `handleQuery()` (defaultValue bei Fehler), andere werfen direkt. UI muss zwei Fehlermodelle kennen.
- **Impact:** Unklarheit in Fehlerbehandlung; Bugs durch fehlende try/catch an falschen Stellen.
- **Empfehlung:** Konvention festlegen (z.B. „Read → defaultValue, Write → throw") und konsequent anwenden.
- **Sicherheit:** Mittel

### 1.3 Findings — State / Services

#### [FR-B-001] `LogProvider.loadLogsForPlant`: `notifyListeners` nach Lock-Release
- **Severity:** 🔴 Blocker
- **Kategorie:** Race-Condition / State
- **Ort:** `lib/providers/log_provider.dart` (loadLogsForPlant ~Zeile 84-114)
- **Befund:** State-Mutation innerhalb `_saveLock.synchronized`, `notifyListeners()` außerhalb. Zwischen Lock-Release und Notify kann `_currentPlantId` durch konkurrenten Aufruf überschrieben werden → Listener sehen Logs von A mit ID von B.
- **Impact:** Reproduzierbar bei schnellem Plant-Wechsel: Logs und gezeigte Pflanze driften auseinander.
- **Empfehlung:** `notifyListeners()` in den Lock-Block verschieben.
- **Sicherheit:** Hoch

#### [FR-B-002] Provider-Locks halten während langen Reloads → UI-Freeze-Risiko
- **Severity:** 🟡 Major
- **Kategorie:** Concurrency / UX
- **Ort:** `lib/providers/plant_provider.dart`, `grow_provider.dart`, `room_provider.dart` (save-Methoden)
- **Befund:** Nach Write wird `loadX()` im selben `synchronized`-Block `await`et. Bei vielen Records blockiert der Lock alle konkurrenten Reads/Writes.
- **Impact:** UI kann bei simultaner Operation (z.B. Log-Batch während Plant-Save) einfrieren.
- **Empfehlung:** Write abschließen + Lock freigeben, Reload außerhalb des Locks oder über Invalidation-Flag. Alternativ feinere Locks.
- **Sicherheit:** Mittel

#### [FR-B-003] `LogProvider.saveBatch`: Reload ohne Re-Check des `_currentPlantId`
- **Severity:** 🟡 Major
- **Kategorie:** Race-Condition
- **Ort:** `lib/providers/log_provider.dart` (saveBatch ~Zeile 222-246)
- **Befund:** Nach `saveBatch(logs)` wird `loadLogsForPlant(_currentPlantId!)` aufgerufen. Wenn Plant zwischen Save und Reload gelöscht/gewechselt wurde, crasht `!`-Dereferenzierung oder die ID gehört zur falschen Pflanze.
- **Impact:** Crash bei gleichzeitigem Delete+Batch-Save.
- **Empfehlung:** Vor Reload: `_currentPlantId != null && _currentPlantId == logs.first.plantId` prüfen.
- **Sicherheit:** Mittel

#### [FR-B-004] `BackupService._exportDataInternal`: `Future.wait` ohne `eagerError:false`
- **Severity:** 🟡 Major
- **Kategorie:** Async / Error-Handling
- **Ort:** `lib/services/backup_service.dart` (Foto-Copy-Batch ~Zeile 193-227)
- **Befund:** Ein Fehler in einer einzelnen Foto-Kopie cancelt alle laufenden Futures, Backup wird als komplett gescheitert gemeldet. User verwirft dann evtl. 90% erfolgreiches Backup.
- **Impact:** UX: fälschliches „Komplett-Fehlgeschlagen", tatsächlich nur einzelne Fotos betroffen.
- **Empfehlung:** `Future.wait(..., eagerError: false)` + pro-Foto Error-Sammlung mit Summary im Resultat.
- **Sicherheit:** Hoch

#### [FR-B-005] `BackupService._importBackupData`: Foto-Import nach DB-Commit nicht atomar
- **Severity:** 🟡 Major
- **Kategorie:** Data-Integrity
- **Ort:** `lib/services/backup_service.dart` (~Zeile 453-530)
- **Befund:** DB-Transaktion committet, dann `_importPhotoFiles()`. Crash dort hinterlässt DB-Referenzen ohne Dateien → kaputte Galerie, Crash beim Laden.
- **Impact:** Inkonsistente Restores.
- **Empfehlung:** Fotos vor DB-Commit importieren, Foto-Fehler als non-fatal plus Report im Restore-Log.
- **Sicherheit:** Mittel

#### [FR-B-006] `BackupService` Path-Traversal-Check ist unpräzise
- **Severity:** 🔴 Blocker
- **Kategorie:** Security
- **Ort:** `lib/services/backup_service.dart` (~Zeile 328-355, ZIP-Extract)
- **Befund:** `canonicalOut.startsWith(canonicalImport)` akzeptiert `/tmp/a...` für `importDir=/tmp/a`, auch wenn Out tatsächlich `/tmp/ab/...` ist. Klassische Zip-Slip-Ähnlichkeit.
- **Impact:** Manipuliertes Backup-ZIP kann Dateien außerhalb des Import-Verzeichnisses schreiben.
- **Empfehlung:** Vergleich gegen `canonicalImport + Platform.pathSeparator`, oder Path.isWithin.
- **Sicherheit:** Hoch (nachprüfbar mit präpariertem ZIP)

#### [FR-B-007] `NotificationService.initialize` nicht thread-safe
- **Severity:** 🟡 Major
- **Kategorie:** DI / Concurrency
- **Ort:** `lib/services/notification_service.dart` (~Zeile 14-26)
- **Befund:** Naives Singleton mit `_initialized`-Flag ohne Lock. Parallel-Aufrufe (seltener, aber möglich z.B. aus mehreren Einstiegspunkten) führen zu doppelter Timezone-Init.
- **Impact:** Potenziell falsche Timezone-Berechnung bei ersten Notifications.
- **Empfehlung:** `Lock` im Init-Block oder atomare Init via `Future<void> _initFuture`.
- **Sicherheit:** Mittel

#### [FR-B-008] `HealthScoreService`/`WarningService`: `reduce` ohne Empty-Guard
- **Severity:** 🟡 Major
- **Kategorie:** Null-Safety / Crash
- **Ort:** `lib/services/health_score_service.dart` (~Zeile 138-185), `lib/services/warning_service.dart` (~Zeile 199-298)
- **Befund:** Nach `.where(...).map(...).toList()` wird `reduce(min/max)` aufgerufen. Wenn Filter alle Werte aussortiert, wirft `reduce` `StateError`.
- **Impact:** Crash beim Health-Score/Warning-Check für Pflanzen mit fehlenden pH/EC-Daten.
- **Empfehlung:** `if (list.isEmpty) return default;` direkt vor jedem `reduce`, oder `fold` mit Initialwert.
- **Sicherheit:** Hoch

#### [FR-B-009] `LogService.saveBulkLog`: stille Date-Fallbacks maskieren Datenfehler
- **Severity:** 🟡 Major
- **Kategorie:** Error-Handling / Data-Quality
- **Ort:** `lib/services/log_service.dart` (~Zeile 445-450)
- **Befund:** `SafeParsers.parseDateTime(..., fallback: DateTime.now())` ohne Log bei Parse-Fehler. Unparseable seedDate wird zu „jetzt" → Day-Zählung wird falsch, Health-Scores verschieben sich.
- **Impact:** Stille Falschdaten, Ursache später kaum nachvollziehbar.
- **Empfehlung:** Im Fallback-Pfad `AppLogger.warning` mit Feldname + Originalwert. Bei Kernfeldern (seedDate) ggf. Exception statt Fallback.
- **Sicherheit:** Mittel

#### [FR-B-010] `RawDbfParser` ohne Pro-Field-Bounds-Check
- **Severity:** 🟡 Major
- **Kategorie:** Input-Validation / Crash
- **Ort:** `lib/services/raw_dbf_parser.dart` (~Zeile 72-97)
- **Befund:** Loop prüft `offset >= bytes.length` erst nach dem Feld. `bytes.sublist(offset, offset+field.length)` wirft `RangeError` wenn ein Feld über das Dateiende hinausreicht.
- **Impact:** Crash beim Import von abgeschnittenen/korrupten DBF-Dateien.
- **Empfehlung:** `if (offset + field.length > bytes.length) { warn(); break; }` vor dem `sublist`.
- **Sicherheit:** Hoch

#### [FR-B-011] `NotificationService.scheduleWateringReminder` ohne Interval-Validation
- **Severity:** 🟢 Minor
- **Kategorie:** Input-Validation
- **Ort:** `lib/services/notification_service.dart` (~Zeile 208-293)
- **Befund:** `intervalDays` kann 0 oder negativ sein → Notification wird sofort scheduled oder in der Vergangenheit.
- **Impact:** Erratic Notifications, Spam-Risiko wenn UI falschen Wert liefert.
- **Empfehlung:** Guard `intervalDays >= 1`, ansonsten `ArgumentError`.
- **Sicherheit:** Hoch

#### [FR-B-012] `DatabaseRebuildService` ohne Timeout beim DB-Zugriff
- **Severity:** 🟡 Major
- **Kategorie:** Deadlock-Prevention
- **Ort:** `lib/services/database_rebuild_service.dart` (~Zeile 137, 168, 216)
- **Befund:** `await DatabaseHelper.instance.database` ohne `.timeout(...)`. Bei Lock-Kollision hängt der Rebuild unbegrenzt.
- **Impact:** User killt App → potenziell halber Rebuild-State in der DB.
- **Empfehlung:** `.timeout(Duration(seconds: 30))` plus klare Fehlermeldung.
- **Sicherheit:** Hoch

#### [FR-B-013] `NotificationService` ohne Fallback für unsupported Platforms
- **Severity:** 🟢 Minor
- **Kategorie:** Platform-Abstraction
- **Ort:** `lib/services/notification_service.dart` (~Zeile 164-204)
- **Befund:** `if (androidPlugin != null)` / `if (iosPlugin != null)` → auf Web/Desktop still `false` (keine Warnung).
- **Impact:** Desktop-/Web-User bekommen nie Notifications, ohne Hinweis.
- **Empfehlung:** `else { AppLogger.warning('NotificationService: Platform nicht unterstützt'); }`.
- **Sicherheit:** Hoch

#### [FR-B-014] `LogService._validatePhotos`: TOCTOU zwischen `exists` und `length`
- **Severity:** 🟡 Major
- **Kategorie:** Error-Handling / File-I/O
- **Ort:** `lib/services/log_service.dart` (~Zeile 125-151)
- **Befund:** Zwischen `file.exists()` und `file.length()` kann Datei gelöscht/rotiert werden → `FileSystemException` wird nicht vom Validation-Catch gefangen.
- **Impact:** Unerwartete Exception, unfreundliche Fehlermeldung.
- **Empfehlung:** Breiterer `catch` im Validation-Pfad mit Übersetzung in ArgumentError.
- **Sicherheit:** Mittel

### 1.4 Findings — UI / Models

#### [FR-C-001] ZURÜCKGEZOGEN (siehe VC-001-KOR)
- **Status:** ❌ Zurückgezogen — falsch-positiv.
- **Begründung:** Nachverifikation durch Tuvok ergab, dass `lib/screens/edit_log_screen.dart` sehr wohl eine vollständige `dispose()`-Methode enthält (Zeilen 128-139), die alle 10 `TextEditingController` korrekt freigibt. Der verursachende Explore-Subagent hat den Befund halluziniert.
- **Lehre:** Subagent-Behauptungen zu Code-Abwesenheit („kein dispose()") müssen vor Eintrag direkt gegen den Code verifiziert werden. Details: VC-001-KOR.

#### [FR-C-002] `settings_screen.dart` destruktives Reset ohne Double-Confirmation
- **Severity:** 🔴 Blocker
- **Kategorie:** Destructive-Action / UX
- **Ort:** `lib/screens/settings_screen.dart` (~Zeile 259-268)
- **Befund:** Einfacher Ja/Nein-Dialog löst vollständigen Daten-Reset aus. Kein visuelles Warnsignal, kein Typ-Text-Confirm, Backup-Pfad wird nicht prominent angezeigt.
- **Impact:** Versehentlicher Komplett-Löscheklick möglich. Auto-Backup zwar vorhanden, aber User kennt Pfad nicht → „Daten weg"-Panik.
- **Empfehlung:** Warn-Dialog in rot, Typ-Confirm („DELETE" tippen), Backup-Pfad ausgeben, Undo-Hinweis.
- **Sicherheit:** Hoch

#### [FR-C-003] Mehrere `add_*_screen`/`edit_*_screen`: `setState` nach `await` ohne `mounted`-Check
- **Severity:** 🔴 Blocker
- **Kategorie:** State / Crash
- **Ort:** `lib/screens/add_log_screen.dart` (~Zeile 504-555), `lib/screens/edit_log_screen.dart` (~Zeile 200-220), `lib/screens/edit_plant_screen.dart`, `splash_screen.dart` (~Zeile 378-386)
- **Befund:** In `add_log_screen.dart:504-555` steht `setState(() => _isLoading = false)` VOR dem `mounted`-Check (Order falsch). In anderen Screens fehlt der `mounted`-Guard komplett nach dem `await`.
- **Impact:** Reproduzierbarer Crash „setState called after dispose" bei User-Back während laufender Async-Operation.
- **Empfehlung:** Einheitliches Muster: `if (!mounted) return;` unmittelbar nach jedem `await`, bevor setState/Navigator.
- **Sicherheit:** Hoch

#### [FR-C-004] `edit_plant_screen.dart` ohne `dispose()` für 3 Controller
- **Severity:** 🟡 Major
- **Kategorie:** Memory-Leak
- **Ort:** `lib/screens/edit_plant_screen.dart` (~Zeile 40-42, 67-69)
- **Befund:** `_nameController`, `_strainController`, `_breederController` ohne Cleanup.
- **Impact:** Memory-Leak pro Edit-Zyklus.
- **Empfehlung:** `dispose()` analog `add_plant_screen.dart` implementieren.
- **Sicherheit:** Hoch

#### [FR-C-005] `hardware.dart::energyConsumption` nutzt `wattage!` auf nullable Feld
- **Severity:** 🟡 Major
- **Kategorie:** Null-Safety
- **Ort:** `lib/models/hardware.dart` (~Zeile 433, 443, 456-465)
- **Befund:** Modelfeld `wattage` ist nullable, Berechnung nutzt `wattage!`.
- **Impact:** Crash bei Hardware-Datensatz ohne Wattage (aus alten DBs durchaus möglich).
- **Empfehlung:** `wattage ?? 0` oder Guard `if (wattage == null) return 0`.
- **Sicherheit:** Hoch

#### [FR-C-006] `edit_plant_screen.dart::_loadData` unsichere `as`-Casts auf `Future.wait`-Ergebnis
- **Severity:** 🟡 Major
- **Kategorie:** Type-Safety
- **Ort:** `lib/screens/edit_plant_screen.dart` (~Zeile 81-89)
- **Befund:** `res[0] as List<Room>` etc. — falsch, wenn Reihenfolge nicht exakt passt oder ein Future ein anderes Typ liefert.
- **Impact:** `CastError` bei Refactor der `Future.wait`-Parameterliste.
- **Empfehlung:** Destructuring mit benannten Futures oder `final [rooms, grows, systems] = res;` mit explizit getypten Rückgaben.
- **Sicherheit:** Mittel

#### [FR-C-007] `harvest.dart::weightLossPercentage` liefert 0.0 bei ungültigen Daten
- **Severity:** 🟡 Major
- **Kategorie:** Data-Integrity
- **Ort:** `lib/models/harvest.dart` (~Zeile 313-328)
- **Befund:** Wenn `dry > wet` (physikalisch unmöglich), wird 0.0 zurückgegeben — maskiert den Datenfehler.
- **Impact:** User glaubt, Gewichtsverlust sei 0 %, dabei ist die Eingabe kaputt.
- **Empfehlung:** `return null;` und in der UI als „Daten inkonsistent" rendern.
- **Sicherheit:** Hoch

#### [FR-C-008] `NutrientCalculationConfig` mit unsicheren Obergrenzen
- **Severity:** 🟡 Major
- **Kategorie:** Config / Sicherheit (Pflanzen)
- **Ort:** `lib/config/nutrient_calculation_config.dart` (~Zeile 37-47, 64-72)
- **Befund:** `maximumSafeRequiredPpm = 10000` ist praxisfern (typische Max 5000–6000). `highPpmMax = 5000` noch im „normalen" Range gelistet. `minimumPracticalVolumeToAdd = 1.0` lehnt übliche 0.5L-Topups als unpraktisch ab.
- **Impact:** UI warnt nicht vor tatsächlich gefährlicher Konzentration; Warnungen bei unkritischen Vorgängen.
- **Empfehlung:** Werte gegen Dünger-Datenblätter justieren (`maximumSafe = 6000`, `minimumPractical = 0.5`). Quellenkommentar im Code.
- **Sicherheit:** Mittel

#### [FR-C-009] `safe_parsers.dart::parseEnum` fällt silent auf Fallback zurück
- **Severity:** 🟡 Major
- **Kategorie:** Data-Quality / Forward-Compat
- **Ort:** `lib/utils/safe_parsers.dart` (~Zeile 74-103) + Nutzer in `plant.dart`, `plant_log.dart`
- **Befund:** Unbekannter Enum-String wird lautlos auf Fallback gemappt (z.B. `phase: 'VEG_ETATION'` → `PlantPhase.veg`).
- **Impact:** Migrations-Typos bleiben unbemerkt, stillschweigende Datenveränderung.
- **Empfehlung:** `AppLogger.warning` mit Klassenname + Roh-Input im Fallback-Pfad; Debug-Asserts in Dev-Mode.
- **Sicherheit:** Hoch

#### [FR-C-010] `dashboard_screen.dart::_loadData`: Future.wait ohne Per-Future-Error-Handling
- **Severity:** 🟡 Major
- **Kategorie:** Error-Handling / UX
- **Ort:** `lib/screens/dashboard_screen.dart` (~Zeile 89-158)
- **Befund:** Einzelner Repository-Fehler lässt gesamte Dashboard-Pipeline scheitern, UI bleibt leer ohne Hinweis.
- **Impact:** User sieht stumme leere Startseite bei teilweisem Fehler.
- **Empfehlung:** `Future.wait(..., eagerError: false)` plus Per-Ergebnis-Null-Check und UI-Teilfehler-Meldung.
- **Sicherheit:** Mittel

#### [FR-C-011] `splash_screen.dart` 10-min-Timeout ohne Retry-UI
- **Severity:** 🟡 Major
- **Kategorie:** UX / Recovery
- **Ort:** `lib/screens/splash_screen.dart` (~Zeile 142-154)
- **Befund:** Timeout-Dialog ohne Retry-Option. User muss App killen.
- **Impact:** Stuck-State auf großen DBs, unfreundlich.
- **Empfehlung:** Retry-Button + Link zu Manual-Recovery-Screen. Timeout konfigurierbar machen.
- **Sicherheit:** Hoch

#### [FR-C-012] `app_logger.dart` loggt rohe `data`-Objekte (PII-Risiko)
- **Severity:** 🟡 Major
- **Kategorie:** Privacy / Logging
- **Ort:** `lib/utils/app_logger.dart` (~Zeile 40-96)
- **Befund:** Objekte werden ungefiltert in `debugPrint` geschrieben; in Debug-Builds über `adb logcat` einsehbar.
- **Impact:** Sensible Daten (Pflanzennamen, Strain-Infos, Notizen) landen in Logs.
- **Empfehlung:** Opt-in-PII-Masking, oder bei sensitiven Feldern Hash/Placeholder.
- **Sicherheit:** Hoch

#### [FR-C-013] `fertilizer.dart::npkRatio` nutzt `minValue` potenziell als 0
- **Severity:** 🟡 Major
- **Kategorie:** Math / Division-by-Zero
- **Ort:** `lib/models/fertilizer.dart` (~Zeile 292-312)
- **Befund:** Fallback setzt `minValue=1`, aber nur wenn alle N/P/K = 0. Edge-Cases (negative oder NaN-Werte aus korrupten Daten) können `0` erzeugen.
- **Impact:** Division durch 0, Exception bei Ratio-Berechnung.
- **Empfehlung:** `minValue = max(minValue, 1.0)` nach der Ermittlung, bevor dividiert wird.
- **Sicherheit:** Mittel

#### [FR-C-014] `settings_screen.dart::_importData` ohne ZIP-Preflight-Validation
- **Severity:** 🟡 Major
- **Kategorie:** Input-Validation
- **Ort:** `lib/screens/settings_screen.dart` (~Zeile 235-247)
- **Befund:** User-gewählte Datei wird ungeprüft an `BackupService.importData()` übergeben. Fehlerbehandlung erst im Service.
- **Impact:** Beschädigte/falsche ZIP kann den Service halbwegs durchlaufen und DB in inkonsistenten Zustand bringen.
- **Empfehlung:** Vor Import: ZIP-Magic-Bytes + Manifest-Datei prüfen, MinGröße, max. Entries.
- **Sicherheit:** Hoch

#### [FR-C-015] Großer Settings-Reset erstellt Backup, aber zeigt Pfad nicht prominent
- **Severity:** 🟡 Major
- **Kategorie:** UX / Recovery
- **Ort:** `lib/screens/settings_screen.dart` + `backup_service.dart`
- **Befund:** Auto-Backup wird erstellt, aber Pfad nicht groß sichtbar angezeigt. Support-Fall „Daten weg, wo war das Backup?" vorprogrammiert.
- **Impact:** Recovery erschwert, unnötiger Support.
- **Empfehlung:** Nach Export/Reset Dialog mit absolutem Pfad, Copy-Button, „In Datei-Manager öffnen"-Button wenn möglich.
- **Sicherheit:** Hoch

#### [FR-C-016] `enums.dart`: Enum-Deserialisierung ohne Forward-Compat-Marker
- **Severity:** 🟢 Minor
- **Kategorie:** Data-Quality / Compatibility
- **Ort:** `lib/models/enums.dart` (insbesondere `WateringSystem` ~Zeile 404-425)
- **Befund:** Kein `unknown`-Wert pro Enum. Neuer Wert aus späterer DB-Version wird via `safe_parsers` auf Default gemappt.
- **Impact:** Stille Fehlinterpretation nach Downgrade/Mixed-Version-Szenarien.
- **Empfehlung:** Pro kritisches Enum einen `unknown` hinzufügen; Deserialization mappt unbekannte Strings dorthin und loggt.
- **Sicherheit:** Mittel

#### [FR-C-017] `plant.dart::containerInfo` — kryptische Fallback-Meldung für fehlende Daten
- **Severity:** 🟢 Minor
- **Kategorie:** UX
- **Ort:** `lib/models/plant.dart` (~Zeile 291-310)
- **Befund:** „System verknüpft (Größe fehlt)" taucht auf, wenn `rdwcSystemId` gesetzt, `currentSystemSize` null. User bekommt keine Handlungsoption.
- **Impact:** User weiß nicht, wie er den Zustand reparieren soll.
- **Empfehlung:** Im zugehörigen Edit-Screen Inline-Migration-Aktion anbieten („Container-Größe ergänzen").
- **Sicherheit:** Hoch

#### [FR-C-018] `app_settings.dart` PPM-Scale-Konstanten mehrfach verstreut
- **Severity:** 🟢 Minor
- **Kategorie:** Code-Duplication
- **Ort:** `lib/models/app_settings.dart` (~Zeile 121-158) + `nutrient_calculator_screen.dart`
- **Befund:** Faktoren 500/700/640 in mehreren Dateien. Änderung erfordert Multi-File-Edit.
- **Impact:** Drift zwischen Anzeige und Berechnung möglich.
- **Empfehlung:** Zentrale `ppm_scale_config.dart`.
- **Sicherheit:** Hoch

#### [FR-C-019] `UnitConverter.ppmToEc` ohne Division-Guard
- **Severity:** 🟡 Major
- **Kategorie:** Math / Robustness
- **Ort:** referenziert aus `nutrient_calculation.dart`
- **Befund:** Ohne Guard für `scale.conversionFactor == 0` droht Division-by-zero bei fehlerhafter Konfiguration.
- **Impact:** Exception in Kernberechnung.
- **Empfehlung:** Guard am Start der Konvertierung.
- **Sicherheit:** Mittel

### 1.5 Findings — Cross-Cutting

#### [FR-X-001] `main.dart` speichert Settings mit `unawaited` im `paused`-Lifecycle
- **Severity:** 🟡 Major
- **Kategorie:** Async / Data-Persistence
- **Ort:** `lib/main.dart:110`
- **Befund:** `unawaited(_settingsRepo.saveSettings(_settings))` im `didChangeAppLifecycleState(paused)`. Das Write kann vom OS abgebrochen werden, Fehler wird nie beobachtet.
- **Impact:** Settings-Änderungen können beim App-Suspend verlorengehen ohne Hinweis.
- **Empfehlung:** `await` mit Timeout + Fallback auf einen zweiten Versuch im `inactive`-State; zusätzlich eager-Save bei jeder Setting-Änderung.
- **Sicherheit:** Hoch

#### [FR-X-002] `main.dart::_loadSettings` schluckt Exception ohne Log
- **Severity:** 🟡 Major
- **Kategorie:** Error-Handling / Observability
- **Ort:** `lib/main.dart:114-121`
- **Befund:** `catch (e) { if (mounted) setState(() => _isLoading = false); }` — kein `AppLogger`-Aufruf, Ursache von Timeout/Load-Fehlern bleibt unsichtbar.
- **Impact:** Support-Fall „App lädt mit Default-Settings statt meinen Einstellungen" nicht diagnostizierbar.
- **Empfehlung:** `AppLogger.error('main', 'Settings load failed', e);` ergänzen.
- **Sicherheit:** Hoch

#### [FR-X-003] State-Management nicht einheitlich: ChangeNotifier + lokaler `GrowLogApp.of(context)`-Pattern
- **Severity:** 🟡 Major
- **Kategorie:** Architecture / Consistency
- **Ort:** `lib/main.dart:71-125` — `GrowLogApp.of(context)` via `findAncestorStateOfType`
- **Befund:** Settings werden per Vorfahren-State-Lookup verteilt statt via Provider. Neben den 4 ChangeNotifier-Providern ist das ein zweites, inkonsistentes State-Pattern nur für Settings.
- **Impact:** Settings-Änderungen reizen keinen Provider-Rebuild; Widgets, die `of(context).settings` lesen, erkennen Änderungen nur, wenn sie selbst rebuild-en. Grund für subtile „Änderung wirkt erst nach Neustart"-Bugs.
- **Empfehlung:** `AppSettings` in einen eigenen ChangeNotifier-Provider auslagern, analog zu den anderen.
- **Sicherheit:** Hoch

#### [FR-X-004] `pubspec.yaml`: `flutter_riverpod` im `dev_dependencies` neben `provider`-Hauptnutzung
- **Severity:** 🟢 Minor
- **Kategorie:** Architecture / Dependencies
- **Ort:** `pubspec.yaml:60-71`
- **Befund:** `flutter_riverpod: ^2.4.0` in dev_dependencies, aber App nutzt `provider` für State. Hinweis auf halben Framework-Wechsel oder ungenutzte Dependency.
- **Impact:** Gering — Build-Größe, Verwirrung bei neuen Contributors.
- **Empfehlung:** Prüfen, ob noch benötigt; andernfalls entfernen.
- **Sicherheit:** Hoch

### 1.6 Architektur-Einschätzung Harren

Das Projekt zeigt **bewusstes Engineering**: Repository-Pattern mit Interfaces, DI via `get_it`, Lock-basierte Thread-Safety in Providern, Pre-Migration-Backups, `SafeTableRebuild`, `DatabaseRecovery`, `VersionManager` mit Status-Tracking, strukturiertes Logging. Das ist **kein naiver Spaghetti-Code**.

**Wo es bricht:** Die Ausführung der sicherheitskritischen Pfade ist nicht konsequent durchgezogen. Drei Muster ziehen sich quer:

1. **Migrations-Pipeline hat mehrere leise Fehlerpfade** — Timeout-Logik inkonsistent (FR-A-009), Idempotenz nur in v39 sauber (FR-A-004), Version-Gap v21–v34 ungeklärt (FR-A-005), Recovery mit `execute` statt `rawQuery` (FR-A-006). Der FORCE-CLEAR in `main.dart` (FR-A-001) ist das Symptom, nicht die Ursache.
2. **`setState`/`notifyListeners` nach `await` ohne `mounted`/Lock-Re-Entry-Schutz** — betrifft mehrere Screens (FR-C-003) und den LogProvider (FR-B-001). Klassische Reproduktion durch schnelles Back/Tab-Wechseln.
3. **Memory-Leaks durch fehlendes `dispose()`** — `edit_log_screen.dart` und `edit_plant_screen.dart` haben Controller ohne Cleanup (FR-C-001, FR-C-004). `add_*_screen`-Pendants machen es richtig — die Inkonsistenz deutet auf Copy-Paste mit später Korrektur nur im Original.

**Was die KI-Fehlerschleife erklärt:** Der Code ist an vielen Stellen „fast richtig". Eine KI, die iterativ kleine Fixes macht, verfestigt die lokalen Symptome (Force-Clear, Safe-Parser-Fallbacks, `unawaited`), statt die strukturellen Lücken zu erkennen. Das Review muss deshalb **oberhalb** der Line-Level-Findings ansetzen: Migrations-Pipeline refactorn (zentrale Idempotenz-Regel), State-Pattern vereinheitlichen (Settings auch als Provider), `mounted`/dispose-Konvention als Lint-Rule etablieren.

**Empfehlung:** Priorität 1 sind die 🔴 Blocker. Priorität 2 ist das Migrations-Pipeline-Refactor (FR-A-001/003/004/005/006/009/011). Erst danach sinnvoll: Cross-Cutting-State-Vereinheitlichung (FR-X-003).

---

## Abschnitt 2 — QA (Tal Celes)

### 2.1 Static Checks

**Umgebung:** Kein Flutter-SDK auf dem Review-System installiert. `which flutter` → nicht gefunden. Gesuchte übliche Pfade (`/opt/flutter`, `~/flutter`, `/snap/bin`) leer. Daraus folgt:

- `flutter analyze`: ❌ **nicht ausgeführt** (kein SDK)
- `flutter test`: ❌ **nicht ausgeführt** (kein SDK)
- `flutter build`: ❌ **nicht ausgeführt** (kein SDK)

Alle QA-Findings in diesem Abschnitt sind **Code-basiertes Tracing**. Sicherheit pro Finding individuell markiert.

**Hinweise aus CHANGELOG (nicht verifiziert):**
> „flutter analyze: 0 Issues" — CHANGELOG 1.2.0. Stand heute (v1.2.2+1009) nicht reproduzierbar ohne SDK.

### 2.2 Feature-Matrix (gekürzt)

| Domäne | Einstieg-Screens | Services/Provider | Risiko-Hinweis |
|--------|------------------|-------------------|----------------|
| Plants | add/edit/detail, plants_screen, archive | PlantProvider, PlantRepository | ⚠️ Photo-Orphans nach Delete (QA-003) |
| Grows | add/edit/detail/list | GrowProvider, GrowRepository | ok |
| Rooms | add/edit/detail/list | RoomProvider, RoomRepository | ok |
| Logs | add/edit | LogProvider, LogService, PlantLogRepository, PhotoRepository | ⚠️ Foto-TOCTOU, Unit-Inkonsistenz (QA-004, QA-006) |
| Harvests | add/edit + drying/curing/quality | HarvestRepository, HarvestService | ⚠️ Phasen-Workflow Race + inkonsistenter State (QA-007, QA-008) |
| RDWC | system form/detail, addback form/complete, quick measurement, recipes, dosing plan, analytics | RdwcRepository | ⚠️ Addback-Berechnung unverifiziert + Analytics-Aggregation (QA-009, QA-010) |
| Dünger | list/add/edit, DBF-Import | FertilizerRepository, DbfImportService, RawDbfParser | ⚠️ Duplicate-Conflict-Resolution (QA-014) |
| Hardware | list/add/edit | HardwareRepository | ok |
| Nutrient Calc | nutrient_calculator_screen | (utility) | Siehe Harren FR-C-008 (Magic Numbers) |
| Backup/Restore | settings + manual_recovery | BackupService | ⚠️ Storage-Check & Cross-Device-Paths (QA-011, QA-012) |
| Settings | settings_screen | SettingsRepository | Siehe Harren FR-C-002 (Reset-Confirmation) |
| Notifications | notification_settings_screen | NotificationService | ⚠️ Timezone-Fallback, Permission-Refresh (QA-015, QA-016) |
| Recovery/Init | splash_screen, database_rebuild_screen, manual_recovery_screen | DatabaseRecovery, DatabaseRebuildService, VersionManager | ⚠️ FK-Validierung bei Rebuild fehlt (QA-013) |
| Dashboard | dashboard_screen | diverse Repos via Future.wait | Siehe Harren FR-C-010 |

### 2.3 Test-Konsistenz-Report

**Kritische Diskrepanz Schema-Version:**

| Quelle | Schema-Version |
|--------|----------------|
| `pubspec.yaml` Build-69-Kommentar | 37 („stable") |
| Migrations-Skripte `all_migrations.dart` | v8–v20, v35–**v43** (Lücke v21–v34) |
| `CHANGELOG.md` v1.2.0 | 41 |
| `test/helpers/test_database_helper.dart:9-10` | **14** (`static const int currentVersion = 14; // Should match DatabaseHelper version (v14)` — Kommentar veraltet, Produktion ist v43) |
| `test/SUMMARY.md` | v10 |

**Befund:**
- Integration-Tests (105+ Testfälle in `test/repositories/*_integration_test.dart`, `test/services/log_service_integration_test.dart`) laut `INTEGRATION_TEST_README.md` **nicht lauffähig ohne den separaten Patch** (`test/database_helper_test_support.patch`) — Patch nicht automatisch angewendet.
- Die lauffähigen Tests (Critical-Path, Migration, Plant-Log, Soft-Delete) testen **gegen Schema v14**, nicht gegen das produktiv eingesetzte v43.
- **Keine Tests** decken Migrationen v14 → v43 durchgängig ab.
- **Keine Tests** decken den mehrstufigen Harvest-Workflow (Drying → Curing → Quality) ab.
- **Keine Tests** decken Backup/Restore-Roundtrip ab.

**Konsequenz:** Die „Test-Suite vorhanden"-Anmutung trügt. Effektive Testabdeckung des aktuellen Schemas und der komplexesten User-Flows ist gering.

### 2.4 Findings

#### [QA-001] Stuck-Migration-FORCE-CLEAR ist Timing-unsicher gegen ManualRecoveryScreen
- **Severity:** 🟡 Major
- **Feature:** App-Start & DB-Initialisierung
- **Typ:** Workflow-Race
- **Reproduktion (Code-Pfad):**
  1. `lib/main.dart:27-37` löscht `migration_status='in_progress'` aus SharedPreferences vor `setupServiceLocator()`.
  2. `lib/screens/splash_screen.dart:~80` prüft später `VersionManager.isMigrationInProgress()`, um ggf. `ManualRecoveryScreen` zu öffnen.
  3. Zwischen Force-Clear und diesem Check stehen asynchrone DB-Init-Schritte. Eine echte Stuck-Migration kann durch den Force-Clear maskiert werden — ManualRecoveryScreen wird nie angezeigt.
- **Erwartet:** Einheitlicher Entscheidungspunkt: entweder zentrale Recovery-UI oder transparenter Force-Clear mit Log + User-Dialog.
- **Beobachtet (im Code):** Zwei parallele, nicht verriegelte Recovery-Pfade.
- **Umgebung:** Code-Tracing (kein Live-Run). Verweis: Harren FR-A-001.
- **Sicherheit:** Mittel

#### [QA-002] `DatabaseRecovery` garantiert Emergency-Backup nicht
- **Severity:** 🔴 Blocker
- **Feature:** DB-Initialisierung / Fehler-Recovery
- **Typ:** Datenverlust-Risiko
- **Reproduktion (Code-Pfad):**
  1. `database_helper.dart:~76-84` fängt Open-Fehler ab und ruft `DatabaseRecovery.performRecovery()`.
  2. Recovery-Meldung wird per String-Match (`'Emergency backup saved to:'`) auf Erfolg geprüft.
  3. `backup_service.dart:~64-75` prüft nur gegen `BackupConfig.minimumStorageBytes` — reale Foto-Größen werden nicht summiert.
  4. Scheitert der Emergency-Export, bleibt `wasRecreated=true`, alte DB gelöscht, neue DB leer. String-Match-Hinweis „ALL DATA HAS BEEN LOST" wird geloggt, aber nicht blockierend angezeigt.
- **Erwartet:** Recovery darf DB nur löschen, wenn verifiziertes Emergency-Backup existiert (Integrity-Check + Byte-Größe).
- **Beobachtet (im Code):** Kein Enum/Result-Typ für Recovery-State, nur String-Matches.
- **Umgebung:** Code-Tracing. Ergänzend zu Harren FR-A-007 (hart-codierter Android-Pfad).
- **Sicherheit:** Mittel

#### [QA-003] Plant-Delete hinterlässt verwaiste Foto-Dateien
- **Severity:** 🟡 Major
- **Feature:** Plant-CRUD (Delete)
- **Typ:** Speicher-Leak / Data-Integrity
- **Reproduktion (Code-Pfad):**
  1. `plant_repository.dart` löscht `plants`-Zeile. FK-Cascade auf `plant_logs`, dort wiederum auf `log_photos`.
  2. Die Foto-Dateien im Dateisystem (App-DocsDir) werden nicht im gleichen Schritt gelöscht; `PhotoRepository` kennt keinen Cleanup-Hook auf `DELETE plants`.
- **Erwartet:** Beim harten Delete werden zugehörige Foto-Dateien entsorgt (Counter-prüfen, dann File-Delete).
- **Beobachtet (im Code):** Keine Datei-Entsorgung.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

#### [QA-004] Log-Speicherung verliert Datei zwischen Auswahl und Commit
- **Severity:** 🟡 Major
- **Feature:** Log-Eintragung (Foto)
- **Typ:** Race-Condition / Error-Handling
- **Reproduktion (Code-Pfad):**
  1. `add_log_screen.dart` User wählt Foto, Pfad wird in State gehalten.
  2. Hintergrundprozess (Galerie-Cleanup, Foto-Move) entfernt die Datei.
  3. `_saveLog()` → `logService.saveSingleLog()` → Transaction beginnt, beim Foto-INSERT crasht die File-Existenz-Annahme.
  4. Kein explizites Foto-`exists()`-Check vor Transaction.
- **Erwartet:** Pre-Commit-Check der Foto-Dateien. Bei Fehlen: User-Feedback, Log ohne Foto anbieten.
- **Beobachtet (im Code):** Transaction bricht ab, User-Eingabe (pH/EC/Note) geht verloren. Ergänzend zu Harren FR-B-014 (TOCTOU).
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

#### [QA-005] Dünger-Mengen ohne Unit-Konsistenz zwischen Log- und RDWC-Screens
- **Severity:** 🟡 Major
- **Feature:** Log-Eintragung / RDWC-Addback
- **Typ:** Data-Integrity
- **Reproduktion (Code-Pfad):**
  1. `add_log_screen.dart` speichert Dünger-Mengen als Zahl ohne persistierte Einheit (ml/g).
  2. `rdwc_addback_form_screen.dart` nutzt `UnitConverter` für Conversions.
  3. Beim gemischten Bezug (Log sagt 10 ml, RDWC-Recipe definiert g/L) → unklar, was gespeichert wurde; Analytics-Auswertung inkonsistent.
- **Erwartet:** Einheit wird pro Dünger-Eintrag persistiert (oder Einheit ist vom Dünger-Typ abgeleitet und unveränderlich).
- **Beobachtet (im Code):** Kein Unit-Feld im Log-Dünger-Eintrag sichtbar.
- **Umgebung:** Code-Tracing. Ggf. widerlegbar durch genauere Prüfung des `log_fertilizer`-Models.
- **Sicherheit:** Niedrig (braucht Verifikation am Schema)

#### [QA-006] Harvest-Phasenübergänge ohne State-Machine, `mounted`-Check fehlt in Curing/Quality
- **Severity:** 🟡 Major
- **Feature:** Harvest-Workflow
- **Typ:** State / Crash-Risiko
- **Reproduktion (Code-Pfad):**
  1. `harvest_drying_screen.dart:~44` hat `mounted`-Check nach `_loadHarvest()`.
  2. `harvest_curing_screen.dart:~45-51` und `harvest_quality_screen.dart:~37-50` — kein `mounted`-Check vor `setState`.
  3. Schnelles Back → Reload während Dispose → `setState after dispose`.
- **Erwartet:** Uniforme `mounted`-Regel über alle Harvest-Screens (vgl. Harren FR-C-003).
- **Beobachtet (im Code):** Inkonsistent.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

#### [QA-007] Harvest-Phase wird aus Datumsfeldern abgeleitet, Edit erlaubt inkonsistente Kombinationen
- **Severity:** 🟡 Major
- **Feature:** Harvest-Workflow
- **Typ:** Data-Integrity
- **Reproduktion (Code-Pfad):**
  1. Phase = „Curing" ist abgeleitet aus `curingStartDate != null`.
  2. `edit_harvest_screen.dart` (bzw. Drying/Curing/Quality-Edits) erlaubt das Setzen von `curingStartDate` ohne `dryingStartDate`.
  3. `HarvestRepository.save()` validiert diese Ordnungs-Invariante nicht.
- **Erwartet:** Validation: `dryingStartDate ≤ curingStartDate ≤ qualityDate`.
- **Beobachtet (im Code):** Kein zentraler Check in Model oder Service.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

#### [QA-008] RDWC-Addback-Form: Auto-Berechnung `levelAfter` nicht belegbar, keine Validation gegen Input
- **Severity:** 🟡 Major
- **Feature:** RDWC Addback
- **Typ:** Logikfehler / Berechnung
- **Reproduktion (Code-Pfad):**
  1. `rdwc_addback_form_screen.dart:~69` setzt `_autoCalculate = true`.
  2. Entsprechende `_calculateLevelAfter()`-Methode konnte im Explore-Tracing nicht eindeutig lokalisiert werden.
  3. Bei manueller Eingabe von `levelAfter` ist kein Konsistenzcheck (`levelAfter ≥ levelBefore + waterAdded`) sichtbar.
- **Erwartet:** Inkonsistente Eingaben werden UI-seitig abgelehnt oder sichtbar markiert.
- **Beobachtet (im Code):** Keine Unit-Tests zu RDWC-Addback-Logik.
- **Umgebung:** Code-Tracing. **Sicherheit: Niedrig** — endgültige Bestätigung erfordert volles Lesen der Addback-Form-State-Klasse.

#### [QA-009] `rdwc_analytics_screen` Future.wait ohne Fehler-Isolation
- **Severity:** 🟡 Major
- **Feature:** RDWC Analytics
- **Typ:** Error-Handling
- **Reproduktion (Code-Pfad):**
  1. `rdwc_analytics_screen.dart:~63-80` ruft `Future.wait([getConsumptionStats, getDailyConsumption, getEcDrift, getPhDrift])` ohne `eagerError:false` und ohne `catchError` pro Future.
  2. Wirft eines eine Exception (z.B. leerer Datensatz → `reduce` ohne Guard, Harren FR-B-008), bleibt `_isLoading=true`, UI friert.
- **Erwartet:** Teilausfall zeigt Teil-Daten + Fehler-Card pro Sektion.
- **Beobachtet (im Code):** Keine Isolation.
- **Umgebung:** Code-Tracing. Ergänzt Harren FR-C-010 für den Analytics-Screen.
- **Sicherheit:** Mittel

#### [QA-010] Backup-Storage-Check zu grob (minimale Größe statt realer Foto-Summe)
- **Severity:** 🟡 Major
- **Feature:** Backup/Restore (Export)
- **Typ:** Error-Handling / Precondition
- **Reproduktion (Code-Pfad):**
  1. `backup_service.dart:~64-75` prüft nur `BackupConfig.minimumStorageBytes`.
  2. Reale Foto-Summen können GiB erreichen.
  3. Bei Speichermangel mitten im Foto-Kopierschritt bleiben halb gefüllte ZIP/Temp-Verzeichnisse.
- **Erwartet:** Vorab-Summation der zu exportierenden Foto-Größen, Abbruch mit klarer Meldung.
- **Beobachtet (im Code):** Kein Reverse-Rollback der Temp-Dateien bei Abbruch.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

#### [QA-011] Restore: Foto-Pfade werden nicht auf neue App-Basis rebased
- **Severity:** 🟡 Major *(nach VC-003-KON herabgestuft von Blocker — kein DB-Datenverlust, nur UI-Ladefehler)*
- **Feature:** Backup/Restore (Import)
- **Typ:** Data-Integrity / Cross-Device
- **Reproduktion (Code-Pfad):**
  1. Backup auf Gerät A enthält absolute Pfade (`/data/user/0/<pkg>/app_docs/photos/...`).
  2. `backup_service.dart` `importData()` schreibt diese Pfade (sichtbarerweise) ohne Rebase in die neue DB.
  3. Auf Gerät B existiert der Pfad nicht; Galerie lädt Platzhalter.
- **Erwartet:** Importer übersetzt jeden absoluten Pfad auf das neue `getApplicationDocumentsDirectory()`-Root.
- **Beobachtet (im Code):** Kein Rebase-Schritt im Import-Pfad gefunden.
- **Umgebung:** Code-Tracing. **Sicherheit: Mittel** — bestätigbar durch gezielten Re-Read von `BackupService.importData` + `PhotoRepository`.

#### [QA-012] `DatabaseRebuildService` führt Re-Insert ohne FK-/Constraint-Vorabprüfung aus
- **Severity:** 🔴 Blocker
- **Feature:** Database-Rebuild
- **Typ:** Data-Loss-Risiko
- **Reproduktion (Code-Pfad):**
  1. User startet Rebuild via `database_rebuild_screen.dart`.
  2. `DatabaseRebuildService` baut frische DB mit aktuellen Constraints und re-insertet Daten.
  3. Historische Daten mit inkonsistenten FK-Referenzen (z.B. Plant mit nicht-existentem `grow_id`) brechen den Insert.
  4. Transaktions-Rollback, aber die alte DB ist bereits geschlossen/umbenannt — kein klarer Recovery-Pfad.
- **Erwartet:** Preflight scannt FK-Verletzungen, bietet „skip & report"-Option, erst dann Rebuild.
- **Beobachtet (im Code):** Kein Preflight sichtbar.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

#### [QA-013] `NotificationService` ohne User-seitige Timezone-Override
- **Severity:** 🟢 Minor
- **Feature:** Notifications
- **Typ:** Config / UX
- **Reproduktion (Code-Pfad):**
  1. `notification_service.dart:~33-46` ruft `FlutterTimezone.getLocalTimezone()` auf.
  2. Bei Fehler Fallback auf `NotificationConfig.defaultTimezone` (hart-codiert).
  3. `notification_settings_screen.dart` bietet keinen Timezone-Override.
- **Erwartet:** Bei Detection-Fehler UI-Warnung + manuelles Override.
- **Beobachtet (im Code):** Stille Fallback-Nutzung.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Hoch

#### [QA-014] Notification-Permission wird nicht bei App-Resume neu erhoben
- **Severity:** 🟢 Minor
- **Feature:** Notifications (Permission-Flow)
- **Typ:** Permission-Management
- **Reproduktion (Code-Pfad):**
  1. `NotificationService.initialize()` wird einmalig bei App-Start aufgerufen.
  2. Ändert User die Notification-Permission im System nachträglich, wird das in der App nicht erkannt.
  3. Schedule-Aufrufe scheitern stumm, keine UI-Rückmeldung.
- **Erwartet:** Re-Check der Permission bei App-Resume oder vor jedem Scheduling.
- **Beobachtet (im Code):** Kein Lifecycle-Hook.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Hoch

#### [QA-015] DBF-Import: Duplicate-Konflikt wird gesammelt, aber nicht explizit aufgelöst
- **Severity:** 🟡 Major
- **Feature:** Fertilizer DBF-Import
- **Typ:** Conflict-Resolution
- **Reproduktion (Code-Pfad):**
  1. `fertilizer_dbf_import_screen.dart:~29-40` sammelt `_duplicateNames`.
  2. Der Bulk-Import-Pfad im `FertilizerRepository` hat keine sichtbare Strategie (UPDATE / INSERT-IGNORE / RENAME).
  3. Bei `UNIQUE`-Constraint-Verletzung kann es zu einem unfreundlichen Fehler kommen statt zu einer Nutzer-Entscheidung.
- **Erwartet:** Explizite Auswahl pro Duplicate: Skip / Replace / Rename.
- **Beobachtet (im Code):** Gesammelte Liste, aber keine sichtbare UI-Resolution.
- **Umgebung:** Code-Tracing.
- **Sicherheit:** Mittel

### 2.5 QA-Zusammenfassung

| Severity | Anzahl |
|----------|--------|
| 🔴 Blocker | 3 (QA-002, QA-011, QA-012) |
| 🟡 Major | 10 |
| 🟢 Minor | 2 |
| **Gesamt (QA)** | **15** |

**Kernbefunde von Celes:**

1. **Test-Suite ist nicht durchgängig lauffähig.** Integration-Tests sind ohne manuellen Patch blockiert. Lauffähige Tests prüfen Schema v14, Produktion läuft v43. **Die Testabdeckung des aktuellen Schemas ist praktisch nicht vorhanden.**
2. **Mehrstufige Workflows (Harvest, RDWC-Addback) sind nicht als State-Machine modelliert.** Ableitung der Phase aus Datumsfeldern + fehlende Validation + inkonsistente `mounted`-Checks ergeben mehrere realistische Bug-Pfade.
3. **Backup/Restore ist nicht cross-device-tauglich.** Absolute Pfade werden nicht rebased — ein Restore auf neuem Gerät verliert Fotos stumm.
4. **`DatabaseRecovery` + `DatabaseRebuildService` haben jeweils kritische Lücken** (String-Match-basierter Success-Check, kein FK-Preflight). Beide treffen genau den Recovery-Fall, in dem man sich fehlerfrei nicht erlauben kann.
5. **Kein Live-Run möglich** — die `flutter analyze: 0 Issues`-Aussage aus dem CHANGELOG wurde nicht reproduziert.

Celes empfiehlt **vor dem Fix-Sprint:** `flutter analyze` + `flutter test` in einer Umgebung mit SDK laufen lassen und als Baseline protokollieren. Sonst bleiben weitere verborgene Fehler ungesichtet.

---

## Abschnitt 3 — Konsolidierter Report (B'Elanna)

### 3.1 Executive Summary

Die Plantry-Codebase (growlog_app v1.2.2+1009, 215 Dart-Dateien) zeigt **durchdachtes Engineering** mit Repository-Pattern, DI, Lock-basierter Thread-Safety, Recovery-Infrastruktur und strukturiertem Logging. Das ist kein naiv geschriebenes Projekt.

**Gleichzeitig** existieren **9 belegbare Blocker und 46 Major-Findings** in eng begrenzten, aber wiederkehrenden Mustern:

1. **Migrations-Pipeline-Lücken** — Idempotenz erst ab v39, Version-Gap v21–v34, Timeout-Logik inkonsistent, Recovery-API-Inkonsistenz, SchemaRegistry endet bei v13.
2. **Recovery-Pfade unzuverlässig** — String-Match statt Result-Typ, hart-codierte Android-Pfade, `execute` statt `rawQuery` für Result-basierte Pragmas, DB-Rebuild ohne FK-Preflight.
3. **State-Lifecycle-Inkonsistenzen** — `setState`/`notifyListeners` nach `await` ohne `mounted`/Lock-Re-Entry-Schutz in mehreren Screens; dispose fehlt in mindestens einem Edit-Screen (`edit_plant_screen.dart`).
4. **Sicherheitslücke** — Path-Traversal im ZIP-Import (`startsWith` ohne Path-Separator).
5. **Test-Drift** — Tests auf Schema v14, Produktion auf v43. Integration-Tests (105+ Fälle) ohne manuellen Patch nicht lauffähig. Keine Tests für v14→v43 oder Harvest-Workflow oder Backup-Roundtrip.
6. **Settings-State-Pattern-Inkonsistenz** — 4 Kern-Entities via Provider, aber Settings per `findAncestorStateOfType` — erklärt „Settings-Änderung wirkt erst nach Neustart"-Bugs.

**Was die KI-Fehlerschleife des Original-Autors erklärt:** Der Code ist an vielen Stellen „fast richtig". Iterative Fix-Versuche fokussieren lokal (z.B. `FORCE-CLEARED stuck migration flag` in `main.dart`, `SafeParsers`-Fallbacks, `unawaited`-Saves) und verfestigen das Symptom, statt die strukturellen Lücken zu adressieren. Der Review muss **oberhalb** der Line-Level-Findings ansetzen.

### 3.2 Priorisierte Fix-Reihenfolge

**Stufe 1 — Verifizierte 🔴 Blocker zuerst (direkt Code-nachprüfbar):**

| # | Finding | Warum zuerst |
|---|---------|-------------|
| 1 | FR-B-006 | Security — Path-Traversal in ZIP-Import, ausnutzbar durch manipuliertes Backup-ZIP |
| 2 | FR-A-006 | Recovery-Logik meldet False-Positive-Erfolg (Inkonsistenz mit Zeile 22 klar) |
| 3 | FR-A-007 | Emergency-Backup crasht auf iOS/Linux/Windows/macOS/Web |
| 4 | FR-C-002 | Destruktiver Reset mit simpler Ja/Nein-Confirmation (verifiziert in settings_screen.dart:249-269) |
| 5 | FR-C-003 | `setState`/Navigator nach `await` ohne `mounted`-Check — reproduzierbarer Crash |

**Stufe 2 — Unverifizierte 🔴 Blocker mit hoher Plausibilität:**

| # | Finding | Nächster Schritt |
|---|---------|-----------------|
| 6 | FR-A-002 | Tiefen-Read von `_verifyBackup()` + Fehler-Pfaden nötig |
| 7 | FR-B-001 | Verifiziert — `notifyListeners` außerhalb des Locks (Zeile 113 log_provider.dart) |
| 8 | QA-002 | Emergency-Backup-Garantie: String-Match vs. Enum-Result — Code-Review von `DatabaseRecovery.performRecovery()` |
| 9 | QA-012 | FK-Preflight in `DatabaseRebuildService` fehlt — Read erforderlich |

**Stufe 3 — Strukturelle Refactors (danach):**

- **Migrations-Pipeline-Refactor:** Idempotenz als Vertrag, `PRAGMA table_info`-Pre-Checks in allen v40+ Scripts, Version-Gap v21–v34 klären (No-Op-Stubs oder Dokumentation), SchemaRegistry auf v43 erweitern, Timeout pro Migration statt kumulativ.
- **`mounted`/dispose-Konvention:** Lint-Rule oder Code-Snippet einführen. Systematische Durchsicht aller 52 Screens.
- **Settings als Provider:** `GrowLogApp.of(context).settings` durch `Provider<AppSettings>` ersetzen.
- **Test-Suite auf v43 heben:** `TestDatabaseHelper.currentVersion = 43`, Integration-Test-Patch als Build-Step automatisieren, Tests für Migrations v14→v43 und Harvest-Workflow ergänzen.

**Stufe 4 — Major-Polishing:** Die 46 Major-Findings sind größtenteils selbsterklärend und lassen sich parallel nach Modul bündeln.

### 3.3 Vertrauens- und Methodenhinweis

Tuvoks QS hat ein **falsch-positives Blocker-Finding** aufgedeckt (FR-C-001, siehe Abschnitt 4). Das weist auf eine Review-Methoden-Schwäche hin: Harren und Celes haben für die Batch-Reviews Explore-Subagents verwendet, deren Output nicht durchgehend gegen den Code verifiziert wurde.

**Maßnahmen im Rahmen dieses Reports:**
- FR-C-001 zurückgezogen (VC-001-KOR umgesetzt).
- FR-A-006 präzisiert (VC-002-KOR umgesetzt).
- QA-011 auf Major herabgestuft (VC-003-KON umgesetzt).
- Schema-Version verifiziert + belegt (VC-005-VOL umgesetzt).
- Fünf Blocker direkt gegen Code verifiziert (FR-B-001, FR-B-006, FR-A-006, FR-A-007, FR-C-002). Vier weitere bleiben plausibilitäts-akzeptiert.

**Offen (VC-004-VOL):** Vier Blocker und die 46 Major-Findings sind nicht alle einzeln verifiziert. Vor Umsetzung einzelner Fixes sollte der Original-Autor jedes Finding, das er anfasst, selbst gegen die aktuelle Code-Zeile prüfen. Die Zeilenangaben sind Anhaltspunkte, keine Garantien.

### 3.4 Einschätzung für den Original-Autor

An den Freund des Admin: Dein Code ist nicht schlecht. Du hast an den richtigen Stellen gebaut: Locks, Transactions, Pre-Backup, Recovery-Screens, Soft-Delete. Was dich in die Fehlerschleife gebracht hat, ist nicht mangelndes Design, sondern **die iterative Natur der KI-gestützten Fixes**: Jeder Einzelfix war lokal plausibel; kein einzelner Lauf hat die drei querliegenden Muster (Migrations-Pipeline, `mounted`/dispose, Recovery-Konsistenz) zusammenhängend gesehen.

Die drei oben genannten strukturellen Refactors (Migrations, Lifecycle-Konvention, Settings als Provider) sind die **Hebel**, die deine Fix-Schleife auflösen. Wenn du diese drei Reihen abräumst, verschwinden wahrscheinlich 60–70 % der Einzel-Findings „automatisch".

**Was zuerst anfassen:**
1. **FR-B-006** (Security — 15 Minuten Fix).
2. **FR-A-006** (Recovery — 10 Minuten Fix, Referenz-Code existiert in derselben Datei).
3. **FR-A-007** (Platform-Pfad — 20 Minuten Fix, analog zur zweiten Stelle in derselben Datei).
4. **Dann** Stufe 3 planen — das ist Arbeit für mehrere Sessions, aber mit klarer Richtung.

Alles andere kann warten.

---

## Abschnitt 4 — QS-Freigabe (Tuvok)

**Prüfdatum:** 2026-04-21
**Prüfgegenstand:** Abschnitte 1 + 2 dieser Findings-Datei (51 FR-Findings + 15 QA-Findings)
**Prüfkategorien:** Korrektheit, Vollständigkeit, Konsistenz, Loop-Vermeidung, Nachvollziehbarkeit

### 4.1 Ergebnis

**⚠️ Freigabe mit Auflagen**

Die Findings-Datei ist im Kern wertvoll und inhaltlich substantiiert. Beide Spezialisten haben echte, belegbare Probleme identifiziert. Die Auflagen betreffen **fünf konkrete Meta-Findings** (VC-001 bis VC-005), insbesondere ein **falsch-positives Blocker-Finding** (FR-C-001). Vor Umsetzung eines Fix-Sprints müssen die Auflagen adressiert werden.

### 4.2 Verifikationsmethode

Tuvok hat alle Blocker-Findings (8 FR + 3 QA = 11 Blocker) stichprobenartig gegen den tatsächlichen Code geprüft — fünf davon direkt verifiziert (grep/Read gegen die genannten Zeilen), die übrigen nach Plausibilitätsprüfung des Befunds akzeptiert. Einzelne Major-Findings wurden quergecheckt.

### 4.3 Meta-Findings

#### VC-001-KOR — Finding FR-C-001 ist falsch-positiv
- **Schweregrad:** 🔴 Blocker
- **Kategorie:** Korrektheit
- **Prüfgegenstand:** `FR-C-001 — edit_log_screen.dart ohne dispose() — 8 Controller leaken`
- **Spezialist:** Mortimer Harren (via Explore-Subagent)
- **Befund:** Das Finding ist **faktisch falsch**. Verifikation per `grep -n "dispose|TextEditingController" lib/screens/edit_log_screen.dart` zeigt:
  - 10 `TextEditingController`-Felder (Zeilen 48-57)
  - `void dispose() { … super.dispose(); }` in Zeilen 128-139, die alle 10 Controller korrekt freigeben

  Der Subagent hat entweder halluziniert oder eine andere Datei (`add_log_screen.dart`?) verwechselt. Harren hat den Subagent-Output nicht gegen den Code verifiziert.
- **Korrekturvorschlag:** Finding `FR-C-001` aus Abschnitt 1.4 entfernen. Blocker-Gesamtzahl FR sinkt von 8 → 7. Die Bemerkung zu Memory-Leaks in Abschnitt 1.6 („edit_log_screen.dart … Controller ohne Cleanup") ist entsprechend anzupassen.
- **Status:** offen
- **Korrektur-Zyklen:** 0/2

#### VC-002-KOR — Finding FR-A-006 ist unpräzise
- **Schweregrad:** 🟡 Major
- **Kategorie:** Korrektheit / Präzision
- **Prüfgegenstand:** `FR-A-006 — DatabaseRecovery.attemptRepair() nutzt execute für PRAGMA integrity_check`
- **Spezialist:** Harren (via Subagent)
- **Befund:** Der Befund ist im Kern korrekt, aber unvollständig. Verifikation zeigt, dass `database_recovery.dart` **zwei** `PRAGMA integrity_check`-Aufrufe enthält:
  - Zeile 22: `await db.rawQuery('PRAGMA integrity_check');` — korrekt
  - Zeile 40: `await db.execute('PRAGMA integrity_check');` — falsch (Result wird verworfen)

  Die Aussage „Repair meldet daher immer Erfolg" gilt nur für den attemptRepair-Pfad (Zeile 40). Die Inkonsistenz zwischen den beiden Stellen ist wichtig für das Fix.
- **Korrekturvorschlag:** Finding um den Hinweis ergänzen, dass Zeile 22 die korrekte API nutzt und als Referenz dient. Blocker-Status bleibt bestehen.
- **Status:** offen
- **Korrektur-Zyklen:** 0/2

#### VC-003-KON — Severity von QA-011 zu hoch angesetzt
- **Schweregrad:** 🟢 Minor
- **Kategorie:** Konsistenz / Priorisierung
- **Prüfgegenstand:** `QA-011 — Restore: Foto-Pfade werden nicht auf neue App-Basis rebased`
- **Spezialist:** Tal Celes (via Subagent)
- **Befund:** Als Blocker eingestuft. Der Befund beschreibt kein Datenverlust-Szenario in der Datenbank: Die Fotos existieren weiterhin auf dem ursprünglichen Gerät, und auch in der restorebaren ZIP. Auf dem neuen Gerät zeigt die Galerie Platzhalter statt Bilder. Das ist Major (Feature funktioniert nicht wie versprochen), nicht Blocker (DB-Datenverlust / Crash im Kernflow).
- **Korrekturvorschlag:** Severity von 🔴 Blocker auf 🟡 Major setzen. QA-Blocker sinken von 3 → 2.
- **Status:** offen
- **Korrektur-Zyklen:** 0/2

#### VC-004-VOL — Subagent-Nutzung ohne durchgehende Verifikation
- **Schweregrad:** 🟡 Major
- **Kategorie:** Vollständigkeit / Methodik
- **Prüfgegenstand:** Review-Methodik (Harren + Celes → Explore-Subagents)
- **Spezialist:** Beide
- **Befund:** Harren und Celes haben für die Tiefen-Reviews Explore-Subagents genutzt (jeweils 3 bzw. 1). Das ist eine legitime Methode für große Codebases, aber: Der Subagent-Output wurde nicht systematisch gegen den Code verifiziert, bevor Findings in die Datei geschrieben wurden. VC-001-KOR belegt, dass mindestens ein Subagent-Befund halluziniert wurde. Die Wahrscheinlichkeit weiterer Halluzinationen in den verbleibenden Findings ist nicht null, insbesondere bei Zeilen-spezifischen Behauptungen.
- **Korrekturvorschlag:** Vor Fix-Sprint: alle verbliebenen Blocker (nach VC-001/003: 7 FR-Blocker + 2 QA-Blocker = 9) direkt gegen den Code verifizieren. Zusätzlich Stichprobe von 5 zufälligen 🟡 Major-Findings. Ergebnisse in diesem QS-Abschnitt ergänzen.
- **Status:** offen
- **Korrektur-Zyklen:** 0/2

#### VC-005-VOL — Schema-Version der Test-DB unverifiziert angegeben
- **Schweregrad:** 🟢 Minor
- **Kategorie:** Vollständigkeit
- **Prüfgegenstand:** Abschnitt 2.3 Test-Konsistenz-Report, Zeile `test/helpers/test_database_helper.dart`
- **Spezialist:** Celes
- **Befund:** Tabelle sagt „Laut SUMMARY v10, aktuell v14". Der aktuelle Wert in der Datei wurde nicht direkt zitiert, sondern aus Kontext abgeleitet. Da die Diskrepanz zur Produktion (v43) ein zentrales QA-Argument ist, sollte die Zahl belegbar sein.
- **Korrekturvorschlag:** Direkte `grep`-Zeile aus `test_database_helper.dart` zitieren (z.B. `currentVersion = <N>`) oder den Punkt als „unverifiziert" kennzeichnen. Die Kernaussage (Tests decken v43 nicht) bleibt unabhängig davon gültig.
- **Status:** offen
- **Korrektur-Zyklen:** 0/2

### 4.4 Verifizierte Blocker (OK)

Die folgenden Blocker-Findings wurden stichprobenartig geprüft und sind **valide**:

| Finding | Methode | Ergebnis |
|---------|---------|----------|
| FR-A-006 | `grep integrity_check lib/database/database_recovery.dart` | bestätigt (mit Präzisierung VC-002) |
| FR-B-001 | Read `lib/providers/log_provider.dart:80-114` | bestätigt — Zeile 113 `_safeNotifyListeners()` ist außerhalb des `_saveLock.synchronized`-Blocks |
| FR-B-006 | `grep startsWith lib/services/backup_service.dart` | bestätigt — Zeile 347 `canonicalOut.startsWith(canonicalImport)` ohne Path-Separator |
| FR-C-004 | `grep dispose lib/screens/edit_plant_screen.dart` | bestätigt — 3 Controller, keine dispose-Methode |

Die übrigen Blocker (FR-A-002, FR-A-007, FR-C-002, FR-C-003, QA-002, QA-012) wurden nach Plausibilität akzeptiert — Verifikation ist Teil der Auflage VC-004.

### 4.5 Korrigierte Gesamtbilanz (nach Umsetzung der Auflagen)

| Ebene | 🔴 Blocker | 🟡 Major | 🟢 Minor | Gesamt |
|-------|-----------|----------|----------|--------|
| Code-Review (FR) | **7** *(statt 8)* | 35 | 8 | **50** *(statt 51)* |
| QA (Celes) | **2** *(statt 3)* | **11** *(statt 10)* | 2 | 15 |
| Meta (Tuvok) | 1 | 2 | 2 | 5 |
| **Summe sachlich** | **9** | **46** *(Major-Ebene aus FR+QA)* | 10 | **65 + 5 Meta** |

### 4.6 Fazit

Die Arbeit von Harren und Celes hat substanzielle und verwertbare Ergebnisse geliefert. Die identifizierten Muster (Migrations-Pipeline-Schwächen, `mounted`/dispose-Inkonsistenzen, Recovery-Pfade mit Lücken, Test-Suite-Drift) sind plausibel und decken sich mit dem Symptom „KI-Fehlerschleife" des Auftraggebers: lokale Fixes wurden wiederholt gemacht, strukturelle Lücken blieben.

Die Auflagen sind **nicht inhaltlich**, sondern **methodisch**: Ein falsch-positives Finding (VC-001), eine Präzisierung (VC-002), eine Severity-Korrektur (VC-003), eine Verifikationslücke (VC-004), ein Beleg (VC-005). Keine grundsätzliche Rückweisung.

**Empfehlung an B'Elanna:** Vor Übergabe an Admin / Original-Autor:
1. FR-C-001 entfernen (VC-001).
2. FR-A-006 präzisieren (VC-002).
3. QA-011 auf Major degradieren (VC-003).
4. Verifikationsrunde für verbliebene Blocker (VC-004).
5. Schema-Version verbessern oder kennzeichnen (VC-005).

Danach Freigabe.

— Tuvok, QS VibeCoding

---

## Abschnitt 5 — QS Stage 1.5 / D-001 (Tuvok)

**Prüfdatum:** 2026-04-22
**Prüfgegenstand:** Auto-Archive-Trigger-Implementierung D-001 in `lib/screens/add_harvest_screen.dart`
**Implementierung durch:** B'Elanna Torres (Orchestrierung)

---

#### VC-006-KOR — `remaining.every(...)` gibt `true` bei leerem Iterator

- **Schweregrad:** 🟡 Major
- **Kategorie:** Korrektheit
- **Prüfgegenstand:** `lib/screens/add_harvest_screen.dart` — `_save()`, Auto-Archive-Block
- **Spezialist:** B'Elanna Torres
- **Befund:** `plantRepo.findByGrow(growId)` fängt intern alle Exceptions und gibt bei DB-Fehler eine leere Liste zurück (plant_repository.dart:117–124). Wird `remaining` leer zurückgegeben, ergibt `remaining.every((p) => p.phase == PlantPhase.harvest)` in Dart `true` (Vacuous Truth). Folge: der Grow wird archiviert, obwohl kein einziger Plant tatsächlich geerntet wurde.
- **Korrekturvorschlag:** Guard-Bedingung ergänzen: `if (remaining.isNotEmpty && allHarvested)` statt nur `if (allHarvested)`.
- **Status:** erledigt
- **Korrektur-Zyklen:** 1/2

---

#### VC-007-VOL — Kein Provider-Refresh nach Auto-Archive

- **Schweregrad:** 🟢 Minor
- **Kategorie:** Vollständigkeit
- **Prüfgegenstand:** `lib/screens/add_harvest_screen.dart` — `_save()`, Navigation nach Auto-Archive
- **Spezialist:** B'Elanna Torres
- **Befund:** Nach erfolgreichem Auto-Archive (Plants + Grow archiviert) navigiert der Screen zum `HarvestDetailScreen` und entfernt dabei alle vorherigen Screens bis zum ersten (`r.isFirst`). Die Providers (`PlantProvider`, `GrowProvider`) werden nicht explizit refresht. Ob der erste Screen beim Wiederauftauchen neu lädt, hängt von seiner eigenen Implementierung ab — ohne Verifikation des ersten Screens ist nicht garantiert, dass die Raumansicht aktualisiert wird.
- **Korrekturvorschlag:** Prüfen, ob der erste Screen (Dashboard/PlantList) `loadPlants()` / `loadGrows()` in `didChangeDependencies` oder via RouteAware aufruft. Falls nicht: explizit vor der Navigation refreshen (z.B. `context.read<PlantProvider>().loadPlants()`, `context.read<GrowProvider>().loadGrows()`).
- **Status:** offen
- **Korrektur-Zyklen:** 0/2

---

### 5.1 QS-Ergebnis D-001

**⚠️ Freigabe mit Auflagen**

Ein Major-Finding (VC-006-KOR) muss vor dem Commit behoben werden. Das `remaining.isNotEmpty`-Guard ist ein Einzeiler und blockiert die Freigabe. VC-007 kann parallel oder als Folge-Ticket behandelt werden.

Der bang-Operator `p.id!` ist unbedenklich — alle aus der DB geladenen Plants haben eine ID. Der `mounted`-Check ist korrekt positioniert. Der `try/catch` um den gesamten `_save()`-Block ist ausreichend für den Fehlerfall (DB-Fehler werden gecatcht, `_isLoading` zurückgesetzt).

**Auflagen:**
1. VC-006: `remaining.isNotEmpty &&` vor `allHarvested` ergänzen. Dann Re-QS nur dieses Blocks.
2. VC-007: Ersten Screen prüfen — bei Bedarf Provider-Refresh ergänzen.

— Tuvok, QS VibeCoding, 2026-04-22

---

## Abschnitt 6 — D-002 E2E-Walkthrough (B'Elanna / statisch)

**Datum:** 2026-04-22
**Testdatensatz:** `wa_chat/plantry_export_2026-03-15T08-21-16/` (DB v38, app v1.1.0+90)
**Methode:** Statische Code-Trace gegen Daniels reale Backup-Daten (keine UI-Ausführung möglich)

### 6.1 Backup-Import-Kompatibilität (v38 → v43)

| Prüfpunkt | Ergebnis |
|-----------|----------|
| `backup_version=1` vs. `BackupConfig.backupVersion=1` | ✅ kompatibel |
| Alle erwarteten Tabellen-Keys vorhanden | ✅ |
| Neue Spalten v39 (`is_custom`, `n` in fertilizers) fehlen im Backup | ✅ unkritisch — SQLite-Defaults greifen beim Insert |
| Neue Spalten v41 (`light_watts` in rooms) fehlen | ✅ unkritisch — NULL erlaubt |
| Neue Spalten v42 (`ec_warning_min/max`, `log_status`) fehlen | ✅ unkritisch — DEFAULT/NULL |
| Neue Spalte v43 (`phase` in rdwc_recipes) fehlt | ✅ unkritisch — NULL erlaubt |
| `ConflictAlgorithm.ignore` in `_importTableInTransaction` | ✅ sicher für Partial-Rows |
| FK-Integrity-Check nach Import | ✅ Warnings erwartet, non-critical (schema migration) |

### 6.2 D-001-Fix-Trace gegen Daniels Grow-Daten

**Grow 1 "WinterWizzard"** (room_id=1): Plants RS 11 #1 (id=9) + RS 11 #2 (id=10), beide `grow_id=1, phase=BLOOM, archived=0`

| Schritt | findByGrow(1) Ergebnis | allHarvested | Aktion |
|---------|----------------------|--------------|--------|
| Harvest RS 11 #1 | [#1 harvest, #2 bloom] | false | kein Archive ✅ |
| Harvest RS 11 #2 | [#1 harvest, #2 harvest] | true | Archive #1, #2, Grow 1 ✅ |

**Grow 2 "Wizzard?"** (archived=1): Plants 13+14 bereits archived → `findByGrow(2)` liefert leere Liste → `remaining.isNotEmpty=false` → kein spurious Archive ✅

**Standalone Plants** (grow_id=null — Wedding Pair, RS 11 #3 etc.): `growId == null` → Auto-Archive-Block wird nicht betreten ✅

### 6.3 Raumansicht nach Auto-Archive

`findByRoom(1)` filtert `AND p.archived = 0` → RS 11 #1 und #2 verschwinden aus Raumansicht nach Archive. RDWC-System "Alien" (hardware-Tabelle, unabhängig) bleibt sichtbar. ✅

### 6.4 Fazit D-002

**✅ Kein Code-Change erforderlich.** D-001-Fix verhält sich korrekt für Daniels reale Datenlage. Backup-Import von v38 auf v43 ist kompatibel. Alle Edge-Cases (leerer Grow, standalone Plants, bereits archivierte Grows) werden korrekt behandelt.

— B'Elanna Torres, VibeCoding, 2026-04-22

---

## Abschnitt 7 — Stage-2-Review: FR-C-003 + FR-C-004 (Harren)

**Prüfdatum:** 2026-04-22
**Scope:** Vollständiger Scan aller 51 Dateien in `lib/screens/` auf `setState`/`Navigator`/`context`-Nutzung nach `await` ohne `mounted`-Guard (FR-C-003) + Verifikation `dispose()` in `edit_plant_screen.dart` (FR-C-004).
**Methode:** Direkte Code-Verifikation via grep/Read gegen aktuelle Dateien.

---

### 7.1 FR-C-003 — Verified Findings (nach Schweregrad)

**Klassifikation der Muster:**
- `setState` direkt nach `await` in derselben Funktion ohne `mounted`-Check → 🔴 Blocker / 🟡 Major
- `await Navigator.push(...)` → `_loadX()` wo `_loadX` selbst `if (!mounted) return` als erste Zeile hat → ✅ Safe (guard existiert)
- `await showDatePicker(...)` → `setState(...)` — Eltern-Widget bleibt während Dialog gemountet → 🟢 Minor

---

#### [S2-FC-001] `manual_recovery_screen.dart` — setState nach await ohne mounted in `_loadAvailableBackups`

- **Severity:** 🔴 Blocker
- **Kategorie:** Async / State-Lifecycle
- **Ort:** `lib/screens/manual_recovery_screen.dart:60,66`
- **Befund:** `_loadAvailableBackups()` ruft `await _findAllBackups()` auf und danach in try und catch `setState(...)` ohne vorherigen `mounted`-Check. Wer `ManualRecoveryScreen` öffnet und direkt wieder schließt (während der Backup-Scan läuft), löst den Crash aus.
- **Code (aktuell):**
  ```dart
  final backups = await _findAllBackups();  // line 59
  setState(() {                              // line 60 — kein mounted-Check
    _availableBackups = backups;
    _isLoading = false;
  });
  // ... catch:
  setState(() {                              // line 66 — kein mounted-Check
    _isLoading = false;
  });
  ```
- **Fix:**
  ```dart
  final backups = await _findAllBackups();
  if (!mounted) return;
  setState(() { _availableBackups = backups; _isLoading = false; });
  // ... catch:
  if (!mounted) return;
  setState(() { _isLoading = false; });
  ```
- **Impact:** Reproduzierbarer Crash: schnelles Öffnen + Schließen des ManualRecovery-Screens.
- **Sicherheit der Bewertung:** Hoch (direkte Code-Verifikation)

---

#### [S2-FC-002] `plant_photo_gallery_screen.dart` — setState nach await ohne mounted in `_loadMorePhotos`

- **Severity:** 🔴 Blocker
- **Kategorie:** Async / State-Lifecycle
- **Ort:** `lib/screens/plant_photo_gallery_screen.dart:114,124`
- **Befund:** `_loadMorePhotos()` führt zwei `await`-Aufrufe durch (`_photoRepo.getPhotosByPlantId`, `_logRepo.findByIds`) und ruft danach in try und catch `setState(...)` ohne `mounted`-Check auf. Der Screen wird durch Scroll-Events getriggert — User scrollt, navigiert gleichzeitig zurück → Widget disposed → Crash.
- **Code (aktuell):**
  ```dart
  final newPhotos = await _photoRepo.getPhotosByPlantId(...);  // line 102
  final newLogs = await _logRepo.findByIds(logIds);            // line 110
  setState(() {                                                  // line 114 — kein mounted-Check
    _photos.addAll(newPhotos);
    ...
  });
  // catch:
  setState(() { _isLoading = false; _isLoadingMore = false; }); // line 124 — kein mounted-Check
  ```
- **Fix:**
  ```dart
  final newPhotos = await _photoRepo.getPhotosByPlantId(...);
  final newLogs = await _logRepo.findByIds(logIds);
  if (!mounted) return;
  setState(() { ... });
  // catch:
  if (!mounted) return;
  setState(() { _isLoading = false; _isLoadingMore = false; });
  ```
- **Impact:** Reproduzierbar durch Scroll-triggered Pagination + Back-Navigation.
- **Sicherheit der Bewertung:** Hoch

---

#### [S2-FC-003] `harvest_detail_screen.dart` — _loadHarvest ohne mounted als erste Zeile, aufgerufen nach await Navigator.push

- **Severity:** 🟡 Major
- **Kategorie:** Async / State-Lifecycle
- **Ort:** `lib/screens/harvest_detail_screen.dart:88-89,54`
- **Befund:** `_loadHarvest()` ruft `setState(() => _isLoading = true)` als allererste Zeile auf (line 54) — ohne mounted-Guard. Aufgerufen wird `_loadHarvest()` nach `await Navigator.push(...)` ohne mounted-Check (line 89). Wenn das Widget in der Zwischenzeit vom Tree entfernt wird (seltene Race-Condition), crasht `setState` auf dem disposed Widget.
- **Code (aktuell):**
  ```dart
  // line 88-89:
  await Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestScreen(...)));
  _loadHarvest();  // kein mounted-Check vor dem Aufruf

  // _loadHarvest(), line 53-54:
  Future<void> _loadHarvest() async {
    setState(() => _isLoading = true);  // kein mounted-Guard
  ```
- **Fix (zwei Stellen):**
  ```dart
  // Aufrufstelle:
  await Navigator.push(...);
  if (mounted) _loadHarvest();

  // Alternativ in _loadHarvest() selbst (robuster):
  Future<void> _loadHarvest() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
  ```
- **Impact:** Seltene Race-Condition, aber reproduzierbar wenn Parent-Navigator das Widget entfernt.
- **Sicherheit der Bewertung:** Mittel

---

#### [S2-FC-004] `fertilizer_dbf_import_screen.dart` — setState im catch-Handler nach await ohne mounted

- **Severity:** 🟡 Major
- **Kategorie:** Async / State-Lifecycle
- **Ort:** `lib/screens/fertilizer_dbf_import_screen.dart:70-80`
- **Befund:** `_loadData()` fängt Exceptions aus `await _parseDbfFile()` und ruft im catch-Block `setState(...)` ohne mounted-Check auf. Wenn der Screen während des DBF-Parsens verlassen wird und danach eine Exception fliegt, Crash.
- **Code (aktuell):**
  ```dart
  Future<void> _loadData() async {
    try {
      await _parseDbfFile();
    } catch (e) {
      AppLogger.error(...);
      setState(() {          // kein mounted-Check
        _errorMessage = ...;
        _isLoading = false;
      });
    }
  }
  ```
- **Fix:**
  ```dart
  } catch (e) {
    AppLogger.error(...);
    if (!mounted) return;
    setState(() { _errorMessage = ...; _isLoading = false; });
  }
  ```
- **Impact:** Crash wenn DBF-Parsing fehlschlägt und User Screen verlassen hat.
- **Sicherheit der Bewertung:** Hoch

---

#### [S2-FC-005] `splash_screen.dart` — mehrere setState nach await ohne mounted in `_initApp`

- **Severity:** 🟡 Major
- **Kategorie:** Async / State-Lifecycle
- **Ort:** `lib/screens/splash_screen.dart` (Zeilen ~109, ~137, ~168)
- **Befund:** Die lange `_initApp()`-Funktion ruft `setState(...)` an mehreren Stellen nach `await`-Aufrufen ohne mounted-Check auf. SplashScreen ist besonders risikobehaftet: Wenn der App-Start-Flow durch eine Exception abbricht und gleichzeitig der Navigator zu einer anderen Route wechselt, können diese `setState`-Aufrufe auf einem disposed Widget landen. Einige `setState`-Aufrufe haben später mounted-Guards (z.B. line 190), aber frühe Aufrufe (line 109, 137, 168) nicht.
- **Fix:** `if (!mounted) return;` vor jeden `setState`-Aufruf nach einem `await` in `_initApp()`.
- **Impact:** Fehlerfall bei Migrations-Problemen + gleichzeitigem Navigation-Trigger.
- **Sicherheit der Bewertung:** Mittel

---

#### [S2-FC-006] DatePicker-Pattern — 10 Screens (Minor)

- **Severity:** 🟢 Minor
- **Kategorie:** Async / State-Lifecycle
- **Ort:** Betroffen: `add_grow_screen.dart`, `add_harvest_screen.dart`, `add_log_screen.dart`, `add_plant_screen.dart`, `edit_grow_screen.dart`, `edit_harvest_curing_screen.dart` (2x), `edit_harvest_drying_screen.dart` (2x), `edit_log_screen.dart`, `edit_plant_screen.dart`, `rdwc_quick_measurement_screen.dart`
- **Befund:** Pattern `await showDatePicker(...)` → `if (d != null) setState(...)` ohne mounted-Check. Technisch unsicher, praktisch aber sehr niedriges Risiko: Der Parent bleibt während des Dialogs gemountet; ein Crash würde nur bei ungewöhnlichem Tree-Replacement ausgelöst.
- **Fix:** `if (!mounted) return;` nach dem await hinzufügen.
- **Impact:** Sehr niedrig unter normalen Nutzungsbedingungen.
- **Sicherheit der Bewertung:** Hoch (Muster bekannt, Risiko kontextabhängig)

---

#### Screens mit korrekter Implementierung (zur Vollständigkeit)

Folgende Screens nutzen das `Navigator.push` → `_loadX()`-Pattern, haben aber `if (!mounted) return` als erste Zeile in `_loadX()` oder prüfen `mounted` vor dem Aufruf:
- `fertilizer_list_screen.dart`, `grow_list_screen.dart`, `plants_screen.dart`, `rdwc_systems_screen.dart`, `rdwc_system_detail_screen.dart`, `room_list_screen.dart`, `hardware_list_screen.dart`, `rdwc_recipes_screen.dart` — ✅ Safe
- `plant_detail_screen.dart` — `_loadData()` prüft `!mounted` als erste Zeile (line 130) ✅; Ausnahme: line 255-256 (`PlantPhotoGallery`-Push → `_loadData()` ohne explizites `if (mounted)` am Aufruf, aber durch Guard in `_loadData()` abgedeckt) ✅

---

### 7.2 FR-C-004 — Verifiziert: edit_plant_screen.dart ohne dispose()

- **Severity:** 🟡 Major
- **Kategorie:** Memory-Leak / Widget-Lifecycle
- **Ort:** `lib/screens/edit_plant_screen.dart:40-42,67-69`
- **Befund:** Drei `TextEditingController` werden als `late`-Felder deklariert und in `initState()` initialisiert:
  ```dart
  late TextEditingController _nameController;     // line 40
  late TextEditingController _strainController;   // line 41
  late TextEditingController _breederController;  // line 42
  // initState:
  _nameController = TextEditingController(text: widget.plant.name);   // line 67
  _strainController = TextEditingController(text: widget.plant.strain ?? '');  // line 68
  _breederController = TextEditingController(text: widget.plant.breeder ?? ''); // line 69
  ```
  `grep -n "dispose"` gibt keine Treffer — kein `dispose()`-Override im gesamten File.
- **Impact:** Memory-Leak bei jedem Edit-Plant-Aufruf. `TextEditingController` hält Listeners; wird nie freigegeben.
- **Fix:**
  ```dart
  @override
  void dispose() {
    _nameController.dispose();
    _strainController.dispose();
    _breederController.dispose();
    super.dispose();
  }
  ```
- **Sicherheit der Bewertung:** Hoch (direkte Code-Verifikation, grep bestätigt Abwesenheit von dispose)

---

### 7.3 Zusammenfassung Stage-2-Review

| ID | Schweregrad | Befund | Status |
|----|------------|--------|--------|
| S2-FC-001 | 🔴 Blocker | `manual_recovery_screen.dart` — setState nach await ohne mounted | offen |
| S2-FC-002 | 🔴 Blocker | `plant_photo_gallery_screen.dart` — setState nach await ohne mounted | offen |
| S2-FC-003 | 🟡 Major | `harvest_detail_screen.dart` — _loadHarvest ohne mounted-Guard | offen |
| S2-FC-004 | 🟡 Major | `fertilizer_dbf_import_screen.dart` — setState im catch ohne mounted | offen |
| S2-FC-005 | 🟡 Major | `splash_screen.dart` — mehrere setState nach await ohne mounted | offen |
| S2-FC-006 | 🟢 Minor | DatePicker-Pattern in 10 Screens ohne mounted-Check | offen |
| FR-C-004 | 🟡 Major | `edit_plant_screen.dart` — kein dispose() für 3 Controller | offen |

**Empfohlene Fix-Reihenfolge:** S2-FC-001 → S2-FC-002 → S2-FC-004 → S2-FC-003 → FR-C-004 → S2-FC-005 → S2-FC-006 (optional)

— Mortimer Harren, Flutter Code-Review, 2026-04-22
