// =============================================
// GROWLOG - Health Score Model
// =============================================

enum HealthLevel {
  excellent, // 90-100
  good, // 70-89
  fair, // 50-69
  poor, // 30-49
  critical, // 0-29
}

class HealthScore {
  // ✅ AUDIT FIX: Extract magic numbers for health score thresholds
  static const int thresholdExcellent = 90;
  static const int thresholdGood = 70;
  static const int thresholdFair = 50;
  static const int thresholdPoor = 30;
  static const int minScore = 0;
  static const int maxScore = 100;

  final int score; // 0-100
  final HealthLevel level;
  final Map<String, double> factors;
  final List<String> warnings;
  final List<String> recommendations;
  final DateTime calculatedAt;

  HealthScore({
    required this.score,
    required this.level,
    required this.factors,
    required this.warnings,
    required this.recommendations,
    required this.calculatedAt,
  });

  static HealthLevel getLevelFromScore(int score) {
    if (score >= thresholdExcellent) return HealthLevel.excellent;
    if (score >= thresholdGood) return HealthLevel.good;
    if (score >= thresholdFair) return HealthLevel.fair;
    if (score >= thresholdPoor) return HealthLevel.poor;
    return HealthLevel.critical;
  }

  String getLevelText() {
    switch (level) {
      case HealthLevel.excellent:
        return 'Exzellent';
      case HealthLevel.good:
        return 'Gut';
      case HealthLevel.fair:
        return 'Mittel';
      case HealthLevel.poor:
        return 'Schlecht';
      case HealthLevel.critical:
        return 'Kritisch';
    }
  }

  String getLevelEmoji() {
    switch (level) {
      case HealthLevel.excellent:
        return '🌟';
      case HealthLevel.good:
        return '💚';
      case HealthLevel.fair:
        return '🟡';
      case HealthLevel.poor:
        return '🟠';
      case HealthLevel.critical:
        return '🔴';
    }
  }
}
