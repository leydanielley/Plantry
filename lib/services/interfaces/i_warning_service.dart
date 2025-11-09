// =============================================
// GROWLOG - WarningService Interface
// =============================================

import '../../models/plant.dart';
import '../warning_service.dart';

abstract class IWarningService {
  /// Check for all warnings for a plant
  Future<List<PlantWarning>> checkWarnings(Plant plant);
}
