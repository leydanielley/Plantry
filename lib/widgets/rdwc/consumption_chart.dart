// =============================================
// GROWLOG - RDWC Consumption Chart Widget
// =============================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/unit_converter.dart';
import '../../models/app_settings.dart';

class ConsumptionChart extends StatelessWidget {
  final Map<String, dynamic> dailyConsumption; // date -> liters
  final double averageConsumption;
  final AppSettings settings;

  const ConsumptionChart({
    super.key,
    required this.dailyConsumption,
    required this.averageConsumption,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyConsumption.isEmpty) {
      return _buildEmptyState(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = dailyConsumption.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2),
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = entries[groupIndex].key;
                final value = entries[groupIndex].value;
                final formatted = UnitConverter.formatVolume(value, settings.volumeUnit);
                return BarTooltipItem(
                  '$date\n$formatted',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= entries.length) return const Text('');
                  final date = entries[value.toInt()].key;
                  // Show day only (e.g., "Mon", "Tue")
                  final dayOfWeek = DateTime.parse(date).weekday;
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[dayOfWeek - 1],
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    UnitConverter.formatVolume(value, settings.volumeUnit),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2) / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: entries.asMap().entries.map((entry) {
            final index = entry.key;
            final consumption = entry.value.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: consumption,
                  color: Colors.blue,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: (entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.2),
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ],
            );
          }).toList(),
          // Average line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: averageConsumption,
                color: Colors.orange,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  labelResolver: (line) => 'Avg: ${UnitConverter.formatVolume(averageConsumption, settings.volumeUnit)}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No consumption data yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
