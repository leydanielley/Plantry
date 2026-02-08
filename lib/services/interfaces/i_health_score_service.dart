// =============================================
// GROWLOG - HealthScoreService Interface
// =============================================

import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/health_score.dart';

abstract class IHealthScoreService {
  /// Calculate health score for a plant
  Future<HealthScore> calculateHealthScore(Plant plant);
}
