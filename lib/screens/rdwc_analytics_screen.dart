// =============================================
// GROWLOG - RDWC Analytics Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/unit_converter.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/widgets/rdwc/stats_card.dart';
import 'package:growlog_app/widgets/rdwc/consumption_chart.dart';
import 'package:growlog_app/widgets/rdwc/drift_chart.dart';
import 'package:growlog_app/di/service_locator.dart';

class RdwcAnalyticsScreen extends StatefulWidget {
  final RdwcSystem system;

  const RdwcAnalyticsScreen({super.key, required this.system});

  @override
  State<RdwcAnalyticsScreen> createState() => _RdwcAnalyticsScreenState();
}

class _RdwcAnalyticsScreenState extends State<RdwcAnalyticsScreen> with SingleTickerProviderStateMixin {
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late TabController _tabController;
  late AppTranslations _t;
  late AppSettings _settings;

  int _selectedDays = 7;
  bool _isLoading = true;

  // Analytics data
  Map<String, dynamic>? _consumptionStats;
  Map<String, dynamic>? _dailyConsumption;
  Map<String, dynamic>? _ecDrift;
  Map<String, dynamic>? _phDrift;
  List<RdwcLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;  // ✅ FIX: Add mounted check before setState
    setState(() => _isLoading = true);

    try {
      final settings = await _settingsRepo.getSettings();
      final consumptionStats = await _rdwcRepo.getConsumptionStats(widget.system.id!, days: _selectedDays);
      final dailyConsumption = await _rdwcRepo.getDailyConsumption(widget.system.id!, days: _selectedDays);
      final ecDrift = await _rdwcRepo.getEcDriftAnalysis(widget.system.id!, days: _selectedDays);
      final phDrift = await _rdwcRepo.getPhDriftAnalysis(widget.system.id!, days: _selectedDays);
      final logs = await _rdwcRepo.getRecentLogs(widget.system.id!, limit: _selectedDays * 3);

      if (mounted) {
        setState(() {
          _settings = settings;
          _t = AppTranslations(settings.language);
          _consumptionStats = consumptionStats;
          _dailyConsumption = dailyConsumption;
          _ecDrift = ecDrift;
          _phDrift = phDrift;
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcAnalyticsScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.system.name} - ${_isLoading ? 'Loading...' : _t['analytics']}'),
        actions: [
          // Day selector
          PopupMenuButton<int>(
            initialValue: _selectedDays,
            onSelected: (days) {
              setState(() => _selectedDays = days);
              _loadData();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 7, child: Text('7 ${_isLoading ? 'Days' : _t['days']}')),
              PopupMenuItem(value: 14, child: Text('14 ${_isLoading ? 'Days' : _t['days']}')),
              PopupMenuItem(value: 30, child: Text('30 ${_isLoading ? 'Days' : _t['days']}')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('$_selectedDays ${_isLoading ? 'Days' : _t['days']}'),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        ],
        bottom: _isLoading
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: _t['consumption'], icon: const Icon(Icons.water_drop)),
                  Tab(text: 'EC ${_t['drift_analysis']}', icon: const Icon(Icons.analytics)),
                  Tab(text: 'pH ${_t['drift_analysis']}', icon: const Icon(Icons.water)),
                ],
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildConsumptionTab(isDark),
                _buildEcDriftTab(isDark),
                _buildPhDriftTab(isDark),
              ],
            ),
    );
  }

  Widget _buildConsumptionTab(bool isDark) {
    final avgConsumption = _consumptionStats?['average'] ?? 0.0;
    final maxConsumption = _consumptionStats?['max'] ?? 0.0;
    final minConsumption = _consumptionStats?['min'] ?? 0.0;
    final totalConsumption = _consumptionStats?['total'] ?? 0.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: _t['average'],
                  value: UnitConverter.formatVolume(avgConsumption, _settings.volumeUnit),
                  icon: Icons.water_drop,
                  color: Colors.blue,
                  subtitle: _t['per_day'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: _t['total_added'],
                  value: UnitConverter.formatVolume(totalConsumption, _settings.volumeUnit),
                  icon: Icons.water,
                  color: Colors.green,
                  subtitle: '$_selectedDays ${_t['days']}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: _t['maximum'],
                  value: UnitConverter.formatVolume(maxConsumption, _settings.volumeUnit),
                  icon: Icons.trending_up,
                  color: Colors.orange,
                  trend: 'up',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: _t['minimum'],
                  value: UnitConverter.formatVolume(minConsumption, _settings.volumeUnit),
                  icon: Icons.trending_down,
                  color: Colors.purple,
                  trend: 'down',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_t['daily']} ${_t['consumption']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ConsumptionChart(
                  dailyConsumption: _dailyConsumption ?? {},
                  averageConsumption: avgConsumption,
                  settings: _settings,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcDriftTab(bool isDark) {
    // ✅ FIX: Cast to avoid dynamic call error
    final avgDrift = (_ecDrift?['average'] as num?) ?? 0.0;
    final maxDrift = (_ecDrift?['max'] as num?) ?? 0.0;
    final minDrift = (_ecDrift?['min'] as num?) ?? 0.0;
    final trend = _ecDrift?['trend']?.toString() ?? 'stable';

    // Build drift data points from logs
    final ecDriftPoints = _logs
        .where((log) => log.ecDrift != null)
        .map((log) => DriftDataPoint(
              date: log.logDate,
              value: log.ecDrift!,
            ))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: '${_t['average']} ${_t['drift_analysis']}',
                  value: '${avgDrift.toStringAsFixed(2)} mS/cm',
                  icon: Icons.analytics,
                  color: Colors.blue,
                  trend: trend,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: _t['trend'],
                  value: _getTrendText(trend),
                  icon: _getTrendIcon(trend),
                  color: _getTrendColor(trend),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: '${_t['maximum']} ${_t['drift_analysis']}',
                  value: '${maxDrift.toStringAsFixed(2)} mS/cm',
                  icon: Icons.trending_up,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: '${_t['minimum']} ${_t['drift_analysis']}',
                  value: '${minDrift.toStringAsFixed(2)} mS/cm',
                  icon: Icons.trending_down,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'EC ${_t['drift_analysis']} ${_t['over_time']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                DriftChart(
                  ecData: ecDriftPoints,
                  phData: const [],
                  mode: 'ec',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhDriftTab(bool isDark) {
    // ✅ FIX: Cast to avoid dynamic call error
    final avgDrift = (_phDrift?['average'] as num?) ?? 0.0;
    final maxDrift = (_phDrift?['max'] as num?) ?? 0.0;
    final minDrift = (_phDrift?['min'] as num?) ?? 0.0;
    final trend = _phDrift?['trend']?.toString() ?? 'stable';

    // Build drift data points from logs
    final phDriftPoints = _logs
        .where((log) => log.phDrift != null)
        .map((log) => DriftDataPoint(
              date: log.logDate,
              value: log.phDrift!,
            ))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: '${_t['average']} ${_t['drift_analysis']}',
                  value: avgDrift.toStringAsFixed(2),
                  icon: Icons.water,
                  color: Colors.green,
                  trend: trend,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: _t['trend'],
                  value: _getTrendText(trend),
                  icon: _getTrendIcon(trend),
                  color: _getTrendColor(trend),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  label: '${_t['maximum']} ${_t['drift_analysis']}',
                  value: maxDrift.toStringAsFixed(2),
                  icon: Icons.trending_up,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatsCard(
                  label: '${_t['minimum']} ${_t['drift_analysis']}',
                  value: minDrift.toStringAsFixed(2),
                  icon: Icons.trending_down,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'pH ${_t['drift_analysis']} ${_t['over_time']}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                DriftChart(
                  ecData: const [],
                  phData: phDriftPoints,
                  mode: 'ph',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTrendText(String trend) {
    switch (trend) {
      case 'increasing':
        return _t['increasing'];
      case 'decreasing':
        return _t['decreasing'];
      case 'stable':
        return _t['stable'];
      default:
        return _t['stable'];
    }
  }

  IconData _getTrendIcon(String trend) {
    switch (trend) {
      case 'increasing':
        return Icons.trending_up;
      case 'decreasing':
        return Icons.trending_down;
      case 'stable':
        return Icons.trending_flat;
      default:
        return Icons.trending_flat;
    }
  }

  Color _getTrendColor(String trend) {
    switch (trend) {
      case 'increasing':
        return Colors.red;
      case 'decreasing':
        return Colors.green;
      case 'stable':
        return Colors.blue;
      default:
        return Colors.blue;
    }
  }
}
