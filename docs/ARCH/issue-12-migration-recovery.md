# FR-A-001 — Migration Recovery Design Note (P1)

**Issue:** leydanielley/Plantry#12  
**Titel:** refactor(migrations): replace main.dart Force-Clear with MigrationManager root-cause fix  
**Branch:** feature/issue-12-migration-rootcause  
**Phase:** P1 — Design only (kein Code-Diff in `lib/`)  
**Datum:** 2026-05-26  
**Autor:** Harren (VC Review)

---

## Kontext & Problemstellung

Der aktuelle Start-Pfad (`main.dart`, Zeilen 26–59) enthält eine Prüfung, die einen
`migration_status == 'in_progress'` Eintrag in SharedPreferences bei Überschreitung
von 30 Minuten auf `timeout` schreibt. Das ist bereits ein Improvement gegenüber einem
früheren Force-Clear, aber es löst nicht das Root-Cause-Problem:

**Der MigrationManager weiß beim nächsten App-Start nicht aktiv, ob die DB in einem
stuck-State ist.** Er verlässt sich ausschließlich auf den `migration_status`-Flag in
SharedPreferences — einen externen, von der DB entkoppelten Marker. Wenn dieser Flag
fehlt, falsch ist oder nie gesetzt wurde (z. B. bei einem Kill-Signal nach
`markMigrationInProgress()` aber vor dem eigentlichen `openDatabase()`-Aufruf),
startet der MigrationManager ohne Warnung.

Zusätzlich existiert ein Version-Mismatch in `database_helper.dart`:
- Zeile 70: `version: 43` (erster `openDatabase`-Call, normaler Pfad)
- Zeile 96/143: `version: 44` (Recovery-Pfad)

Dieser Mismatch bedeutet: Im normalen Start-Pfad wird v44 nie als Zielversion gesetzt,
d.h. `migrationV44` wird nicht ausgeführt. Das ist ein separates Bug (nicht Scope dieses Issues)
— hier dokumentiert als Querhinweis für P2.

---

## (a) Stuck-DB-Detection

### Was ein "stuck" State ist

Ein stuck-State liegt vor, wenn eine der folgenden Bedingungen zutrifft:

1. **Status-Flag `in_progress` ohne laufende Migration** — SharedPreferences zeigt
   `migration_status == 'in_progress'` beim App-Start, aber keine Migration läuft.
   Das passiert bei App-Kill während `migrate()`.

2. **Status-Flag `timeout`** — VersionManager hat bereits festgestellt, dass eine
   Migration >30 min lief. Die DB ist ggf. in einem partiellen Zustand (Transaktion
   wurde gerollt zurück, aber Status blieb stehen).

3. **Schema-Version-Drift** — `PRAGMA user_version` der SQLite-DB stimmt nicht mit
   dem erwarteten `newVersion` überein, nach einem App-Neustart wo `migration_status ==
   'completed'` gesetzt wurde. Das kann passieren, wenn `markMigrationCompleted()`
   in der Transaktion (Zeile 304 in `migration_manager.dart`) erfolgreich war, aber
   das eigentliche `PRAGMA user_version`-Increment durch sqflite fehlschlug.

4. **Fehlende Tabellen bei bekannter DB-Version** — `SchemaRegistry.validateSchema()`
   schlägt fehl für die aktuelle `PRAGMA user_version`, obwohl `migration_status ==
   'completed'` steht. Zeigt an, dass eine partielle Migration committete, aber die
   Schema-Validierung damals nicht ausgeführt wurde (Legacy-Gap v21–v35).

### Marker-Prüfung

Zu prüfende Marker beim App-Start (in dieser Reihenfolge):

| Priorität | Marker | Prüfpunkt | Quelle |
|-----------|--------|-----------|--------|
| 1 | `migration_status` | `in_progress` oder `timeout` | SharedPreferences |
| 2 | `migration_start_time` | Elapsed > Threshold | SharedPreferences |
| 3 | `PRAGMA user_version` vs. erwartetem `kCurrentDbVersion` | Differenz != 0 | SQLite |
| 4 | `SchemaRegistry.validateSchema(db, actualVersion)` | Validierung schlägt fehl | SQLite + SchemaRegistry |

### Wo prüfen: App-Start vs. on-demand

**App-Start (Pflicht):** Die Detection muss im `DatabaseHelper._initDB()`-Pfad
erfolgen, *vor* dem ersten `openDatabase()`-Aufruf mit Migrations-Callback. Das ist
der frühestmögliche Zeitpunkt, zu dem die DB-Datei existiert und geöffnet werden kann.

Die bestehende Prüfung in `main.dart` (Zeilen 26–59) liest nur SharedPreferences
und hat keinen Zugriff auf die DB-Datei selbst. Sie sollte als Vor-Stufe erhalten
bleiben (sie setzt `status` auf `timeout` bevor DB überhaupt geöffnet wird), aber
die DB-Level-Prüfung (Marker 3 und 4) gehört in `DatabaseHelper`.

**On-demand (optional, P3):** Ein `MigrationManager.diagnose(Database db)`-Aufruf
könnte in einem Admin-Screen oder beim manuellen "Datenbank prüfen"-Button angeboten
werden. Nicht in P2-Scope.

---

## (b) Recovery-Strategie ohne Datenverlust

### Ist-Situation

Der aktuelle Rollback-Mechanismus ist korrekt für den Happy-Path: Die gesamte
Migration läuft in einer SQLite-Transaktion (`db.transaction()`). Bei Exception
rollt sqflite die Transaktion zurück. `PRAGMA user_version` wird von sqflite
automatisch auf `newVersion` gesetzt *nach* Transaktions-Commit — d.h. bei
Rollback bleibt `user_version == oldVersion`. Das ist robust.

Das Problem liegt im **Post-Kill-Szenario**: Wenn die App während einer laufenden
Transaktion gekillt wird, rollt SQLite die uncommittete Transaktion beim nächsten
Öffnen via WAL-Journal automatisch zurück. Die DB ist konsistent auf `oldVersion`.
Aber `migration_status` in SharedPreferences zeigt noch `in_progress`, und der
MigrationManager weiß nicht, ob er einfach neu starten soll.

### Optionen

**Option A — Re-run der unvollständigen Migration (empfohlen)**

Beim Detect eines stuck-State (Marker 1 oder 2): Aktuellen `PRAGMA user_version` lesen,
mit erwartetem `kCurrentDbVersion` vergleichen, dann `migrate(db, actualVersion,
kCurrentDbVersion)` erneut aufrufen. Da die Transaktion bei Kill automatisch
gerollt wurde, ist `actualVersion == oldVersion`. Die Migration läuft einfach neu
durch — der Pre-Migration-Backup wird erneut erstellt, die Transaktion erneut versucht.

- Vorteile: Keine spezielle Logik, nutzt bestehenden Migrations-Pfad. Kein Datenverlust.
  Idempotent (die meisten Migrations-Scripts haben bereits `IF NOT EXISTS`-Guards oder
  `PRAGMA table_info`-Checks, z.B. `migration_v44.dart` Zeilen 8–13).
- Nachteile: Falls die Migration selbst einen Fehler hat (Bug im Script), wird sie
  erneut fehlschlagen. Endlos-Loop wenn Recovery wieder in `in_progress` endet — dagegen
  muss eine `retry_count`-Schranke eingebaut werden (max. 2 Versuche).

**Option B — Schema-Repair via SchemaRegistry**

Wenn `actualVersion == expectedVersion` aber Schema-Validierung schlägt fehl
(Marker 4 — Schema-Drift ohne Version-Diff): Differenz-Tabellen und -Spalten aus
SchemaRegistry ermitteln und via `ALTER TABLE ... ADD COLUMN` nachrüsten.

- Vorteile: Zielgerichtet, minimaler Eingriff, kein Datenverlust.
- Nachteile: Nur für `ADD COLUMN` machbar. `DROP COLUMN`, Umbenennung, Index-Rebuild
  sind in SQLite aufwändig. Deckt nicht alle Drift-Szenarien ab.
- Einsatz: Als ergänzende Strategie nach Option A, wenn Re-run nicht greift.

**Option C — Rollback + Forward via Backup-Restore**

Wenn Re-run (Option A) zweimal schlägt: Backup vom Pre-Migration-Backup-Pfad
(gespeichert im `backupPath`-Feld von `MigrationException`) wiederherstellen,
dann Migration erneut versuchen. Das ist eine vollständige Rücksetzung auf den
Zustand vor dem Migrations-Versuch.

- Vorteile: Garantiert konsistenten Ausgangszustand.
- Nachteile: Backup-Restore ist komplex (ZIP entpacken, DB ersetzen, Neustart).
  Datenverlust von Änderungen nach dem Pre-Migration-Backup (typisch 0, da Migration
  direkt nach App-Update läuft). Benötigt Import-Logic aus BackupService.
- Einsatz: Nur als letzter Schritt vor dem Fallback (Sektion c).

### Empfehlung

**Option A als primäre Strategie** mit `retry_count`-Schranke (max. 2):

1. Stuck-State detected: Lese `PRAGMA user_version` → `actualVersion`
2. Falls `actualVersion < kCurrentDbVersion`: `migrate(db, actualVersion, kCurrentDbVersion)` aufrufen
3. Falls Migration erneut fehlschlägt und `retry_count < 2`: retry_count erhöhen, zurück zu 2
4. Falls `retry_count >= 2`: Fallback-Pfad (Sektion c)

**Option B** wird parallel zu Schritt 2 angewandt, wenn `actualVersion == expectedVersion`
aber Schema-Validierung failed (Sonderfall Drift ohne Version-Diff).

**Option C** ist für P2 zurückgestellt — benötigt Backup-Restore-API die noch nicht
als separater Einstiegspunkt existiert.

---

## (c) Fallback-Verhalten

### Wenn Recovery nicht möglich ist

Szenarien, in denen Recovery fehlschlägt:
- Korrupte WAL-Datei: `PRAGMA integrity_check` liefert Fehler (bereits durch
  `DatabaseRecovery.performRecovery()` abgedeckt — dieser Pfad existiert)
- Irreparabler Schema-Drift: `ALTER TABLE` schlägt fehl, Columns nicht hinzufügbar
- Zwei fehlgeschlagene Re-run-Versuche: Bug im Migration-Script selbst

### Sicheres Fallback-Protokoll

**Kein stilles Force-Clear. Daten dürfen nur mit expliziter User-Bestätigung gelöscht werden.**

Ablauf:

1. **Read-only-Modus aktivieren** — App startet, aber alle Schreiboperationen sind
   gesperrt (Repositories geben `DatabaseReadOnlyException` zurück). User kann
   seine Daten noch sehen.

2. **Recovery-Dialog anzeigen** — Modaler Dialog (nicht dismissible!) mit:
   - Klarer Fehlerbeschreibung (keine technischen Details, aber ehrlich)
   - Button "Daten exportieren (JSON)" — triggert `DatabaseRecovery.exportToJSON()`
     und öffnet System-Share-Dialog
   - Button "Support kontaktieren" — öffnet Mail-Intent mit Log-Anhang
   - Button "Datenbank zurücksetzen" (destruktiv, rot, unten) — erst aktiv nach
     Bestätigungs-Checkbox "Ich verstehe, dass alle Daten gelöscht werden"

3. **Nach expliziter Bestätigung** — `DatabaseRecovery.deleteCorruptedDatabase()`
   aufrufen (der bereits ein Backup vor dem Löschen erstellt), dann Neustart.

4. **Logging** — Vollständiger Stack-Trace und Status-History in AppLogger,
   damit Support-Diagnose möglich ist.

### Was niemals passieren darf

- Stilles `deleteDatabase()` ohne User-Wissen
- App-Start mit leerer DB ohne Dialog wenn vorher Daten vorhanden waren
- `migration_status`-Flag löschen ohne den aktuellen DB-Zustand zu verstehen

---

## (d) Interface-Sketch

Pseudo-Dart — nur Vertrags-Definition für P2, keine Implementierung.

```dart
// lib/database/migrations/migration_manager.dart — Erweiterung

// ---- Neuer Enum: Aktueller Zustand der DB beim Start ----
enum DbStartupState {
  /// DB ist auf erwartetem Schema, kein Eingriff nötig
  healthy,

  /// Migration muss normal laufen (oldVersion < newVersion, kein prior stuck)
  migrationNeeded,

  /// In-progress oder timeout-Flag gefunden — Re-run nötig
  stuckInProgress,

  /// Schema-Drift: user_version stimmt, aber Tabellen/Columns fehlen
  schemaDrift,

  /// Recovery komplett fehlgeschlagen — Read-only + Dialog
  unrecoverable,
}

// ---- Result-Typ für Startup-Diagnose ----
class DbStartupDiagnosis {
  final DbStartupState state;
  final int actualVersion;    // PRAGMA user_version
  final int expectedVersion;  // kCurrentDbVersion
  final String? details;      // Log-Detail für Support

  const DbStartupDiagnosis({
    required this.state,
    required this.actualVersion,
    required this.expectedVersion,
    this.details,
  });
}

// ---- Result-Typ für Recovery-Versuch ----
sealed class RecoveryResult {
  const RecoveryResult();
}

class RecoverySuccess extends RecoveryResult {
  final int recoveredToVersion;
  const RecoverySuccess({required this.recoveredToVersion});
}

class RecoveryFailed extends RecoveryResult {
  final String reason;
  final bool dataExportAvailable;
  final String? exportPath;
  const RecoveryFailed({
    required this.reason,
    required this.dataExportAvailable,
    this.exportPath,
  });
}

// ---- Neue Methoden auf MigrationManager ----
extension MigrationManagerRecovery on MigrationManager {

  /// Analysiert den DB-Zustand beim App-Start.
  /// Muss NACH openDatabase() aufgerufen werden, da PRAGMA user_version
  /// erst dann lesbar ist.
  ///
  /// [db] Geöffnete Datenbank-Instanz
  /// [expectedVersion] kCurrentDbVersion aus DatabaseHelper
  Future<DbStartupDiagnosis> diagnoseStartupState(
    Database db,
    int expectedVersion,
  );

  /// Versucht Recovery für einen erkannten stuck-State.
  /// Maximal [maxRetries] Versuche (empfohlen: 2).
  ///
  /// Gibt [RecoverySuccess] zurück wenn DB wieder in konsistentem Zustand.
  /// Gibt [RecoveryFailed] zurück wenn Recovery unmöglich — Caller zeigt Dialog.
  Future<RecoveryResult> attemptRecovery(
    Database db,
    DbStartupDiagnosis diagnosis, {
    int maxRetries = 2,
  });

  /// Repariert Schema-Drift durch ADD COLUMN für fehlende Spalten.
  /// Nur für Drift ohne Version-Diff (Sonderfall).
  ///
  /// Gibt true zurück wenn alle fehlenden Columns hinzugefügt wurden.
  Future<bool> repairSchemaDrift(
    Database db,
    int targetVersion,
  );
}

// ---- Konstante für MigrationManager (ersetzt magic number) ----
// Muss mit openDatabase(version: ...) synchron gehalten werden.
// In P2: aus DatabaseHelper.kCurrentDbVersion lesen statt duplizieren.
static const int kCurrentDbVersion = 44; // TODO(P2): sync-Mechanismus definieren
```

### Integration in DatabaseHelper

```dart
// Konzeptueller Aufruf-Ort: nach _initDB(), vor Rückgabe an Caller

// Schritt 1: Diagnose
final diagnosis = await migrationManager.diagnoseStartupState(db, kCurrentDbVersion);

switch (diagnosis.state) {
  case DbStartupState.healthy:
  case DbStartupState.migrationNeeded:
    break; // Normal-Pfad, sqflite's onUpgrade läuft
  case DbStartupState.stuckInProgress:
  case DbStartupState.schemaDrift:
    final result = await migrationManager.attemptRecovery(db, diagnosis);
    if (result is RecoveryFailed) {
      // -> Read-only-Modus + Recovery-Dialog triggern
      _triggerRecoveryDialog(result);
    }
  case DbStartupState.unrecoverable:
    _triggerRecoveryDialog(null);
}
```

---

## Offene Punkte für P2

1. **Version-Mismatch in `database_helper.dart`**: Zeile 70 trägt `version: 43`,
   Recovery-Pfad auf Zeilen 96/143 trägt `version: 44`. Im normalen Start-Pfad
   wird migrationV44 nie getriggert. Muss in P2 auf `kCurrentDbVersion` normalisiert
   werden (eine Konstante, ein Ort).

2. **`retry_count`-Persistenz**: Zwischen App-Starts muss `retry_count` in
   SharedPreferences gespeichert werden, damit der 2-Retry-Guard auch über Kills
   hinweg greift. Schlüssel: `migration_retry_count`.

3. **Read-only-Modus**: Kein Read-only-Mechanismus existiert bislang in den
   Repositories. P2 muss definieren, wie `DatabaseReadOnlyException` durch die
   Repository-Schicht propagiert wird.

4. **BackupService-Integration in Recovery-Dialog**: `DatabaseRecovery.exportToJSON()`
   erzeugt ein Rohdaten-JSON, aber der User braucht einen Share-Intent. Der Dialog-Widget
   benötigt Zugriff auf BackupService oder einen Export-Callback.

5. **`kCurrentDbVersion`-Sync**: Aktuell ist die DB-Zielversion in
   `DatabaseHelper._initDB()` hardcoded. Empfehlung: Eine zentrale Konstante in
   `DatabaseHelper` einführen, auf die sowohl `openDatabase(version:)` als auch
   der neue Recovery-Code referenzieren.

---

## Querverweise

- `lib/main.dart:26–59` — Bestehende SharedPreferences-Prüfung (Vor-Stufe)
- `lib/database/migrations/migration_manager.dart` — Migrations-Transaktion + Rollback-Logik
- `lib/database/database_recovery.dart` — Corruption-Recovery (VACUUM/REINDEX + Emergency Export)
- `lib/database/schema_registry.dart` — Schema-Definitionen v13–v44, `validateSchema()`
- `lib/utils/version_manager.dart` — `migration_status`, `markMigrationInProgress/Completed/Failed`
- `lib/database/database_helper.dart:70,96,143` — Version-Mismatch (offener Punkt 1)
