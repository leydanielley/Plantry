// =============================================
// GROWLOG - RDWC EC Trend Chart Widget
// =============================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class EcTrendChart extends StatelessWidget {
  final List<RdwcLog> logs; // pre-filtered: complete + ecAfter != null, sorted ascending
  final double? ecMin;
  final double? ecMax;

  const EcTrendChart({
    super.key,
    required this.logs,
    this.ecMin,
    this.ecMax,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Noch keine EC-Daten', style: TextStyle(color: DT.textSecondary, fontSize: 13)),
      );
    }

    final spots = logs.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.ecAfter!))
        .toList();

    // Y range — include target lines in range
    final yValues = spots.map((s) => s.y).toList();
    if (ecMin != null) yValues.add(ecMin!);
    if (ecMax != null) yValues.add(ecMax!);
    final minY = yValues.reduce(min) - 0.3;
    final maxY = yValues.reduce(max) + 0.3;

    // Horizontal target lines
    final hLines = <HorizontalLine>[];
    if (ecMin != null) {
      hLines.add(HorizontalLine(
        y: ecMin!,
        color: DT.success,
        strokeWidth: 1.5,
        dashArray: [6, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          labelResolver: (_) => 'Min ${ecMin!.toStringAsFixed(1)}',
          style: const TextStyle(color: DT.success, fontSize: 9),
        ),
      ));
    }
    if (ecMax != null) {
      hLines.add(HorizontalLine(
        y: ecMax!,
        color: DT.warning,
        strokeWidth: 1.5,
        dashArray: [6, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 4, bottom: 2),
          labelResolver: (_) => 'Max ${ecMax!.toStringAsFixed(1)}',
          style: const TextStyle(color: DT.warning, fontSize: 9),
        ),
      ));
    }

    // Vertical lines for full-change events
    final vLines = logs.asMap().entries
        .where((e) => e.value.logType == RdwcLogType.fullChange)
        .map((e) => VerticalLine(
              x: e.key.toDouble(),
              color: DT.secondary.withValues(alpha: 0.6),
              strokeWidth: 1.5,
              dashArray: [4, 4],
            ))
        .toList();

    // X-axis interval — show ~5 labels max
    final xInterval = max(1.0, (logs.length / 5).floorToDouble());

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: DT.info,
              barWidth: 2.5,
              dotData: FlDotData(show: logs.length <= 30),
              belowBarData: BarAreaData(
                show: true,
                color: DT.info.withValues(alpha: 0.08),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: hLines,
            verticalLines: vLines,
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: xInterval,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= logs.length) return const Text('');
                  final date = logs[index].logDate;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('d.M').format(date),
                      style: const TextStyle(fontSize: 9, color: DT.textSecondary),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 9, color: DT.textSecondary),
                ),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: DT.elevated, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= logs.length) return null;
                final log = logs[index];
                return LineTooltipItem(
                  'EC: ${log.ecAfter!.toStringAsFixed(2)}\n${DateFormat('dd.MM HH:mm').format(log.logDate)}',
                  const TextStyle(color: DT.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
