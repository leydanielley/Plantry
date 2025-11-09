// =============================================
// GROWLOG - RDWC Systems Screen (Expert Mode)
// =============================================

import 'package:flutter/material.dart';
import '../repositories/interfaces/i_rdwc_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../models/rdwc_system.dart';
import '../models/app_settings.dart';
import '../utils/translations.dart';
import '../utils/unit_converter.dart';
import '../utils/app_logger.dart';
import 'rdwc_system_detail_screen.dart';
import 'rdwc_system_form_screen.dart';
import '../di/service_locator.dart';

class RdwcSystemsScreen extends StatefulWidget {
  const RdwcSystemsScreen({super.key});

  @override
  State<RdwcSystemsScreen> createState() => _RdwcSystemsScreenState();
}

class _RdwcSystemsScreenState extends State<RdwcSystemsScreen> {
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  List<RdwcSystem> _systems = [];
  bool _isLoading = true;
  bool _showArchived = false;
  late AppTranslations _t;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final systems = await _rdwcRepo.getAllSystems(includeArchived: _showArchived);

      if (mounted) {
        setState(() {
          _settings = settings;
          _t = AppTranslations(settings.language);
          _systems = systems;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcSystemsScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshSystems() async {
    final systems = await _rdwcRepo.getAllSystems(includeArchived: _showArchived);
    if (mounted) {
      setState(() => _systems = systems);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('RDWC Systems')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t['rdwc_systems']),
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.archive : Icons.archive_outlined),
            onPressed: () {
              setState(() => _showArchived = !_showArchived);
              _refreshSystems();
            },
            tooltip: _showArchived ? 'Hide Archived' : 'Show Archived',
          ),
        ],
      ),
      body: _systems.isEmpty
          ? _buildEmptyState(isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _systems.length,
              itemBuilder: (context, index) {
                return _buildSystemCard(_systems[index], isDark);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const RdwcSystemFormScreen(),
            ),
          );
          if (result == true) {
            _refreshSystems();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_t['add_rdwc_system']),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _t['no_logs_yet'],
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _t['create_first_log'],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[700] : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard(RdwcSystem system, bool isDark) {
    // Calculate status color
    Color statusColor;
    if (system.isCriticallyLow) {
      statusColor = Colors.red;
    } else if (system.isLowWater) {
      statusColor = Colors.orange;
    } else if (system.isFull) {
      statusColor = Colors.blue;
    } else {
      statusColor = Colors.green;
    }

    // ✅ PERFORMANCE: RepaintBoundary isoliert jede Card für flüssigeres Scrolling
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RdwcSystemDetailScreen(system: system),
            ),
          );
          if (result == true) {
            _refreshSystems();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Icon(
                    Icons.water_damage,
                    color: statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          system.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (system.description != null && system.description!.isNotEmpty)
                          Text(
                            system.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (system.archived)
                    const Icon(Icons.archive, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),

              // Level Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _t['water_level'],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${system.fillPercentage.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: system.fillPercentage / 100,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStat(
                    _t['current_level'],
                    UnitConverter.formatVolume(system.currentLevel, _settings.volumeUnit),
                    isDark,
                  ),
                  _buildStat(
                    _t['max_capacity'],
                    UnitConverter.formatVolume(system.maxCapacity, _settings.volumeUnit),
                    isDark,
                  ),
                  _buildStat(
                    _t['remaining_capacity'],
                    UnitConverter.formatVolume(system.remainingCapacity, _settings.volumeUnit),
                    isDark,
                  ),
                ],
              ),

              // Warning message
              if (system.isCriticallyLow)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _t['system_critical'],
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
              else if (system.isLowWater)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _t['system_low_water'],
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
