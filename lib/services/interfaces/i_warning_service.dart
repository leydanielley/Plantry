// =============================================
// GROWLOG - WarningService Interface
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/services/warning_service.dart';

abstract class IWarningService {
  /// Check for all warnings for a plant
  Future<List<PlantWarning>> checkWarnings(Plant plant);
}
