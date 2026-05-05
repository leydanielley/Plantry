# Phase 6 — Code-Review Backlog

Stand: 2026-05-05 — KRITISCH + HOCH komplett, MITTEL/NIEDRIG durch (außer
übergreifende Stil-Themen). Externe Review-Findings (FR-/QA-IDs) sind separat
in [`FLUTTER_REVIEW_FINDINGS.md`](./FLUTTER_REVIEW_FINDINGS.md) status-getrackt
und konsolidiert in [`RECONCILIATION_2026-05-05.md`](./RECONCILIATION_2026-05-05.md).

## ✅ KRITISCH — alle erledigt (außer K9, geparkt)

- **K1** — RDWC `as double` Force-Cast → safe cast (`rdwc_repository.dart:720, 809`)
- **K2** — Two-Phase-Delete in `plant_repository.deletePermanently()`
- **K3** — Notification-ID Overflow defensive `assert()`
- **K4** — 13 Stellen `Navigator.push().then()` mit mounted-Check
- **K5** — `add_harvest_screen` Provider-References vor await capturen
- **K6** — `SafeParsers.parseUserDouble()` ausgerollt in 6 Screens (~20 Stellen)
- **K7** — `permission_helper`: PlatformException → false + Dialog (cancel ≠ denied)
- **K8** — Backup-Restore: photo path rebase per ID statt SQL LIKE
- **K9** — iOS hasEnoughStorage: **GEPARKT** (Android-only Build, nicht akut)

## ✅ HOCH — alle erledigt (Sprint 2 abgeschlossen)

- **H1** — Navigator.push state-mutation mit mounted-Check (14 Screens)
- **H2** — Schema-Versionen v42/v43 nachgereicht + `minRequiredSchemaVersion` Pre-Flight
- **H3** — Down-Migrations werfen jetzt `UnsupportedError` statt silent no-op
- **H4** — Image cache Byte-Counter Self-Heal + Lock
- **H5** — Backup-Logs nutzen `path.basename` statt absolute Pfade
- **H6** — FK Re-Enable nach Import-Fail loggt jetzt
- **H7** — Migration-Manager Cleanup-Catch loggt jetzt
- **H8** — Dashboard `Future.wait` mit per-Future `safeCount`
- **H9** — SplashScreen Stream-Listen mit `onError`
- **H10** — Emergency-Backup nutzt `getExternalStorageDirectory()` statt hardcoded
- **H11** — `_formKey.currentState!` → null-safe `?` in 24 Screens
- **H12** — NotificationHelper per-Reminder Try-Catch + Summary-Log
- **H13** — PlantRepository.save() atomare Read-Modify-Write Transaction
- **H14** — Notification-Settings resume `requestPermissions().catchError`
- **H15** — Aggregations-Casts in rdwc_repository als `as num?`
- **H16** — RDWC bidirektionale FK Sync in `RoomRepository.save()` (Bug C aus Live-Test)

## ✅ MITTEL — Sprint 3 abgearbeitet/dokumentiert

- **M1** — Faktisch durch H2 abgedeckt (`minRequiredSchemaVersion` Pre-Flight)
- **M2** — Plant.fromMap-Fallbacks: Enum/DateTime loggen via SafeParsers,
  trivial-Defaults (name, feminized) bewusst ohne Log (wäre nur Noise)
- **M3** — `getIt.reset(dispose: true)` für Resource-Cleanup
- **M4** — RDWC `archived_at` Timestamp + Schema-Migration v44 (`b9fd0f9`)
- **M5** — ✅ Schon in K5 erledigt
- **M6** — Verschachtelte try/catch im migration_manager: bewusst (defensiv,
  vergleichbar mit Try-Each-Reminder Pattern)
- **M7** — add_fertilizer Error-Handler: zeigt schon SnackBar (war im Review veraltet)
- **M8** — Batch-Photo-Restore Error-Distinction: ist da (not-found / copy-failed / no-id)
- **M9** — main.dart `.catchError` ohne rethrow: bewusst, ist `unawaited` mit Log
- **M10** — `.then()` vs `await` Stil-Mix: **OFFEN** (übergreifender Stil-Refactor)
- **M11** — DT-Tokens Theme-Drift: **OFFEN** (übergreifend)
- **M12** — `_phase = PlantPhase.seedling` final → static const (`c3ac470`)
- **M13** — ✅ Pattern dokumentiert

## ✅ NIEDRIG — abgearbeitet/dokumentiert

- **N1** — Hardcoded 'Pflanze bearbeiten' → `_t['edit_plant_title']`
- **N2** — `.then()` vs `await` Stylings: **OFFEN** (= M10)
- **N3** — ✅ Dead `??` in add_harvest_screen entfernt

## Noch offen (intern)
- **K9** (iOS storage check, geparkt bis iOS-Build relevant)
- **M10/N2** (.then vs await Stil-Mix übergreifend)
- **M11** (DT-Token Drift übergreifend)

## Externer Review — Restarbeit (siehe RECONCILIATION_2026-05-05.md)
Stand 2026-05-05: 46 DONE, 6 TEILWEISE, 15 OFFEN von 75 Findings.

**Kernthemen offen:**
- Migrations-Pipeline-Refactor (FR-A-001/003/004/005/008/010 + Rest H2)
- Concurrency / Race-Conditions (FR-B-002/005/007/014, QA-001/004)
- State-Pattern-Vereinheitlichung (FR-X-003/004)
- Validation/UX (FR-C-008/011/014/016/017/018, QA-005/007/008/013/015)

## Verifikation Stand 2026-05-05
- `flutter analyze` clean (laut Vorstand 2026-05-03)
- `flutter test` 643/643 grün (laut Vorstand 2026-05-03)
- App nicht auf Pixel 9a getestet — TODO vor jedem Release-Cut
