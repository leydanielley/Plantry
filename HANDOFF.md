# HANDOFF — Plantry Code-Review-Fixes

**Für:** Admin (Kai) — nach Context-Clear
**Vom:** B'Elanna Torres, zuletzt aktualisiert: 2026-04-24
**Ziel:** Selbst-enthaltendes Briefing, um die Fixes aus `FLUTTER_REVIEW_FINDINGS.md` zu implementieren, auf einem Feature-Branch zu pushen und einen PR zu öffnen.

---

## Stage 4 — ABGESCHLOSSEN (2026-04-24)

**Status:** Alle Phasen P0–P7 implementiert, Tuvok QS bestanden, Fixes committed.

### Was wurde gemacht (Stage 4 / Branch `review`)

| Phase | Findings | Fixes | Falsch-Positive |
|-------|----------|-------|-----------------|
| P0 | FR-B-001, FR-A-002, QA-002, QA-012 | 3 | 1 |
| P1 | FR-A-012, FR-A-013, FR-A-014 | 2 | 1 |
| P2 | FR-B-004, FR-B-008, FR-B-009, FR-B-010, FR-B-012 | 3 | 2 |
| P4 | FR-B-002, FR-B-003, FR-X-001, FR-X-002 | 2 | 2 |
| P5 | FR-B-011, FR-B-013, QA-014 | 3 | 0 |
| P6 | FR-C-005–010, FR-C-013, FR-C-019, QA-009 | 3 | 6 |
| P7 | FR-C-012, FR-C-015, QA-003, QA-010, QA-011, QA-015 | 4 | 2 |

**Offene Minors** (akzeptiert, kein Blocker für PR):
- VC-008-VOL: Partial-Backup-Cleanup-Lücke in `_createPreMigrationBackup` (sehr edge case)
- VC-009-VOL: `PlantLogRepository._photoRepository` direkt konstruiert statt DI (Test-Compat)

**Baseline nach Stage 4:** `flutter test` → +580 -59, `flutter analyze` → 2 pre-existing style infos.

### Nächste Schritte für den PR

```bash
# Branch pushen
git push origin review

# PR erstellen
gh pr create --base main --head review \
  --title "Fix: Stage 4 — Major code-review findings (P0-P7)" \
  --body "$(cat <<'EOF'
## Summary

Stage 4 des externen Code-Reviews (FLUTTER_REVIEW_FINDINGS.md) implementiert.
46 Findings geprüft, ~20 Fixes committed, ~25 als Falsch-Positive bestätigt.

Schwerpunkte:
- Race-Condition in LogProvider (FR-B-001) geschlossen
- Migration-Manager: Partial-Backup-Cleanup (FR-A-002)
- NotificationService: Platform-Guard + Interval-Validation
- BackupService: Photo-Pfad-Rebase auf Restore (QA-011)
- AppLogger: PII-Truncation (FR-C-012)
- Dashboard + EditPlantScreen: error-isolated Future.wait

## Test plan

- [x] flutter analyze → 0 neue Errors
- [x] flutter test → +580 -59 (unveränderte Baseline)
- [x] Tuvok QS → Freigabe P0–P7
EOF
)"
```

---

## TL;DR

1. Flutter SDK installieren + **JDK auf 21 umstellen** (JDK 21 passt zu Gradle 8.12 / AGP 8.9.1 / Kotlin 2.1.0). JDK 25 wird Gradle brechen.
2. Auf den Branch `review` wechseln (existiert bereits auf origin).
3. Top-4-Fixes machen (FR-B-006, FR-A-006, FR-A-007, FR-C-002) — zusammen ~60 Minuten echte Arbeit.
4. `dart format .` + `flutter analyze` + `flutter test` → Commit → Push → PR.
5. Rest (Strukturfixes) später in separaten PRs.

**Alle Details stehen in diesem Dokument und in `FLUTTER_REVIEW_FINDINGS.md`.**

---

## 1 — Kontext in 5 Sätzen

- Das Repo ist `leydanielley/Plantry` (GitHub), Flutter/Dart, mobile + Desktop, SQLite.
- Ein umfassendes Code-Review + QA wurde durchgeführt; das Ergebnis liegt in `FLUTTER_REVIEW_FINDINGS.md`.
- Der Original-Autor steckt in einer KI-Fehlerschleife — der Review hat strukturelle Lücken aufgedeckt, die iterative Einzel-Fixes nicht lösen.
- Du (Admin) hast Collaborator-Rechte, willst auf einem eigenen Branch fixen und per PR zurückmelden.
- Dieses Handoff-Dokument + `FLUTTER_REVIEW_FINDINGS.md` reichen aus, um ohne vorhergehende Konversation weiterzuarbeiten.

---

## 2 — Umgebung einrichten (Fedora 43)

### 2.1 JDK 17 installieren und als Default setzen

Fedora 43 bietet nur noch JDK 21 und JDK 25 an (kein 17 mehr im offiziellen Repo). Für dieses Projekt ist **JDK 21** die richtige Wahl — kompatibel mit Gradle 8.12, AGP 8.9.1 und Kotlin 2.1.0. JDK 25 würde die Android-Toolchain brechen.

```bash
# JDK 21 installieren
sudo dnf install -y java-21-openjdk-devel

# Shell-lokal setzen (dauerhaft via ~/.bashrc, nicht system-weit):
cat >> ~/.bashrc <<'EOF'

# Flutter-Toolchain: JDK 21 für Android/Gradle
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH="$JAVA_HOME/bin:$PATH"
EOF

source ~/.bashrc
java -version   # muss "openjdk version 21.x" zeigen, nicht 25
```

### 2.2 Flutter SDK installieren

Fedora hat kein Paket — Manual-Install ist Standard.

```bash
cd ~
# Aktuelles stable tar.xz von flutter.dev holen (Version prüfen: https://docs.flutter.dev/release/archive)
# Beispiel-Befehl, Version ggf. anpassen:
wget -O flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
tar -xf flutter.tar.xz
rm flutter.tar.xz

# PATH setzen
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

flutter --version
flutter doctor
```

### 2.3 Android-Toolchain verifizieren

Android Studio ist in `/opt/android-studio`, SDK in `~/Android/Sdk`. Flutter findet das i.d.R. automatisch, aber `flutter doctor` zeigt, ob was fehlt (Command-line-tools, Licenses).

```bash
flutter doctor --android-licenses    # einmalig durchklicken
flutter doctor                       # Ziel: alle grünen Häkchen
```

### 2.4 Projekt-Dependencies

```bash
cd /home/kaik/AndroidStudioProjects/Plantry
flutter pub get
```

### 2.5 Sanity-Check (WICHTIG — Baseline vor allen Fixes)

```bash
cd /home/kaik/AndroidStudioProjects/Plantry
flutter analyze > baseline_analyze.txt 2>&1
flutter test > baseline_test.txt 2>&1
```

Diese Baseline ist der Vergleichspunkt. Die Review-Datei behauptet „0 Issues" laut CHANGELOG — prüf, ob das stimmt. Wenn nicht, hast du sofort zusätzliche Findings.

---

## 3 — Repo-Setup

### 3.1 Branch einrichten

Der Branch `review` existiert bereits auf `origin` (vom Admin via GitHub angelegt). Lokal auschecken:

```bash
cd /home/kaik/AndroidStudioProjects/Plantry
git fetch origin
git checkout review         # erzeugt lokalen Tracking-Branch
```

### 3.2 Review-Ergebnis-Dateien committen

`FLUTTER_REVIEW_FINDINGS.md` und dieses `HANDOFF.md` sind noch untracked.

Entscheidung: **Beide im Feature-Branch committen**, damit der Freund im PR Kontext hat. Nicht in `main` mergen — nur am Branch belassen oder später in einen `docs/reviews/`-Ordner verschieben.

```bash
git add FLUTTER_REVIEW_FINDINGS.md HANDOFF.md
git commit -m "docs: add external code review + QA findings and handoff notes"
```

### 3.3 Commit-Stil (aus `CONTRIBUTING.md` + Git-Log ableitbar)

- **Subject:** imperativ, kurz, thematisch. Beispiele aus dem Repo: `Fix: versionCode/versionName ...`, `Bump versionCode to 1002 ...`.
- **Für Review-Fixes:** `Fix: <Kurz> (Review FR-X-NNN)` — die Finding-ID erleichtert Nachverfolgung. Bei mehreren Findings in einem Commit: im Body jeweils eine Zeile `Addresses FR-X-NNN` ergänzen.
- **Code-Style vor Commit:** `dart format .` und `flutter analyze`. Siehe `CONTRIBUTING.md`.

---

## 4 — Fix-Plan

**Reihenfolge = Wert pro Minute.** Die ersten vier Fixes sind isoliert, klein, mit hohem Security/UX-Wert.

### FIX 1 — FR-B-006 Path-Traversal im ZIP-Import (🔴 Security)

- **Datei:** `lib/services/backup_service.dart`, **Zeile 347**.
- **Ist:**
  ```dart
  if (!canonicalOut.startsWith(canonicalImport)) {
  ```
- **Soll:**
  ```dart
  final boundary = canonicalImport.endsWith(Platform.pathSeparator)
      ? canonicalImport
      : '$canonicalImport${Platform.pathSeparator}';
  if (canonicalOut != canonicalImport && !canonicalOut.startsWith(boundary)) {
  ```
- **Warum:** `/tmp/a` akzeptiert `startsWith` fälschlich für `/tmp/ab/...`. Zip-Slip-Variante.
- **Test:** `flutter test` (falls Tests dafür existieren — sonst mindestens manuell: beliebiges ZIP mit `../` in einem Entry importieren). `flutter analyze` muss clean bleiben.
- **Commit:** `Fix: harden ZIP path-traversal check in BackupService (Review FR-B-006)`

### FIX 2 — FR-A-006 `PRAGMA integrity_check` wird verworfen (🔴 Recovery)

- **Datei:** `lib/database/database_recovery.dart`, **Zeile 40**.
- **Ist:**
  ```dart
  await db.execute('PRAGMA integrity_check');
  ```
- **Soll (Muster steht in derselben Datei, Zeile 22):**
  ```dart
  final result = await db.rawQuery('PRAGMA integrity_check');
  final ok = result.isNotEmpty &&
      (result.first.values.first?.toString().toLowerCase() == 'ok');
  if (!ok) {
    AppLogger.error('DatabaseRecovery', 'integrity_check failed', result);
    return false; // je nach Funktionssignatur: RecoveryResult.failed o.ä.
  }
  ```
- **Zusätzlich Zeile 41-42:** `VACUUM`/`REINDEX` können minutenlang laufen — mit Timeout + try/catch absichern.
- **Test:** `flutter test test/database_recovery_test.dart` (existiert bereits).
- **Commit:** `Fix: evaluate PRAGMA integrity_check result in attemptRepair (Review FR-A-006)`

### FIX 3 — FR-A-007 Hart-codierter Android-Pfad für Emergency-Backup (🔴 Platform)

- **Datei:** `lib/database/database_recovery.dart`, **Zeile 176**.
- **Ist:**
  ```dart
  final backupDir = Directory('/storage/emulated/0/Download/Plantry Backups/Emergency');
  ```
- **Soll:** Analog zu **Zeile 251** derselben Datei (dort wird `getApplicationDocumentsDirectory()` korrekt verwendet):
  ```dart
  final base = await getApplicationDocumentsDirectory();
  final backupDir = Directory(path.join(base.path, 'Plantry Backups', 'Emergency'));
  // Auf Android optional zusätzlich versuchen, in Downloads zu spiegeln (Platform.isAndroid).
  ```
- **Test:** `flutter test` grün halten. Manuell (wenn Zeit) auf Linux-Desktop einen korrupten DB-Zustand simulieren und Recovery starten.
- **Commit:** `Fix: use platform-aware path for emergency backup (Review FR-A-007)`

### FIX 4 — FR-C-002 Destruktiver DB-Reset ohne Double-Confirmation (🔴 UX)

- **Datei:** `lib/screens/settings_screen.dart`, **Zeilen 249-269** (`_showResetConfirmation`).
- **Ist:** Einfacher Ja/Nein-AlertDialog → sofortiger `txn.delete(...)` über 6 Tabellen.
- **Soll (skaliert auf Geschmack):**
  - Titel in `DT.error`-Rot mit Warnsymbol.
  - Text: „Alle Daten werden **unwiderruflich** gelöscht. Ein Backup wird vorher automatisch erstellt unter: **<Pfad>**."
  - Typ-Confirm: TextField, User muss „DELETE" tippen.
  - Zwei Buttons: `Abbrechen` (primär) + `Endgültig löschen` (grau bis Text stimmt).
  - Nach erfolgreichem Export: Snackbar mit Pfad + „In Datei-Manager öffnen"-Button (via `url_launcher`).
- **Test:** `flutter analyze`, manueller Klickpfad im Desktop-Build.
- **Commit:** `Fix: strengthen destructive DB-reset confirmation UX (Review FR-C-002)`

### Danach (Stufe 2 — vor PR-Merge, aber eigene Commits)

Blocker, die Plausibilität haben, aber noch nicht gegen Code verifiziert sind (siehe `FLUTTER_REVIEW_FINDINGS.md` Abschnitt 3.3 / VC-004):

- **FR-A-002** (`_verifyBackup` ohne Integritätscheck) — lies `migration_manager.dart` ab `_verifyBackup` und prüf, was da ist.
- **FR-B-001** (verifiziert: `notifyListeners` Zeile 113 außerhalb Lock) — Fix: `_safeNotifyListeners()` in den Lock-Block ziehen.
- **QA-002** (Emergency-Backup-String-Match in `DatabaseRecovery`) — Recovery-Rückgabe auf Enum/Result umstellen.
- **QA-012** (DB-Rebuild ohne FK-Preflight) — `DatabaseRebuildService` lesen, Pre-Check hinzufügen.

### Stufe 3 — strukturelle Refactors (eigene PRs, später)

1. **Migrations-Pipeline-Refactor:** Idempotenz-Vertrag, `PRAGMA table_info`-Checks vor `ADD COLUMN`, Version-Gap v21–v34 klären, `SchemaRegistry` auf v43 heben, Timeout pro Migration.
2. **`mounted`/dispose-Konvention:** Alle 52 Screens durchgehen; Lint-Rule `use_build_context_synchronously` sicherstellen.
3. **Settings als Provider:** `GrowLogApp.of(context).settings` durch `Provider<AppSettings>` ersetzen.
4. **Tests auf v43 heben:** `TestDatabaseHelper.currentVersion = 43`, Test-DB-Patch automatisieren.

**Warum in dieser Reihenfolge:** Die Stufe-3-Punkte sind die Hebel, die den Root-Cause der KI-Fehlerschleife adressieren. Einzelne Stufe-1/2-Fixes sind schnelle Gewinne mit klarem Security/UX-Wert — aber erst Stufe 3 löst die strukturellen Muster auf.

---

## 5 — Pre-Commit-Checkliste

Für **jeden** Commit, egal ob Top-4 oder Stufe-3:

```bash
cd /home/kaik/AndroidStudioProjects/Plantry

# 1. Code-Style
dart format .

# 2. Statische Analyse
flutter analyze
# Ziel: keine neuen Errors gegenüber baseline_analyze.txt

# 3. Tests
flutter test
# Ziel: keine neuen Fails gegenüber baseline_test.txt

# 4. Optional: Integration-Tests
# Laut test/HOW_TO_RUN_INTEGRATION_TESTS.md braucht das einen Patch auf
# DatabaseHelper. ACHTUNG: dieser Patch hebt den Test auf Schema v14,
# während Produktion v43 ist (siehe QA-Befund 2.3). Vor Merge NICHT patchen.
```

Wenn einer der drei Schritte scheitert: **nicht committen**. Fix zuerst, dann erneut prüfen.

---

## 6 — Push und PR

```bash
git push origin review

# Mit GitHub CLI:
gh pr create --base main --head review \
  --title "Fix: external code-review findings (stage 1)" \
  --body-file <(cat <<'EOF'
## Summary

Externes Review (siehe FLUTTER_REVIEW_FINDINGS.md in diesem Branch) hat 9 Blocker
und 46 Major Findings aufgedeckt. Diese PR adressiert Stufe 1 (4 Blocker):

- FR-B-006 — Path-Traversal im ZIP-Import (Security)
- FR-A-006 — `PRAGMA integrity_check` wurde per `execute` verworfen (Recovery)
- FR-A-007 — Emergency-Backup-Pfad Android-only (Platform)
- FR-C-002 — Destruktiver DB-Reset ohne Double-Confirmation (UX)

Stufe 2+3 folgen in separaten PRs.

## Test plan

- [ ] `flutter analyze` clean
- [ ] `flutter test` grün
- [ ] Manuell: ZIP mit `../`-Entry → Import wird abgelehnt
- [ ] Manuell: Emergency-Recovery auf Linux-Desktop triggert keinen Pfad-Fehler
- [ ] Manuell: Reset-Dialog verlangt Typ-Confirm, zeigt Backup-Pfad

## Review

Kontext in `FLUTTER_REVIEW_FINDINGS.md` Abschnitt 3 (Prioritäten) und Abschnitt 4 (QS).
EOF
)
```

---

## 7 — Prompt für eine frische Claude-Session (nach `/clear`)

Kopiere den folgenden Block in die neue Session, damit Claude ohne Vorkontext weitermachen kann:

> Ich arbeite im Repo `/home/kaik/AndroidStudioProjects/Plantry` (Flutter/Dart, Remote `leydanielley/Plantry`, Collaborator-Zugriff). Ich bin auf Branch `review` (checkout per `git fetch origin && git checkout review`). Es gibt zwei wichtige Dokumente im Root:
>
> 1. `HANDOFF.md` — selbst-enthaltende Anleitung für Setup und Fix-Plan.
> 2. `FLUTTER_REVIEW_FINDINGS.md` — externes Code-Review mit 9 Blockern und 46 Majors.
>
> Lies zuerst `HANDOFF.md` komplett und dann `FLUTTER_REVIEW_FINDINGS.md` Abschnitt 3 + 4. Dann fang mit **FIX 1 (FR-B-006)** an. Wenn Fix 1 grün durch `dart format`, `flutter analyze` und `flutter test` läuft, committe mit dem im HANDOFF vorgegebenen Message-Format und mach Fix 2 weiter. Eine Änderung pro Commit.
>
> Vor jedem Commit: `dart format .`, `flutter analyze`, `flutter test`. Keine Skips.
>
> System: Fedora 43, Flutter SDK ggf. noch zu installieren (siehe HANDOFF Abschnitt 2 — JDK 21 via `dnf`, `JAVA_HOME` in `~/.bashrc`, Flutter SDK via `git clone ... -b stable ~/flutter`, `flutter doctor`). Erst Setup fertig, dann Fixes.
>
> Berichte nach Fix 1 kurz: was geändert, Baseline vs. Post-Fix für analyze/test. Dann frag mich, ob ich Fix 2 starten soll.

---

## 8 — Was bewusst nicht getan wurde

- **Keine Änderungen am App-Code** — dieser Handoff beschreibt nur, was du selbst tun wirst.
- **Kein `pub get` vorab** — ohne SDK nicht möglich; du triggerst es als erster Schritt nach Installation.
- **Kein Push** — du pushst selbst, nachdem die Fixes grün sind.
- **Kein Automatisieren der JDK-Umstellung system-weit** — könnte andere Projekte brechen. Shell-lokaler Export via `~/.bashrc` ist die sichere Variante.

---

## 9 — Wenn etwas schiefgeht

| Problem | Erster Check |
|---------|--------------|
| `flutter doctor` klagt über Android-Lizenzen | `flutter doctor --android-licenses` durchklicken |
| Gradle-Build bricht mit JDK-Fehler | `echo $JAVA_HOME` → muss auf `/usr/lib/jvm/java-17-openjdk` zeigen |
| `flutter analyze` zeigt schon vor Fixes viele Errors | Baseline aus `baseline_analyze.txt` mit Freund klären — ist der CHANGELOG-Claim „0 Issues" aktuell? |
| Ein Finding passt nicht zur Realität | Möglich — siehe VC-004 in der Findings-Datei. Finding überspringen und kurz notieren. Keine Zeit mit falsch-positiven verbringen. |
| Integration-Tests scheitern wegen Schema-Version | Nicht fixen in dieser PR. Separater Task in Stufe 3. |

---

**Ende Handoff.** Viel Erfolg, Admin. Beim Freund punkten wir mit Qualität, nicht mit Speed — die Top-4-Fixes reichen für den ersten PR und machen einen klaren Eindruck.

— B'Elanna Torres
