// =============================================
// GROWLOG - HealthScoreService Interface
// =============================================

import '../../models/plant.dart';
import '../../models/health_score.dart';

abstract class IHealthScoreService {
  /// Calculate health score for a plant
  Future<HealthScore> calculateHealthScore(Plant plant);
}
