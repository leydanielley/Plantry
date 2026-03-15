import 'package:growlog_app/database/migrations/migration.dart';

final migrationV42 = Migration(
  version: 42,
  description: 'RDWC: Add log_status to rdwc_logs, ec_warning_min/max to rdwc_systems',
  up: (db) async {
    // rdwc_logs: log_status ('complete' | 'pending_measurement')
    final logCols = await db.rawQuery('PRAGMA table_info(rdwc_logs)');
    final logColNames = logCols.map((r) => r['name'] as String).toList();
    if (!logColNames.contains('log_status')) {
      await db.execute(
        "ALTER TABLE rdwc_logs ADD COLUMN log_status TEXT NOT NULL DEFAULT 'complete'",
      );
    }

    // rdwc_systems: ec_warning_min / ec_warning_max (nullable)
    final sysCols = await db.rawQuery('PRAGMA table_info(rdwc_systems)');
    final sysColNames = sysCols.map((r) => r['name'] as String).toList();
    if (!sysColNames.contains('ec_warning_min')) {
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN ec_warning_min REAL');
    }
    if (!sysColNames.contains('ec_warning_max')) {
      await db.execute('ALTER TABLE rdwc_systems ADD COLUMN ec_warning_max REAL');
    }
  },
  down: (db) async {
    // SQLite doesn't support DROP COLUMN easily — left intentionally empty
  },
);
