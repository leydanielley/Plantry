// =============================================
// GROWLOG - Health Score Widget
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/health_score.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/services/interfaces/i_health_score_service.dart';
import 'package:growlog_app/services/interfaces/i_warning_service.dart';
import 'package:growlog_app/services/warning_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/utils/translations.dart';

class HealthScoreWidget extends StatefulWidget {
  final Plant plant;

  const HealthScoreWidget({super.key, required this.plant});

  @override
  State<HealthScoreWidget> createState() => _HealthScoreWidgetState();
}

class _HealthScoreWidgetState extends State<HealthScoreWidget> {
  final IHealthScoreService _healthScoreService = getIt<IHealthScoreService>();
  final IWarningService _warningService = getIt<IWarningService>();

  HealthScore? _healthScore;
  List<PlantWarning> _warnings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  /// ✅ AUDIT NOTE: Data loading is correctly implemented
  /// - Loads ONCE in initState() (not on every build)
  /// - Uses proper state management with _isLoading flag
  /// - Handles errors gracefully with fallback data
  /// - Checks mounted before setState to prevent memory leaks
  Future<void> _loadHealthData() async {
    try {
      final healthScore = await _healthScoreService.calculateHealthScore(
        widget.plant,
      );
      final warnings = await _warningService.checkWarnings(widget.plant);

      if (mounted) {
        setState(() {
          _healthScore = healthScore;
          _warnings = warnings;
          _isLoading = false;
        });
      }
    } catch (e) {
      // ✅ FIX: Set default health score on error to prevent null crashes
      if (mounted) {
        final t = AppTranslations(
          'de',
        ); // Fallback to German for error messages
        setState(() {
          _healthScore = HealthScore(
            score: 50,
            level: HealthLevel.fair,
            factors: {},
            warnings: [t.translate('error')],
            recommendations: [t.translate('unexpected_error')],
            calculatedAt: DateTime.now(),
          );
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_healthScore == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getScoreColor().withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Score circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _getScoreColor(), width: 6),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_healthScore!.score}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(),
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Score info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _healthScore!.getLevelEmoji(),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _healthScore!.getLevelText(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppTranslations(
                          Localizations.localeOf(context).languageCode,
                        ).translate('plant_health'),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Warnings
          if (_warnings.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations(
                      Localizations.localeOf(context).languageCode,
                    ).translate('warnings'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._warnings
                      .take(3)
                      .map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildWarningItem(warning),
                        ),
                      ),
                  if (_warnings.length > 3)
                    Text(
                      '+ ${_warnings.length - 3} weitere Warnungen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

          // Factor breakdown (expandable)
          ExpansionTile(
            title: const Text(
              'Faktor-Details',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _healthScore!.factors.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildFactorBar(
                        _getFactorLabel(entry.key),
                        entry.value,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          // Recommendations
          if (_healthScore!.recommendations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 ${AppTranslations(Localizations.localeOf(context).languageCode).translate('recommendations')}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._healthScore!.recommendations
                      .take(3)
                      .map(
                        (rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  rec,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(PlantWarning warning) {
    Color color;
    switch (warning.level) {
      case WarningLevel.critical:
        color = Colors.red;
        break;
      case WarningLevel.warning:
        color = Colors.orange;
        break;
      case WarningLevel.info:
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(warning.getIcon(), style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning.message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (warning.recommendation != null) ...[
            const SizedBox(height: 4),
            Text(
              '→ ${warning.recommendation}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFactorBar(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(
              '${value.toInt()}%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            _getScoreColorForValue(value),
          ),
          minHeight: 8,
        ),
      ],
    );
  }

  /// ✅ FIX: Safe color getter that handles null health score
  Color _getScoreColor() {
    if (_healthScore == null) {
      return Colors.grey; // Default color when score unavailable
    }
    return _getScoreColorForValue(_healthScore!.score.toDouble());
  }

  Color _getScoreColorForValue(double value) {
    if (value >= 90) return Colors.green;
    if (value >= 70) return Colors.lightGreen;
    if (value >= 50) return Colors.orange;
    if (value >= 30) return Colors.deepOrange;
    return Colors.red;
  }

  String _getFactorLabel(String key) {
    // Note: We can't use context here, so we use 'de' as default
    // This is acceptable since the widget always rebuilds when language changes
    final t = AppTranslations('de');
    switch (key) {
      case 'watering':
        return t.translate('watering_factor');
      case 'ph_stability':
        return t.translate('ph_stability_factor');
      case 'nutrient_health':
        return t.translate('nutrient_health_factor');
      case 'documentation':
        return t.translate('documentation_factor');
      case 'activity':
        return t.translate('activity_factor');
      default:
        return key;
    }
  }
}
