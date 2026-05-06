// =============================================
// GROWLOG - Placeholder Migrations v21–v34
// =============================================
//
// WHY THESE EXIST:
// The migration chain jumped from v20 to v35 during development.
// Versions v21–v34 were internal/unreleased builds that never reached
// production users. However, the canMigrate() function checks for a
// contiguous version chain — any gap causes it to return false and
// block the upgrade path for users on v20.
//
// These no-op migrations fill the gap so that canMigrate(20, 44) works
// correctly. They do not modify any schema.

import 'package:growlog_app/database/migrations/migration.dart';

Migration _noOp(int version, String reason) => Migration(
  version: version,
  description: 'Placeholder (internal build, never released): $reason',
  up: (_) async {
    // No schema changes — this version was never shipped to users.
  },
  down: (_) async {
    // No-op downgrade (corresponding up is a no-op).
  },
);

final migrationV21 = _noOp(21, 'internal build v21');
final migrationV22 = _noOp(22, 'internal build v22');
final migrationV23 = _noOp(23, 'internal build v23');
final migrationV24 = _noOp(24, 'internal build v24');
final migrationV25 = _noOp(25, 'internal build v25');
final migrationV26 = _noOp(26, 'internal build v26');
final migrationV27 = _noOp(27, 'internal build v27');
final migrationV28 = _noOp(28, 'internal build v28');
final migrationV29 = _noOp(29, 'internal build v29');
final migrationV30 = _noOp(30, 'internal build v30');
final migrationV31 = _noOp(31, 'internal build v31');
final migrationV32 = _noOp(32, 'internal build v32');
final migrationV33 = _noOp(33, 'internal build v33');
final migrationV34 = _noOp(
  34,
  'internal build v34 — superseded by v35 healing migration',
);
