// =============================================
// GROWLOG - Plant EC/pH Charts Widget
// =============================================

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class PlantChartsView extends StatelessWidget {
  /// All logs for the plant, sorted ascending by dayNumber.
  final List<PlantLog> logs;

  /// RDWC system logs — non-null means this is an RDWC plant.
  /// Pre-filtered: complete only, sorted ascending by logDate.
  final List<RdwcLog>? rdwcLogs;

  /// Plant seed date — used to calculate day numbers for RDWC logs.
  final DateTime? seedDate;

  final AppTranslations t;

  const PlantChartsView({
    super.key,
    required this.logs,
    required this.t,
    this.rdwcLogs,
    this.seedDate,
  });

  // ─── RDWC branch ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (rdwcLogs != null) {
      return _buildRdwcView();
    }
    return _buildPlantLogView();
  }

  Widget _buildRdwcView() {
    if (rdwcLogs!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            t['chart_no_rdwc_data'],
            textAlign: TextAlign.center,
            style: const TextStyle(color: DT.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRdwcInfoBanner(),
          const SizedBox(height: 16),
          _buildRdwcEcChart(),
          const SizedBox(height: 24),
          _buildRdwcPhChart(),
        ],
      ),
    );
  }

  Widget _buildRdwcInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DT.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DT.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.water, color: DT.info, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t['chart_rdwc_banner'],
              style: const TextStyle(fontSize: 12, color: DT.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRdwcEcChart() {
    final withEc = rdwcLogs!
        .where((l) => l.ecBefore != null || l.ecAfter != null)
        .toList();

    if (withEc.isEmpty) {
      return _emptyCard(t['chart_ec_reservoir_title'], t['chart_no_ec_reservoir']);
    }

    final beforeSpots = withEc
        .where((l) => l.ecBefore != null)
        .map((l) => FlSpot(_day(l.logDate).toDouble(), l.ecBefore!))
        .toList();
    final afterSpots = withEc
        .where((l) => l.ecAfter != null)
        .map((l) => FlSpot(_day(l.logDate).toDouble(), l.ecAfter!))
        .toList();

    final allY = [
      ...beforeSpots.map((s) => s.y),
      ...afterSpots.map((s) => s.y),
    ];
    final minY = (allY.reduce(min) - 0.3).clamp(0.0, double.infinity);
    final maxY = allY.reduce(max) + 0.3;

    final bars = <LineChartBarData>[
      if (afterSpots.isNotEmpty) _lineBar(afterSpots, DT.secondary, dashed: false),
      if (beforeSpots.isNotEmpty)
        _lineBar(beforeSpots, DT.warning, dashed: true),
    ];

    return _chartCard(
      title: t['chart_ec_reservoir_title'],
      legend: [
        if (afterSpots.isNotEmpty) (t['chart_ec_after_addback'], DT.secondary),
        if (beforeSpots.isNotEmpty) (t['chart_ec_before_addback'], DT.warning),
      ],
      child: _lineChartRaw(
        bars: bars,
        minY: minY,
        maxY: maxY,
        spots: [...beforeSpots, ...afterSpots],
        decimals: 1,
      ),
    );
  }

  Widget _buildRdwcPhChart() {
    final withPh = rdwcLogs!
        .where((l) => l.phBefore != null || l.phAfter != null)
        .toList();

    if (withPh.isEmpty) {
      return _emptyCard(t['chart_ph_reservoir_title'], t['chart_no_ph_reservoir']);
    }

    final beforeSpots = withPh
        .where((l) => l.phBefore != null)
        .map((l) => FlSpot(_day(l.logDate).toDouble(), l.phBefore!))
        .toList();
    final afterSpots = withPh
        .where((l) => l.phAfter != null)
        .map((l) => FlSpot(_day(l.logDate).toDouble(), l.phAfter!))
        .toList();

    final allY = [
      ...beforeSpots.map((s) => s.y),
      ...afterSpots.map((s) => s.y),
    ];
    final minY = (allY.reduce(min) - 0.2).clamp(0.0, double.infinity);
    final maxY = allY.reduce(max) + 0.2;

    final bars = <LineChartBarData>[
      if (afterSpots.isNotEmpty) _lineBar(afterSpots, DT.accent, dashed: false),
      if (beforeSpots.isNotEmpty)
        _lineBar(beforeSpots, DT.error, dashed: true),
    ];

    return _chartCard(
      title: t['chart_ph_reservoir_title'],
      legend: [
        if (afterSpots.isNotEmpty) (t['chart_ph_after_addback'], DT.accent),
        if (beforeSpots.isNotEmpty) (t['chart_ph_before_addback'], DT.error),
      ],
      child: _lineChartRaw(
        bars: bars,
        minY: minY,
        maxY: maxY,
        spots: [...beforeSpots, ...afterSpots],
        decimals: 1,
      ),
    );
  }

  int _day(DateTime date) {
    if (seedDate == null) return 1;
    final diff = date.difference(seedDate!).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  // ─── Plant-log branch ────────────────────────────────────────────────────────

  Widget _buildPlantLogView() {
    final waterFeedLogs = logs
        .where((l) =>
            l.actionType == ActionType.water ||
            l.actionType == ActionType.feed)
        .toList();

    final phaseChangeDays = logs
        .where((l) => l.actionType == ActionType.phaseChange)
        .map((l) => l.dayNumber.toDouble())
        .toList();

    if (waterFeedLogs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            t['chart_no_water_feed'],
            textAlign: TextAlign.center,
            style: const TextStyle(color: DT.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEcChart(waterFeedLogs, phaseChangeDays),
          const SizedBox(height: 24),
          _buildPhChart(waterFeedLogs, phaseChangeDays),
          const SizedBox(height: 24),
          _buildDeltaChart(waterFeedLogs),
        ],
      ),
    );
  }

  // ─── EC Chart ───────────────────────────────────────────────────────────────

  Widget _buildEcChart(List<PlantLog> logs, List<double> phaseChangeDays) {
    final ecInLogs = logs.where((l) => l.ecIn != null).toList();
    final ecOutLogs = logs.where((l) => l.ecOut != null).toList();

    if (ecInLogs.isEmpty) {
      return _emptyCard(t['chart_ec_title'], t['chart_no_ec_data']);
    }

    final inSpots =
        ecInLogs.map((l) => FlSpot(l.dayNumber.toDouble(), l.ecIn!)).toList();
    final outSpots = ecOutLogs
        .map((l) => FlSpot(l.dayNumber.toDouble(), l.ecOut!))
        .toList();

    final allY = [...inSpots.map((s) => s.y), ...outSpots.map((s) => s.y)];
    final minY = (allY.reduce(min) - 0.3).clamp(0.0, double.infinity);
    final maxY = allY.reduce(max) + 0.3;

    final bars = <LineChartBarData>[
      _lineBar(inSpots, DT.secondary, dashed: false),
      if (outSpots.isNotEmpty) _lineBar(outSpots, DT.warning, dashed: true),
    ];

    return _chartCard(
      title: t['chart_ec_title'],
      legend: [
        (t['chart_ec_in'], DT.secondary),
        if (outSpots.isNotEmpty) (t['chart_ec_out'], DT.warning),
      ],
      child: _lineChart(
        bars: bars,
        minY: minY,
        maxY: maxY,
        phaseChangeDays: phaseChangeDays,
        allLogs: logs,
        decimals: 1,
      ),
    );
  }

  // ─── pH Chart ───────────────────────────────────────────────────────────────

  Widget _buildPhChart(List<PlantLog> logs, List<double> phaseChangeDays) {
    final phInLogs = logs.where((l) => l.phIn != null).toList();
    final phOutLogs = logs.where((l) => l.phOut != null).toList();

    if (phInLogs.isEmpty) {
      return _emptyCard(t['chart_ph_title'], t['chart_no_ph_data']);
    }

    final inSpots =
        phInLogs.map((l) => FlSpot(l.dayNumber.toDouble(), l.phIn!)).toList();
    final outSpots = phOutLogs
        .map((l) => FlSpot(l.dayNumber.toDouble(), l.phOut!))
        .toList();

    final allY = [...inSpots.map((s) => s.y), ...outSpots.map((s) => s.y)];
    final minY = (allY.reduce(min) - 0.2).clamp(0.0, double.infinity);
    final maxY = allY.reduce(max) + 0.2;

    final bars = <LineChartBarData>[
      _lineBar(inSpots, DT.accent, dashed: false),
      if (outSpots.isNotEmpty) _lineBar(outSpots, DT.info, dashed: true),
    ];

    return _chartCard(
      title: t['chart_ph_title'],
      legend: [
        (t['chart_ph_in'], DT.accent),
        if (outSpots.isNotEmpty) (t['chart_ph_out'], DT.info),
      ],
      child: _lineChart(
        bars: bars,
        minY: minY,
        maxY: maxY,
        phaseChangeDays: phaseChangeDays,
        allLogs: logs,
        decimals: 1,
      ),
    );
  }

  // ─── EC Delta Chart ─────────────────────────────────────────────────────────

  Widget _buildDeltaChart(List<PlantLog> logs) {
    final deltaLogs =
        logs.where((l) => l.ecIn != null && l.ecOut != null).toList();

    if (deltaLogs.isEmpty) {
      return _emptyCard(t['chart_ec_delta_title'], t['chart_no_runoff_delta']);
    }

    final groups = deltaLogs.asMap().entries.map((e) {
      final delta = e.value.ecOut! - e.value.ecIn!;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: delta,
            fromY: 0,
            color: delta >= 0 ? DT.error : DT.accent,
            width: deltaLogs.length > 20 ? 6 : 12,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      );
    }).toList();

    final allDeltas = deltaLogs.map((l) => l.ecOut! - l.ecIn!).toList();
    final minDelta = allDeltas.reduce(min);
    final maxDelta = allDeltas.reduce(max);
    final minY = (minDelta - 0.2).clamp(-5.0, 0.0);
    final maxY = max(maxDelta + 0.2, 0.2);
    final xInterval = max(1.0, (deltaLogs.length / 5).floorToDouble());

    return _chartCard(
      title: t['chart_ec_delta_title'],
      legend: [
        (t['chart_delta_positive'], DT.error),
        (t['chart_delta_negative'], DT.accent),
      ],
      child: SizedBox(
        height: 240,
        child: BarChart(
          BarChartData(
            minY: minY,
            maxY: maxY,
            barGroups: groups,
            gridData: FlGridData(
              show: true,
              horizontalInterval: 0.5,
              getDrawingHorizontalLine: (v) => FlLine(
                color: DT.border.withValues(alpha: 0.3),
                strokeWidth: 1,
                dashArray: v == 0 ? null : [4, 4],
              ),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= deltaLogs.length) return const Text('');
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'T${deltaLogs[index].dayNumber}',
                        style: const TextStyle(
                            fontSize: 11, color: DT.textSecondary),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 11, color: DT.textSecondary),
                  ),
                ),
              ),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(y: 0, color: DT.textTertiary, strokeWidth: 1.5),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Shared helpers ──────────────────────────────────────────────────────────

  LineChartBarData _lineBar(
    List<FlSpot> spots,
    Color color, {
    required bool dashed,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dashArray: dashed ? [6, 4] : null,
      dotData: FlDotData(show: spots.length <= 30),
      belowBarData: dashed
          ? BarAreaData(show: false)
          : BarAreaData(show: true, color: color.withValues(alpha: 0.07)),
    );
  }

  /// Line chart using PlantLog day numbers on X axis + phase-change lines.
  Widget _lineChart({
    required List<LineChartBarData> bars,
    required double minY,
    required double maxY,
    required List<double> phaseChangeDays,
    required List<PlantLog> allLogs,
    required int decimals,
  }) {
    final allDayNumbers = allLogs.map((l) => l.dayNumber.toDouble()).toList();
    final minX = allDayNumbers.isEmpty ? 0.0 : allDayNumbers.reduce(min);
    final maxX = allDayNumbers.isEmpty ? 1.0 : allDayNumbers.reduce(max);
    final xInterval = max(1.0, ((maxX - minX) / 5).floorToDouble());

    final vLines = phaseChangeDays
        .map((day) => VerticalLine(
              x: day,
              color: DT.accent.withValues(alpha: 0.5),
              strokeWidth: 1.5,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                labelResolver: (_) => t['chart_phase_marker'],
                style: const TextStyle(fontSize: 8, color: DT.accent),
              ),
            ))
        .toList();

    return SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: bars,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) => FlLine(
            color: DT.border.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(verticalLines: vLines),
        titlesData: _titlesData(
          xInterval: xInterval,
          xLabel: (v) => 'T${v.toInt()}',
          decimals: decimals,
        ),
      )),
    );
  }

  /// Line chart using raw FlSpots (RDWC day numbers already embedded).
  Widget _lineChartRaw({
    required List<LineChartBarData> bars,
    required double minY,
    required double maxY,
    required List<FlSpot> spots,
    required int decimals,
  }) {
    final xValues = spots.map((s) => s.x).toList();
    final minX = xValues.isEmpty ? 0.0 : xValues.reduce(min);
    final maxX = xValues.isEmpty ? 1.0 : xValues.reduce(max);
    final xInterval = max(1.0, ((maxX - minX) / 5).floorToDouble());

    return SizedBox(
      height: 200,
      child: LineChart(LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: bars,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (v) => FlLine(
            color: DT.border.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        titlesData: _titlesData(
          xInterval: xInterval,
          xLabel: (v) => 'T${v.toInt()}',
          decimals: decimals,
        ),
      )),
    );
  }

  FlTitlesData _titlesData({
    required double xInterval,
    required String Function(double) xLabel,
    required int decimals,
  }) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: xInterval,
          getTitlesWidget: (value, meta) => Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(xLabel(value),
                style:
                    const TextStyle(fontSize: 11, color: DT.textSecondary)),
          ),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          getTitlesWidget: (value, meta) => Text(
            value.toStringAsFixed(decimals),
            style: const TextStyle(fontSize: 11, color: DT.textSecondary),
          ),
        ),
      ),
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _chartCard({
    required String title,
    required List<(String, Color)> legend,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DT.textPrimary)),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 10,
                  children: legend
                      .map((item) => Text(
                            item.$1,
                            style: TextStyle(fontSize: 13, color: item.$2),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyCard(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DT.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: DT.textPrimary)),
          const SizedBox(height: 12),
          Text(message,
              style:
                  const TextStyle(fontSize: 13, color: DT.textSecondary)),
        ],
      ),
    );
  }
}
