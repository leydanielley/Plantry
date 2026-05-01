# Phase 6 — Offene Tasks aus Code-Review (2026-05-01)

Stand nach Master-Review der Codebase. KRITISCH-Block ist großteils gefixt, HOCH/MITTEL/NIEDRIG noch offen.

## ✅ ERLEDIGT (committet in diesem Branch)

- **K1** — RDWC `as double` Force-Cast → `(... as num?)?.toDouble() ?? 0.0` in `rdwc_repository.dart:720, 809`
- **K2** — Photo-Files vor Plant-DB-Deletion → Two-Phase-Delete in `plant_repository.dart:deletePermanently()` (Files NACH TX-Commit)
- **K3** — Notification-ID Overflow → Defensive `assert()` + `_maxSafePlantId = 200_000_000` in `notification_config.dart`
- **K4** — `Navigator.push().then()` ohne mounted-Check → 13 Stellen in dashboard, room_detail, rdwc_system_detail, plant_detail, harvest_detail
- **K5** — `context.read()` nach `if (mounted)` → Provider-References vor await capturen in `add_harvest_screen.dart`
- **K6 (teilweise)** — `parseUserDouble()` in `safe_parsers.dart` neu angelegt (akzeptiert ',' und '.' als Dezimaltrenner). 3 von 4 Validators in `rdwc_addback_complete_screen.dart` umgestellt, EC-After-Validator noch offen.

## 🔴 K6 (Rest) — DE-Locale Komma-Bug, Querschnitt

`SafeParsers.parseUserDouble()` ist da, aber überall ausrollen wo User-Input geparst wird:

- `rdwc_addback_complete_screen.dart:243-246` — letzter Validator (EC-After)
- `rdwc_quick_measurement_screen.dart:146, 148, 151, 289, 312, 337`
- `rdwc_recipe_form_screen.dart:147, 158, 161, 196, 347, 371, 503`
- `edit_harvest_screen.dart:199, 459-460, 845-846, 1323`
- `edit_room_screen.dart:185-187`
- `rdwc_system_form_screen.dart:101, 112`

Pattern überall: `double.tryParse(v)` → `SafeParsers.parseUserDouble(v)`.

## 🔴 K7 — pickImage() cancel ≠ permission denied

`utils/permission_helper.dart:12-47` — Logic returnt `true` wenn `pickImage()` nicht wirft. User clickt "abbrechen" → kein Throw → returnt `true` → Permission fälschlich als gewährt angesehen.
**Fix:** Null-Check auf `pickImage`-Result, ODER `permission_handler` Package nutzen.

## 🔴 K8 — Backup-Restore SQL-LIKE matched fremde Pfade

`services/backup_service.dart` Restore-Flow — `WHERE file_path LIKE '%$fileName'` zu liberal. `photo.jpg` matched `/foo/photo.jpg` UND `/bar/baz/photo.jpg`.
**Fix:** Match per `id` statt LIKE, oder Map während Import tracken.

## 🔴 K9 — iOS hasEnoughStorage() returnt blind true

`utils/storage_helper.dart:27-77` — iOS-Backups ohne Speicher-Prüfung. Bei vollem Speicher: corrupted DB.
**Fix:** Native Method-Channel für iOS Storage-Check, oder iOS-Backup blockieren wenn Check nicht möglich. Nicht akut (Android-only), aber Showstopper sobald iOS kommt.

## ⚪ N3 — Self-induced Dead Code

`add_harvest_screen.dart:251` — `_t['error_saving'] ?? 'Fehler beim Speichern'`. `_t[]` ist non-null, das `??` ist tot. flutter analyze meldet 2 Warnings. **Fix:** `??`-Fallback entfernen.

---

## 🟠 HOCH — Sprint 2 (14 Items)

### H1. ~40 Stellen mit `Navigator.push` + post-await Code ohne `mounted`
Querschnitts-Pattern in fast allen `*_list_screen.dart`:
```dart
final result = await Navigator.push(...);
if (result == true) _loadXXX();   // ← mounted fehlt
```
Häufige Quelle für `setState() called after dispose()`.

### H2. Schema-Versionen v21–v35 nicht im Registry
`database/schema_registry.dart:280-283` — 14 Versionen blind. Backup von v25 auf v43 → keine Validation. Fix: Schemas retroaktiv registrieren oder Restore blockieren bei version-gap > 5.

### H3. Down-Migrations alle leer
`database/migrations/scripts/migration_v42.dart`, v43 — `down: (db) async {}`. Kein Rollback-Pfad. Fix: Downgrades explizit blockieren ODER proper down-migration.

### H4. Photo-Cache Byte-Counter kann driften
`helpers/image_cache_helper.dart:118-176` — Race zwischen `clearMemoryCache()` und `_addToCache()`. OOM auf Low-End möglich. Fix: Self-heal mit recompute aus `cache.values`.

### H5. AppLogger loggt absolute Pfade (PII-light)
`services/backup_service.dart:107, 219-220, 274-275` — Device-Pfade in Logs. Fix: `path.basename()` für Logs.

### H6. Empty `catch (_) {}` bei FK-Re-Aktivierung
`services/backup_service.dart:555` — `try { await db.execute('PRAGMA foreign_keys = ON'); } catch (_) {}`. Wenn das fehlschlägt → App läuft ohne FK-Constraints → Orphans entstehen still. Fix: Logger + rethrow.

### H7. Empty `catch (_) {}` in Migration-Manager
`database/migrations/migration_manager.dart:120` — File-Cleanup nach Migration-Backup-Failure. Silent fail. Fix: Mindestens debug-log.

### H8. `Future.wait` mit inline `.then(...)` ohne Error-Handler
`screens/dashboard_screen.dart:128, 132` — Throw → inkonsistente Behandlung. Fix: `eagerError: true` + `.then(..., onError: ...)`.

### H9. Stream-Listen ohne `onError`-Callback
`screens/splash_screen.dart:45` — Backup-Progress-Stream-Listener. Crash → SplashScreen hängt → App startet nie. Fix: `onError`-Callback im listen().

### H10. Hardcoded Android-Pfad für Emergency-Backup
`database/database_recovery.dart:225` — `/storage/emulated/0/Download/Plantry Backups/Emergency`. Broken auf Samsung One UI, Multi-User Tablets, scoped storage Android 11+. Fix: `getExternalStorageDirectory()` aus path_provider.

### H11. `_formKey.currentState!` ohne Null-Check
~30 Screens — Bei sehr schnellem Re-build kann `currentState` null sein. Fix: `_formKey.currentState?.validate() != true`.

### H12. NotificationHelper: keine Per-Reminder Try-Catch
`helpers/notification_helper.dart:27-101` — Reminder 1 fails → 2-4 nie scheduled. Fix: Try-Catch pro Reminder + Summary-Log.

### H13. Plant-Save: `findById` außerhalb Transaction
`repositories/plant_repository.dart:196-220` — Read und Write nicht atomar. Bei concurrent saves theoretisch lost-update.

### H14. `requestPermissions().then()` ohne `.catchError`
`screens/notification_settings_screen.dart:54` — Permission-Throw → kein UI-Feedback. Fix: `.catchError()` oder try/catch await.

### H15. (Bonus aus K1-Verifikation) Aggregations-Force-Casts in `rdwc_repository.dart:879, 920, 1406`
`(result.first['avg_consumption'] as num).toDouble()` — wenn AVG/SUM auf leerem Result-Set null returnt, crashed `as num`. Fix: `as num?` mit Fallback wie K1.

---

## 🟡 MITTEL — Sprint 3 (13 Items)

- **M1** SchemaRegistry-Lücke nicht via `_onDowngradeError` blockiert
- **M2** `Plant.fromMap()`-Fallbacks loggen nicht (corrupt data wird stiller)
- **M3** ServiceLocator-Reset ruft kein `dispose()` auf Services
- **M4** RDWC archive: kein `archived_at` Timestamp → Race-Limbo möglich
- **M5** Provider-Calls in `add_harvest_screen` nicht awaited (gefixt in K5 — entfernt)
- **M6** Verschachtelte try/catch in `migration_manager` machen Stack-Trace-Tracking schwer
- **M7** Empty error-Handler in `add_fertilizer_screen.dart:197-200` (kein User-Feedback)
- **M8** Batch-Photo-Restore in `backup_service:202, 618` ohne Error-Distinction
- **M9** `.catchError` in `main.dart:116` ohne `rethrow` — Settings-Save-Failure unsichtbar
- **M10** `.then()` vs `await` Stil-Mix
- **M11** DT-Tokens nicht durchgängig (Theme-Drift in add_log Bereichen)
- **M12** `add_plant_screen` `_phase = PlantPhase.seedling` als `final` (verwirrend)
- **M13** Test-Anti-Pattern `find.byType(Exception)` (gefixt in vorigem Commit, als Pattern dokumentiert)

---

## ⚪ NIEDRIG — Backlog (3 Items)

- **N1** Hardcoded `'Pflanze bearbeiten'` in `edit_plant_screen.dart:116`
- **N2** Inkonsistente `.then()` vs `await` Stylings
- **N3** Self-induced Dead Code (siehe oben)

---

## Hinweise zur Verifikation

Befunde stammen aus parallelem Review von 4 Sub-Agents. Vor Fix:
1. `git blame` auf der Stelle prüfen (Zeilen können verschoben sein)
2. Prüfen ob Logik in der Zwischenzeit bereits geändert wurde
3. Bei DB-Befunden: SQLite-Verhalten der echten Query testen, nicht nur theoretisch

`flutter analyze` ist nach K1-K5 sauber bis auf 2 self-induced Warnings (siehe N3).
