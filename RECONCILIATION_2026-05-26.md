# Findings-Reconciliation — Stand 2026-05-26

Update der `RECONCILIATION_2026-05-05.md` nach den Sweeps:

- `d5400cb` (2026-05-06) — Migrations / Concurrency / State / Validation
- `3b5bbe9` (2026-05-17) — gleicher Zielcluster, finale Welle
- `17795b5` (2026-05-25, PR #8) — VC-008, VC-009, M10/N2, M11
- `fe51e5b` (2026-05-25) — Gradle-Properties Pin (Flutter-Migrator-Opt-outs)
- `5beb33c` (2026-05-25, PR #9) — **QA-007** Harvest-Phase-Validation
- `f23e0e2` (2026-05-25, PR #10) — **QA-002** Result-Typ Emergency-Backup
- `ffc1d99` (2026-05-26, PR #11/1) — **FR-B-014** `_validatePhotos` unter Lock
- `c13b124` (2026-05-26, PR #11/2) — **FR-B-005 / QA-004** atomare Photo-Staging

Code-Verifikation gegen HEAD `c13b124` durch eine Explore-Subagent-Pass (siehe Chat-Transkript dieses Sweeps).

## Bilanz

| Status | Count |
|---|---|
| ✅ DONE | 32 |
| 🟠 TEILWEISE | 2 (Cluster) / 4 (IDs) |
| 🔴 OFFEN (= tracked als Issue) | 2 (Cluster) / 3 (IDs) |

## Was sich gegenüber 2026-05-05 geändert hat

**🔴 OFFEN → ✅ DONE:**

- **QA-007** (Harvest-Phase-Validation) — `lib/services/harvest_service.dart` + `i_harvest_service.dart`: `HarvestPhase`-Enum aus Date-Feldern abgeleitet, `validateTransition(from, to)`-Predicate, `updateHarvestWithValidation`-API, typed `HarvestTransitionException`. 24 neue Tests. **Follow-up:** UI-Wiring der Harvest-Screens auf die neue Service-API steht aus.

**🟠 TEILWEISE → ✅ DONE:**

- **QA-002** (Emergency-Backup Result-Typ) — `lib/database/database_recovery.dart::exportToJSON` returnt jetzt `Future<BackupResult>` (`BackupSuccess` / `BackupSkipped` / `BackupFailure`); Recovery löscht DB nur noch nach echtem Success-Path. Sealed-Class-Pattern matched bestehendes `AsyncValue`. (Scope-Korrektur: der fragile Punkt saß in `database_recovery.dart`, nicht in `backup_service.dart` wie ursprünglich notiert.)
- **FR-B-014** (`_validatePhotos` TOCTOU) — Validation läuft jetzt unter dem bestehenden `_lock` (synchronized-Package) in `lib/services/log_service.dart`; das Time-of-Check-Time-of-Use-Fenster ist geschlossen.
- **FR-B-005 / QA-004** (atomare Photo-Commit) — Photo-Import staged jetzt nach `.staging/<runId>/` unter `documents/photos/`, DB-Insert läuft unter Lock, bei Success FS-Rename in finalen Pfad, bei DB-Failure Cleanup + Re-throw. `cleanStalePhotoStaging()` als Best-Effort-Reaper für Crashes mid-save. **Follow-up:** Targeted Tests für die Staging-Pfade fehlen (der `_docsDirOverride`-Hook ist dafür drin) — empfohlen vor next Release.

## Restarbeit

### 🟠 TEILWEISE (2 Cluster, 4 IDs) — bewusste Entscheidungen, keine Issues

- **FR-A-005 / FR-A-011** — Schema-Registry v14–v44 ist komplett gemapped, aber v21–v34 sind Platzhalter die von v20 erben statt eigener Definitionen. Pragmatisch ok für historische Legacy-Range; eine "echte" Erfassung würde Schema-Archäologie verlangen. Status bleibt PARTIAL by design.
- **FR-B-009 / FR-C-009 (= M2)** — Date-/Enum-Fallbacks in `plant.dart::fromMap` loggen via `SafeParsers.parseEnum(..., logOnFallback: true)`. Dokumentiert als bewusste Entscheidung; voll erfüllbar nur durch zusätzliche structured-error-Reports.

### 🔴 OFFEN (2 Cluster, 3 IDs) — als Issues getrackt, brauchen Architektur-Entscheidung

- **FR-A-001 / QA-001** — Migrations Force-Clear-Workaround in `main.dart` → Root-Cause-Fix im `MigrationManager`. Tracked: [#12](https://github.com/leydanielley/Plantry/issues/12). Datenverlust-kritischer Refactor, braucht human review + Manual-Recovery-Verifikation auf echtem Gerät.
- **FR-X-003** — Settings-State-Pattern-Vereinheitlichung (ChangeNotifier + GetIt analog zu anderen Providern). Tracked: [#13](https://github.com/leydanielley/Plantry/issues/13). Cross-Cutting-Refactor, braucht Provider-API-Design + Settings-Roundtrip-Tests auf Gerät.

## Verifikation Stand 2026-05-26

- `flutter analyze` clean (16 preexisting infos/warnings auf main, alle nicht-blocking, dokumentiert)
- `flutter test` 673/673 grün (Stand nach PR #9 + #10 merge; PR #11 hat keine Regressionen, neue Tests siehe Follow-up)
- App startet sauber auf Pixel 7 API 35 Emulator (Smoke-Test 2026-05-25)

## Mapping zu vorherigem Stand

Siehe `RECONCILIATION_2026-05-05.md` für die historischen Master-Eintragungen aus dem externen Code-Review vom 21.04.2026 und das Mapping zu `PHASE6_TODO.md` (K/H/M/N).
