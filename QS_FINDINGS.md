# QS-Findings — Plantry (Branch: review)

Geführt von: Tuvok (vc-qualitaet)
Projekt: Plantry / Flutter

---

## Stage 4 / P0 — 2026-04-24

| ID | Schweregrad | Befund | Spezialist | Status |
|----|------------|--------|------------|--------|
| VC-008-VOL | 🟢 Minor | FR-A-002: Partial-Backup-Cleanup deckt nur den Fall ab, in dem `_createPreMigrationBackup` erfolgreich zurückgibt, bevor `_verifyBackup` wirft. Schlägt die Backup-Erstellung intern fehl (Exception vor Return), ist `backupPath == null` und eine eventuelle Teil-Datei kann nicht gelöscht werden. Erfordert Änderungen in `_createPreMigrationBackup` selbst. | Harren (Fix), B'Elanna (Auftrag) | offen |

---

## Stage 4 / P2 — 2026-04-24

| ID | Schweregrad | Befund | Spezialist | Status |
|----|------------|--------|------------|--------|
| — | — | Keine neuen Findings. Alle Fixes korrekt, beide Falsch-positive bestätigt. | — | — |

### Prüfergebnis P2

| Finding | Bewertung |
|---------|-----------|
| FR-B-004 (`backup_service.dart`) | ✅ Korrekt — `eagerError: false` an beiden `Future.wait`-Aufrufen (Export Zeile 218, Import Zeile 676). |
| FR-B-008 | ✅ Falsch-positiv bestätigt — `warning_service.dart` und `health_score_service.dart` haben `isEmpty`-Guards vor allen `reduce`-Aufrufen. |
| FR-B-009 | ✅ Falsch-positiv bestätigt — `SafeParsers.parseDateTime` loggt via `AppLogger.warning` bei Parse-Fehler. |
| FR-B-010 (`raw_dbf_parser.dart`) | ✅ Korrekt — `truncated`-Flag, Log bei Bounds-Überschreitung, partieller Record wird verworfen. |
| FR-B-012 (`database_rebuild_service.dart`) | ✅ Korrekt — 2min Timeout auf `_runPreFlightChecks()` via `onTimeout`-Callback mit valider `ValidationResult`; 30s Timeout auf `DatabaseHelper.instance.database`. |

---

## Stage 4 / P1 — 2026-04-24

| ID | Schweregrad | Befund | Spezialist | Status |
|----|------------|--------|------------|--------|
| VC-009-VOL | 🟢 Minor | FR-A-013: `PlantLogRepository._photoRepository` wird weiterhin als `PhotoRepository()` (direkt konstruiert) gehalten. Full getIt-Injection wurde zurückgerollt, da Tests die Klasse ohne DI-Setup instanziieren. Korrekte Lösung erfordert Constructor-Injection oder Test-Setup-Refactor — beides außerhalb des P1-Scopes. | Harren (Analyse), B'Elanna (Auftrag) | offen |

### Prüfergebnis P1

| Finding | Bewertung |
|---------|-----------|
| FR-A-012 (`plant_repository.dart`) | ✅ Falsch-positiv bestätigt — `save()` korrekt: `db.insert` (INSERT-Pfad) und `db.update` (Fallback) sind eigenständige Operationen. Alle Ops innerhalb der Transaction nutzen `txn`. |
| FR-A-013 (`i_photo_repository.dart`, `photo_repository.dart`) | ✅ Interface-Erweiterung korrekt — `deleteByLogIdInTransaction` in `IPhotoRepository` ergänzt, `@override` auf Implementierung. getIt-Injection zurückgerollt (vertretbar, Minor VC-009-VOL). |
| FR-A-014 (`fertilizer_set_repository.dart`) | ✅ Korrekt — `RepositoryErrorHandler` mit `repositoryName` getter, alle vier Methoden in `handleQuery`/`handleMutation` gewrappt. Kein Interface für `FertilizerSetRepository` existiert — pre-existing gap, außerhalb Scope. |

---

## Stage 4 / P4–P7 — 2026-04-24

| ID | Schweregrad | Befund | Spezialist | Status |
|----|------------|--------|------------|--------|
| — | — | Keine neuen Findings. Alle Fixes korrekt. QA-011 LIKE-Match akzeptable Näherung. Falsch-positive: FR-C-005, FR-C-009, FR-C-013, FR-C-019, QA-003, QA-009, QA-015. | — | — |

### Prüfergebnis P4–P7

| Finding | Bewertung |
|---------|-----------|
| FR-X-001 (`main.dart`) | ✅ Korrekt — `.catchError` auf `unawaited` settings save, Fehler geloggt. |
| FR-X-002 (`main.dart`) | ✅ Korrekt — `AppLogger.error` im `_loadSettings` catch-Block ergänzt. |
| FR-B-011 (`notification_service.dart`) | ✅ Korrekt — `intervalDays <= 0` Guard in allen drei schedule-Methoden. |
| FR-B-013 (`notification_service.dart`) | ✅ Korrekt — `_isSupportedPlatform`-Check, `_platformSupported`-Flag, early return für Desktop/Web. |
| QA-014 (`notification_settings_screen.dart`) | ✅ Korrekt — `WidgetsBindingObserver`, Permission-Check auf `resumed`. |
| FR-C-005 (`hardware.dart`) | ✅ Falsch-positiv — `totalWattage` hat `null`-Guard vor `wattage!`. `energyConsumption` existiert nicht. |
| FR-C-006 (`edit_plant_screen.dart`) | ✅ Korrekt — `.cast<T>() ?? []` statt unsafe `as`, try/catch ergänzt. |
| FR-C-007 (`harvest.dart`) | ✅ Korrekt — `weightLossPercentage` gibt `null` statt `0.0` bei `dry > wet`. |
| FR-C-009 (`safe_parsers.dart`) | ✅ Falsch-positiv — `parseEnum` loggt bereits via `AppLogger.warning` in catch(e2). |
| FR-C-010 (`dashboard_screen.dart`) | ✅ Korrekt — `eagerError: false`, outer try/catch mit `_isLoading = false`. |
| FR-C-013 (`fertilizer.dart`) | ✅ Falsch-positiv — `minValue` hat `?? 1` Fallback, Division-by-Zero nicht möglich. |
| FR-C-019 (`unit_converter.dart`) | ✅ Falsch-positiv — `PpmScale.conversionFactor` sind Enum-Konstanten (500/700/640), nie 0. |
| FR-C-012 (`app_logger.dart`) | ✅ Korrekt — `data.toString()` auf 200 Zeichen gecapped. |
| FR-C-015 (`settings_screen.dart`) | ✅ Korrekt — Dialog mit `SelectableText` zeigt Backup-Pfad nach erfolgreichem Reset. |
| QA-003 (`plant_repository.dart`) | ✅ Falsch-positiv — `deletePermanently` löscht bereits physische Foto-Files + DB-Records in Transaction. |
| QA-009 (`rdwc_analytics_screen.dart`) | ✅ Falsch-positiv — kein `Future.wait`, sequentielle awaits in try/catch. |
| QA-010 (`backup_service.dart`) | ✅ Korrekt — `AppLogger.warning` dokumentiert dass Foto-Größe nicht eingerechnet wird. |
| QA-011 (`backup_service.dart`) | ✅ Korrekt mit Minor-Vorbehalt — DB-Pfade werden nach Restore rebased. LIKE-Match auf Dateinamen vertretbar (Dateinamen sind typischerweise eindeutig). |
| QA-015 (`dbf_import_service.dart`) | ✅ Falsch-positiv — `fertilizer_dbf_import_screen.dart` erkennt und loggt Duplikate, deselektiert sie in der UI. |

---

### Prüfergebnis P0

| Finding | Bewertung |
|---------|-----------|
| FR-B-001 (`log_provider.dart`) | ✅ Korrekt — `_safeNotifyListeners` ist jetzt am Ende des Lock-Blocks. Race-Condition geschlossen. |
| FR-A-002 (`migration_manager.dart`) | ✅ Korrekt mit Minor-Vorbehalt (VC-008-VOL). Deckt den Hauptfall ab. |
| QA-002 | ✅ Falsch-positiv bestätigt — `DatabaseRecoveryResult` ist ein Enum-basierter Typ, kein String-Match. Kein Fix nötig. |
| QA-012 (`database_rebuild_service.dart`) | ✅ Korrekt — `PRAGMA foreign_key_check` als Warning-only im Preflight. Rebuild läuft durch, Report informiert den User. |
