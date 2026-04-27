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

import 'package:integration_test/integration_test.dart';

import 'flows/room_flow_test.dart';
import 'flows/grow_flow_test.dart';
import 'flows/plant_flow_test.dart';
import 'flows/harvest_flow_test.dart';
import 'flows/settings_flow_test.dart';
import 'flows/error_cases_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Flows laufen sequenziell, DB-State akkumuliert sich (Emulator-Datenbank)
  roomFlowTests();
  growFlowTests();
  plantFlowTests();
  harvestFlowTests();
  settingsFlowTests();
  errorCasesTests();
}
