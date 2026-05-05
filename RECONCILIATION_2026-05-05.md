# Findings-Reconciliation — Stand 2026-05-05

Master-Quelle für den Status der externen Code-Review-Findings vom 21.04.2026
(`FLUTTER_REVIEW_FINDINGS.md`). Hier konsolidiert: was ist erledigt, was ist
teilweise drin, was ist offen, plus Mapping zur internen Sprint-TODO
(`PHASE6_TODO.md`).

## Bilanz (75 IDs: 64 FR/QA aktiv + FR-C-001 zurückgezogen + 5 VC-Meta + 6 S2-FC)

| Status | Count |
|---|---|
| ✅ DONE | 46 |
| 🟠 TEILWEISE | 6 |
| 🔴 OFFEN | 15 |
| ❓ UNKLAR | 0 |

## Findings-Tabelle

| ID | Sev | Kurzbeschreibung | Status | Commit / PHASE6 | Notiz |
|---|---|---|---|---|---|
| FR-A-001 | 🟡 | main.dart Migrations-Force-Clear-Workaround | 🔴 OFFEN | — | Root-Cause-Refactor; nicht in PHASE6 |
| FR-A-002 | 🔴 | Pre-Migration-Backup ohne sauberen Rollback | ✅ DONE | f635de3 | partial-ZIP wird gelöscht |
| FR-A-003 | 🟡 | SafeTableRebuild Idempotenz-Lücke | 🔴 OFFEN | — | Spot-Check: kein `DROP IF EXISTS ${name}_new` Preflight |
| FR-A-004 | 🟡 | Migrationen v40–v43 nicht idempotent | 🔴 OFFEN | — | kein gezielter Commit |
| FR-A-005 | 🟡 | Version-Gap v21–v34 | 🔴 OFFEN | — | nicht adressiert |
| FR-A-006 | 🔴 | attemptRepair: execute statt rawQuery | ✅ DONE | c3e967f | Stage 1 Fix |
| FR-A-007 | 🔴 | Hardcoded Android-Pfad Emergency-Backup | ✅ DONE | 7ff7d1b, df9d552, 6fb36e1 (= H10) | platform_aware + Android-Mirror |
| FR-A-008 | 🟡 | Row-Count-Decrease nur Warning | 🔴 OFFEN | — | Spot-Check: safe_table_rebuild.dart:161 immer noch nur Warning |
| FR-A-009 | 🟡 | isMigrationInProgress liefert false bei timeout | ✅ DONE | (vorhanden) | Spot-Check: version_manager.dart:253 erkennt 'timeout' Status |
| FR-A-010 | 🟡 | Migration-Timeout pro Lauf, nicht kumulativ | 🔴 OFFEN | — | nicht in PHASE6 |
| FR-A-011 | 🟡 | SchemaRegistry deckt nur v13 ab | 🟠 TEILWEISE | 2c34f8e (= H2) | v42/v43 ergänzt; v14–v41-Lücke bleibt |
| FR-A-012 | 🟡 | nested Transactions in PlantRepository.save | ✅ DONE | 8872395 (= H13) | atomic read-modify-write |
| FR-A-013 | 🟡 | PhotoRepository via `new` statt getIt | ✅ DONE | a1a1186 | RepositoryErrorHandler + interface fix |
| FR-A-014 | 🟢 | Inkonsistente RepositoryErrorHandler-Nutzung | ✅ DONE | a1a1186 | gemeinsamer Commit mit FR-A-013 |
| FR-B-001 | 🔴 | LogProvider.notifyListeners außerhalb Lock | ✅ DONE | f41afae | Stage 1 Fix |
| FR-B-002 | 🟡 | Provider-Locks halten während Reloads | 🔴 OFFEN | — | nicht adressiert |
| FR-B-003 | 🟡 | saveBatch Reload ohne Re-Check `_currentPlantId` | ✅ DONE | (vorhanden) | Spot-Check: log_provider.dart:233-235 hat Check |
| FR-B-004 | 🟡 | BackupService Future.wait ohne eagerError:false | ✅ DONE | 4156b83 | Stage 1 Fix |
| FR-B-005 | 🟡 | Foto-Import nach DB-Commit nicht atomar | 🔴 OFFEN | — | nicht in PHASE6 |
| FR-B-006 | 🔴 | Path-Traversal-Check ungenau | ✅ DONE | d7c7a4f | Stage 1 Fix |
| FR-B-007 | 🟡 | NotificationService.initialize nicht thread-safe | 🔴 OFFEN | — | nicht adressiert |
| FR-B-008 | 🟡 | reduce ohne Empty-Guard in Health/Warning | 🟠 TEILWEISE | 810e930 (= H15) | RDWC-Aggregations-Casts; Health/Warning unklar |
| FR-B-009 | 🟡 | LogService Date-Fallbacks ohne Log | 🟠 TEILWEISE | (= M2) | als bewusste Entscheidung dokumentiert |
| FR-B-010 | 🟡 | RawDbfParser ohne Bounds-Check | ✅ DONE | febcbe7 | Stage 1 Fix |
| FR-B-011 | 🟢 | Notification ohne Interval-Validation | ✅ DONE | 709d61c | Stage 1 Fix |
| FR-B-012 | 🟡 | DatabaseRebuildService ohne Timeout | ✅ DONE | 3d4f087 | Stage 1 Fix |
| FR-B-013 | 🟢 | NotificationService ohne Platform-Fallback | ✅ DONE | 709d61c | gemeinsamer Commit mit FR-B-011 |
| FR-B-014 | 🟡 | LogService _validatePhotos TOCTOU | 🔴 OFFEN | — | nicht adressiert |
| FR-C-001 | — | (zurückgezogen) | n/a | — | VC-001-KOR |
| FR-C-002 | 🔴 | Reset ohne Double-Confirmation | ✅ DONE | 9a5b200, 7b1386b, 02719f2, edf2762 | Stage 1 Fix + Follow-ups |
| FR-C-003 | 🔴 | setState nach await ohne mounted | ✅ DONE | d8dca36, 1279ac5, c225567, 67bcdbf, 4ca747a | = K4/K5/H1 + S2-FC-001..006 |
| FR-C-004 | 🟡 | edit_plant_screen ohne dispose | ✅ DONE | 1279ac5 | Stage 3 |
| FR-C-005 | 🟡 | hardware.dart wattage! auf nullable | ✅ DONE | (vorhanden) | Spot-Check: null-Guards (Z.432/442) vor `!`-Zugriffen |
| FR-C-006 | 🟡 | edit_plant_screen unsichere Casts | ✅ DONE | db4d97e | P6 Fix |
| FR-C-007 | 🟡 | weightLossPercentage liefert 0.0 bei Bad-Data | ✅ DONE | db4d97e | P6 Fix |
| FR-C-008 | 🟡 | NutrientCalculationConfig Magic Numbers | 🔴 OFFEN | — | nicht adressiert |
| FR-C-009 | 🟡 | parseEnum silent Fallback | 🟠 TEILWEISE | (= M2) | dokumentiert als bewusst trivial; Enum/DateTime loggen |
| FR-C-010 | 🟡 | Dashboard Future.wait ohne Per-Future-Handling | ✅ DONE | db4d97e, 154246d (= H8) | safeCount + per-future failure isolation |
| FR-C-011 | 🟡 | Splash 10-min-Timeout ohne Retry | 🔴 OFFEN | — | nicht adressiert |
| FR-C-012 | 🟡 | app_logger PII-Risiko | ✅ DONE | f999140 | PII truncation |
| FR-C-013 | 🟡 | npkRatio Division-by-Zero | ✅ DONE | (vorhanden) | Spot-Check: `where(>0)` + `?? 1` Fallback + 0:0:0-Guard |
| FR-C-014 | 🟡 | _importData ohne ZIP-Preflight | 🔴 OFFEN | — | nicht adressiert |
| FR-C-015 | 🟡 | Reset-Backup-Pfad nicht prominent | ✅ DONE | f999140 | backup path dialog |
| FR-C-016 | 🟢 | Enums ohne unknown-Marker | 🔴 OFFEN | — | nicht adressiert |
| FR-C-017 | 🟢 | containerInfo kryptische Fallback-Meldung | 🔴 OFFEN | — | nicht adressiert |
| FR-C-018 | 🟢 | PPM-Scale-Konstanten dupliziert | 🔴 OFFEN | — | nicht adressiert |
| FR-C-019 | 🟡 | UnitConverter.ppmToEc ohne Division-Guard | ✅ DONE | (vorhanden) | Spot-Check: `conversionFactor` ist Konstante (500/700/640) |
| FR-X-001 | 🟡 | main.dart unawaited save bei paused | ✅ DONE | 94d1fa3 | Stage 1 Fix |
| FR-X-002 | 🟡 | _loadSettings schluckt Exception | ✅ DONE | 94d1fa3 | gemeinsamer Commit mit FR-X-001 |
| FR-X-003 | 🟡 | Settings-State-Pattern-Inkonsistenz | 🔴 OFFEN | — | strukturelles Refactor |
| FR-X-004 | 🟢 | flutter_riverpod in dev_dependencies | 🔴 OFFEN | — | nicht adressiert |
| QA-001 | 🟡 | Stuck-Migration FORCE-CLEAR Race | 🔴 OFFEN | — | siehe FR-A-001 |
| QA-002 | 🔴 | Emergency-Backup-Garantie fehlt | 🟠 TEILWEISE | 7ff7d1b, df9d552 | Pfad gefixt; Result-Typ statt String-Match offen |
| QA-003 | 🟡 | Plant-Delete verwaiste Foto-Dateien | ✅ DONE | 67bcdbf (= K2) | Two-Phase-Delete |
| QA-004 | 🟡 | Foto-Race zwischen Auswahl und Commit | 🔴 OFFEN | — | nicht adressiert |
| QA-005 | 🟡 | Dünger-Mengen ohne Unit-Konsistenz | 🔴 OFFEN | — | nicht adressiert |
| QA-006 | 🟡 | Harvest curing/quality ohne mounted | ✅ DONE | 4ca747a (= H1) | im H1-Sweep enthalten |
| QA-007 | 🟡 | Harvest-Phase Validation fehlt | 🔴 OFFEN | — | nicht adressiert |
| QA-008 | 🟡 | RDWC-Addback-Form Validation | 🔴 OFFEN | — | nicht adressiert |
| QA-009 | 🟡 | rdwc_analytics Future.wait ohne Isolation | 🟠 TEILWEISE | 154246d (= H8) | Dashboard adressiert; Analytics-Screen unklar |
| QA-010 | 🟡 | Backup-Storage-Check zu grob | ✅ DONE | f999140 | storage check warning |
| QA-011 | 🟡 | Restore Foto-Pfade ohne Rebase | ✅ DONE | f999140, 275f237 (= K8) | photo path rebase + per-id |
| QA-012 | 🔴 | DatabaseRebuildService ohne FK-Preflight | ✅ DONE | 5907a30 | FK violation preflight scan |
| QA-013 | 🟢 | Notification ohne Timezone-Override | 🔴 OFFEN | — | nicht adressiert |
| QA-014 | 🟢 | Notification-Permission nicht bei Resume | ✅ DONE | 8dd2f44, 810e930 (= H14) | re-check on resume + catchError |
| QA-015 | 🟡 | DBF-Import Duplicate-Resolution | 🔴 OFFEN | — | nicht adressiert |
| VC-001-KOR | 🔴 | FR-C-001 falsch-positiv | ✅ DONE | (Findings-File) | als zurückgezogen markiert |
| VC-002-KOR | 🟡 | FR-A-006 unpräzise | ✅ DONE | (Findings-File) | präzisiert in Abschnitt 4.4 |
| VC-003-KON | 🟢 | QA-011 zu hoch eingestuft | ✅ DONE | (Findings-File) | Major statt Blocker |
| VC-004-VOL | 🟡 | Subagent-Verifikationslücke | ✅ DONE | 3221d53 | Stage-2-Review hat Blocker direkt verifiziert |
| VC-005-VOL | 🟢 | Schema-Version unverifiziert | ✅ DONE | 1a48391 | test DB auf v41 aligned |
| VC-006-KOR | 🟡 | remaining.every leer = true | ✅ DONE | ea94706 | D-001 Auto-Archive Guard |
| VC-007-VOL | 🟢 | Provider-Refresh nach Auto-Archive | ✅ DONE | c225567 | mounted-Guards + provider refresh |
| S2-FC-001 | 🔴 | manual_recovery setState ohne mounted | ✅ DONE | d8dca36 | Stage 2 |
| S2-FC-002 | 🔴 | plant_photo_gallery setState ohne mounted | ✅ DONE | d8dca36 | Stage 2 |
| S2-FC-003 | 🟡 | harvest_detail _loadHarvest ohne mounted | ✅ DONE | 1279ac5 | Stage 3 |
| S2-FC-004 | 🟡 | fertilizer_dbf catch ohne mounted | ✅ DONE | 1279ac5 | Stage 3 |
| S2-FC-005 | 🟡 | splash_screen mehrere setState ohne mounted | ✅ DONE | 1279ac5 | Stage 3 |
| S2-FC-006 | 🟢 | DatePicker-Pattern in 10 Screens | ✅ DONE | c225567 | mounted guards added |

## Mapping FR/QA → PHASE6_TODO (K/H/M/N)

Sicher etabliert:

- **K2** = QA-003 (plant photo orphan cleanup)
- **K4 + H1** = FR-C-003 (Navigator.push().then mounted-check + S2-FC-001..006)
- **K5** = FR-C-003 (Sub-Aspekt: Provider-Refs vor await)
- **K8** = QA-011 (photo path rebase on restore)
- **K9** = QA-010 (iOS storage check, geparkt)
- **H2** = FR-A-011 (SchemaRegistry, partial)
- **H8** = FR-C-010 (Dashboard Future.wait), teilweise QA-009
- **H10** = FR-A-007 (path_provider statt hardcoded)
- **H13** = FR-A-012 (PlantRepository.save atomic transaction)
- **H14** = QA-014 (Notification-Permission Resume)
- **H15** = FR-B-008 (RDWC-Aggregations-Casts, partial)
- **M2** = FR-B-009 + FR-C-009 (Plant.fromMap-Fallbacks)

**Eigenfunde** (kein FR/QA-Mapping): K1, K3, K6, K7 + H3–H7, H9, H11, H12, H16
sind aus Live-Tests bzw. KRITISCH-Sprint-Eigeninitiative entstanden.

## Restarbeit für nächsten Sprint (15 OFFEN + 6 TEILWEISE)

**Migrations-Pipeline-Refactor (Major-Cluster):**
- FR-A-001 (Force-Clear Workaround → MigrationManager fix)
- FR-A-003 (SafeTableRebuild Idempotenz-Preflight)
- FR-A-004 (v40–v43 idempotent machen)
- FR-A-005 (Version-Gap v21–v34 untersuchen)
- FR-A-008 (Row-Count-Decrease als throw+rollback statt Warning)
- FR-A-010 (Migration-Timeout kumulativ)
- FR-A-011 (Schema-Versionen v14–v41 nachreichen)

**Concurrency / Race-Conditions:**
- FR-B-002 (Provider-Lock-Strategie)
- FR-B-005 (Foto-Import atomar mit DB-Commit)
- FR-B-007 (NotificationService.initialize thread-safe)
- FR-B-014 (LogService _validatePhotos TOCTOU)
- QA-001 (Stuck-Migration Race, = FR-A-001)
- QA-004 (Foto-Race Auswahl/Commit)

**State / Pattern:**
- FR-X-003 (Settings-State-Vereinheitlichung)
- FR-X-004 (flutter_riverpod von dev_deps in deps)
- M10/N2 (`.then()` vs `await` Stil-Mix übergreifend)
- M11 (DT-Token Drift)

**Validation / UX:**
- FR-C-008 (NutrientCalculationConfig Konstanten)
- FR-C-011 (Splash Retry statt 10-min-Timeout)
- FR-C-014 (ZIP-Preflight bei Import)
- FR-C-016/017/018 (Enum-Marker, container Fallback, PPM-Konstanten)
- QA-005/007/008/013/015 (Dünger-Units, Harvest-Validation, RDWC-Form, Timezone, DBF-Duplicates)

**Teilweise erledigt — Restscope:**
- FR-A-011 (H2): v14–v41 ergänzen
- FR-B-008 (H15): Health/Warning-Reduce noch zu prüfen
- FR-B-009/FR-C-009 (M2): aktuell als "bewusst" — wenn das nicht reicht, vollständig loggen
- QA-002: String-Match → Enum-Result für Backup-Garantie
- QA-009 (H8): rdwc_analytics-Screen explizit prüfen

## Verifikation Stand 2026-05-05

- `flutter analyze` clean (laut PHASE6_TODO 2026-05-03)
- `flutter test` 643/643 grün (laut PHASE6_TODO 2026-05-03)
- App **nicht** auf Pixel 9a getestet — TODO vor Release-Cut
