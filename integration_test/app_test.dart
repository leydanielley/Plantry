// =============================================
// GROWLOG – Integration Test Suite
// Alle UI-Flows + Fehleingaben
//
// Ausführen:
//   flutter test integration_test/app_test.dart -d <device-id>
//
// Einzelner Flow:
//   flutter test integration_test/app_test.dart -d <device-id> --name "Room Flow"
// =============================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'flows/room_flow_test.dart';
import 'flows/grow_flow_test.dart';
import 'flows/plant_flow_test.dart';
import 'flows/harvest_flow_test.dart';
import 'flows/settings_flow_test.dart';
import 'flows/error_cases_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Reset state once before the entire suite. Keeps the per-flow
  // dependency (Plant → Harvest) intact, but guarantees deterministic
  // start state for re-runs.
  setUpAll(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'growlog.db'));
    if (await dbFile.exists()) await dbFile.delete();
  });

  // Flows laufen sequenziell, DB-State akkumuliert sich (Emulator-Datenbank)
  roomFlowTests();
  growFlowTests();
  plantFlowTests();
  harvestFlowTests();
  settingsFlowTests();
  errorCasesTests();
}
