// =============================================
// GROWLOG - RDWC Drift Chart Widget
// =============================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class DriftChart extends StatelessWidget {
  final List<DriftDataPoint> ecData;
  final List<DriftDataPoint> phData;
  final String mode; // 'ec', 'ph', or 'both'

  const DriftChart({
    super.key,
    required this.ecData,
    required this.phData,
    this.mode = 'both',
  });

  @override
  Widget build(BuildContext context) {
    if ((mode == 'ec' && ecData.isEmpty) ||
        (mode == 'ph' && phData.isEmpty) ||
        (mode == 'both' && ecData.isEmpty && phData.isEmpty)) {
      return _buildEmptyState(context);
    }

    // Combine all data points to find min/max
    final allValues = <double>[];
    if (mode == 'ec' || mode == 'both') {
      allValues.addAll(ecData.map((d) => d.value));
    }
    if (mode == 'ph' || mode == 'both') {
      allValues.addAll(phData.map((d) => d.value));
    }

    final minY = allValues.isEmpty
        ? -1.0
        : allValues.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxY = allValues.isEmpty
        ? 1.0
        : allValues.reduce((a, b) => a > b ? a : b) + 0.5;

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final allData = mode == 'ec'
                      ? ecData
                      : (mode == 'ph' ? phData : ecData);
                  // ✅ CRITICAL FIX: Store toInt() result once to prevent TOCTOU race condition
                  final index = value.toInt();
                  if (allData.isEmpty || index >= allData.length) {
                    return const Text('');
                  }
                  final date = allData[index].date;
                  final dayOfWeek = date.weekday;
                  const days = [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[dayOfWeek - 1],
                      style: const TextStyle(
                        fontSize: 10,
                        color: DT.textSecondary,
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
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: DT.textSecondary,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 5,
            getDrawingHorizontalLine: (value) {
              return const FlLine(
                color: DT.elevated,
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // EC drift line (blue)
            if (mode == 'ec' || mode == 'both')
              LineChartBarData(
                spots: ecData.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.value);
                }).toList(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            // pH drift line (green)
            if (mode == 'ph' || mode == 'both')
              LineChartBarData(
                spots: phData.asMap().entries.map((entry) {
                  return FlSpot(entry.key.toDouble(), entry.value.value);
                }).toList(),
                isCurved: true,
                color: DT.success,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: DT.success.withValues(alpha: 0.1),
                ),
              ),
          ],
          // Zero line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: DT.textSecondary,
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final isEc =
                      spot.barIndex == 0 && (mode == 'ec' || mode == 'both');
                  final data = isEc ? ecData : phData;
                  // ✅ CRITICAL FIX: Store toInt() result once to prevent TOCTOU race condition
                  final index = spot.x.toInt();
                  if (index >= data.length) return null;

                  final point = data[index];
                  final label = isEc ? 'EC' : 'pH';
                  final value = point.value.toStringAsFixed(2);

                  return LineTooltipItem(
                    '$label: $value\n${_formatDate(point.date)}',
                    const TextStyle(
                      color: DT.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(32),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: DT.textSecondary),
            SizedBox(height: 16),
            Text(
              'No drift data yet',
              style: TextStyle(fontSize: 16, color: DT.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for drift data points
class DriftDataPoint {
  final DateTime date;
  final double value;

  DriftDataPoint({required this.date, required this.value});
}
