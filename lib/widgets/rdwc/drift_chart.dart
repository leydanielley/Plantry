// =============================================
// GROWLOG - RDWC Drift Chart Widget
// =============================================

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
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
              return FlLine(
                // ✅ FIX: Replace force unwrap with null-aware operator
                color: isDark
                    ? (Colors.grey[800] ?? Colors.grey)
                    : (Colors.grey[300] ?? Colors.grey),
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
                color: Colors.green,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withValues(alpha: 0.1),
                ),
              ),
          ],
          // Zero line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 0,
                // ✅ FIX: Replace force unwrap with null-aware operator
                color: isDark
                    ? (Colors.grey[700] ?? Colors.grey)
                    : (Colors.grey[400] ?? Colors.grey),
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
                      color: Colors.white,
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No drift data yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
