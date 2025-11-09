// =============================================
// GROWLOG - RDWC System Detail Screen
// =============================================

import 'package:flutter/material.dart';
import '../repositories/interfaces/i_rdwc_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../models/rdwc_system.dart';
import '../models/rdwc_log.dart';
import '../models/rdwc_log_fertilizer.dart';
import '../models/fertilizer.dart';
import '../models/plant.dart';
import '../models/app_settings.dart';
import '../utils/translations.dart';
import '../utils/unit_converter.dart';
import '../utils/app_logger.dart';
import 'rdwc_addback_form_screen.dart';
import 'rdwc_system_form_screen.dart';
import 'rdwc_recipes_screen.dart';
import 'rdwc_analytics_screen.dart';
import 'rdwc_quick_measurement_screen.dart';
import '../di/service_locator.dart';

class RdwcSystemDetailScreen extends StatefulWidget {
  final RdwcSystem system;

  const RdwcSystemDetailScreen({super.key, required this.system});

  @override
  State<RdwcSystemDetailScreen> createState() => _RdwcSystemDetailScreenState();
}

class _RdwcSystemDetailScreenState extends State<RdwcSystemDetailScreen> {
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();

  late RdwcSystem _system;
  List<RdwcLog> _logs = [];
  List<Plant> _linkedPlants = [];
  double? _avgConsumption;
  bool _isLoading = true;
  late AppTranslations _t;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _system = widget.system;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // ✅ PERFORMANCE: Parallel laden für schnellere Ladezeit
      final results = await Future.wait([
        _settingsRepo.getSettings(),
        _rdwcRepo.getRecentLogsWithFertilizers(_system.id!, limit: 20),
        _rdwcRepo.getAverageDailyConsumption(_system.id!, days: 7),
        _rdwcRepo.getSystemById(_system.id!),
        _plantRepo.findByRdwcSystem(_system.id!),
      ]);

      final settings = results[0] as AppSettings;
      final logs = results[1] as List<RdwcLog>;
      final avg = results[2] as double?;
      final updatedSystem = results[3] as RdwcSystem?;
      final linkedPlants = results[4] as List<Plant>;

      if (mounted) {
        setState(() {
          _settings = settings;
          _t = AppTranslations(settings.language);
          _logs = logs;
          _linkedPlants = linkedPlants;
          _avgConsumption = avg;
          if (updatedSystem != null) _system = updatedSystem;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcSystemDetailScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_system.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => RdwcSystemFormScreen(system: _system),
                ),
              );
              if (result == true) {
                _loadData();
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'archive') {
                await _archiveSystem();
              } else if (value == 'delete') {
                await _deleteSystem();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      _system.archived ? Icons.unarchive : Icons.archive,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(width: 12),
                    Text(_system.archived ? 'Wiederherstellen' : 'Archivieren'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red[700]),
                    const SizedBox(width: 12),
                    const Text('Löschen'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSystemOverview(isDark),
              const SizedBox(height: 24),
              _buildStatistics(isDark),
              const SizedBox(height: 24),
              if (_settings.isExpertMode) ...[
                _buildExpertActions(isDark),
                const SizedBox(height: 24),
              ],
              _buildLinkedPlantsSection(isDark),
              const SizedBox(height: 24),
              _buildLogsSection(isDark),
            ],
          ),
        ),
      ),
      // ✅ FloatingActionButton entfernt - redundant, da bereits "Add Addback" Button in Expert Actions vorhanden
    );
  }

  Future<void> _archiveSystem() async {
    try {
      if (_system.archived) {
        await _rdwcRepo.archiveSystem(_system.id!, false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('System wiederhergestellt')),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        await _rdwcRepo.archiveSystem(_system.id!, true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('System archiviert')),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      AppLogger.error('RdwcSystemDetailScreen', 'Error archiving system', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteSystem() async {
    // Check if system has logs
    if (_logs.isNotEmpty) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Text('System hat Logs'),
            ],
          ),
          content: Text(
            'Dieses RDWC System hat ${_logs.length} Log-Einträge. '
            'Beim Löschen werden ALLE Logs und Daten unwiderruflich gelöscht!\n\n'
            'Möchten Sie stattdessen archivieren?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(false);
                await _archiveSystem();
              },
              child: const Text('Archivieren'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Trotzdem löschen'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // Final confirmation
    if (!mounted) return;
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 12),
            Text('Wirklich löschen?'),
          ],
        ),
        content: Text(
          'RDWC System "${_system.name}" wird unwiderruflich gelöscht.\n\n'
          'Diese Aktion kann nicht rückgängig gemacht werden!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    try {
      await _rdwcRepo.deleteSystem(_system.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ System gelöscht')),
        );
        Navigator.of(context).pop(true); // Return to list
      }
    } catch (e) {
      AppLogger.error('RdwcSystemDetailScreen', 'Error deleting system', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Fehler: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildSystemOverview(bool isDark) {
    Color statusColor = _system.isCriticallyLow
        ? Colors.red
        : _system.isLowWater
            ? Colors.orange
            : _system.isFull
                ? Colors.blue
                : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['reservoir_status'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            // Big level indicator
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                        value: _system.fillPercentage / 100,
                        strokeWidth: 14,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_system.fillPercentage.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t['fill_percentage'],
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stats grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOverviewStat(
                  _t['current_level'],
                  UnitConverter.formatVolume(_system.currentLevel, _settings.volumeUnit),
                  Icons.water_drop,
                  statusColor,
                  isDark,
                ),
                _buildOverviewStat(
                  _t['max_capacity'],
                  UnitConverter.formatVolume(_system.maxCapacity, _settings.volumeUnit),
                  Icons.water,
                  Colors.blue,
                  isDark,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildStatistics(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['statistics'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    _t['avg_daily_consumption'],
                    _avgConsumption != null
                        ? UnitConverter.formatVolume(_avgConsumption!, _settings.volumeUnit, decimals: 2)
                        : '-',
                    Icons.trending_down,
                    Colors.blue,
                    isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    _t['remaining_capacity'],
                    UnitConverter.formatVolume(_system.remainingCapacity, _settings.volumeUnit),
                    Icons.water_damage_outlined,
                    Colors.orange,
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['addback_log'],
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (_logs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 48,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t['no_logs_yet'],
                      style: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._logs.map((log) => _buildLogTile(log, isDark)),
      ],
    );
  }

  Widget _buildLogTile(RdwcLog log, bool isDark) {
    IconData icon;
    Color color;
    String typeLabel;

    switch (log.logType) {
      case RdwcLogType.addback:
        icon = Icons.add_circle;
        color = Colors.green;
        typeLabel = _t['water_addback'];
        break;
      case RdwcLogType.fullChange:
        icon = Icons.sync;
        color = Colors.blue;
        typeLabel = _t['full_change'];
        break;
      case RdwcLogType.maintenance:
        icon = Icons.build;
        color = Colors.orange;
        typeLabel = _t['maintenance'];
        break;
      case RdwcLogType.measurement:
        icon = Icons.science;
        color = Colors.purple;
        typeLabel = _t['measurement'];
        break;
    }

    // Check if there are fertilizers to display
    final hasFertilizers = log.fertilizers != null && log.fertilizers!.isNotEmpty;

    if (!hasFertilizers) {
      // Simple tile without fertilizers
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(typeLabel),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.formattedDate),
              if (log.waterAdded != null)
                Text('${_t['water_added']}: ${UnitConverter.formatVolume(log.waterAdded!, _settings.volumeUnit)}'),
              if (log.waterConsumed != null)
                Text('${_t['water_consumed']}: ${UnitConverter.formatVolume(log.waterConsumed!, _settings.volumeUnit)}'),
            ],
          ),
          trailing: log.ecAfter != null
              ? Text(
                  UnitConverter.formatNutrient(log.ecAfter!, _settings.nutrientUnit, _settings.ppmScale, decimals: 1),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
              : null,
          onTap: () => _editLog(log),
          onLongPress: () => _deleteLog(log),
        ),
      );
    }

    // Expandable tile with fertilizers
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: color),
        title: GestureDetector(
          onTap: () => _editLog(log),
          onLongPress: () => _deleteLog(log),
          child: Text(typeLabel),
        ),
        subtitle: GestureDetector(
          onTap: () => _editLog(log),
          onLongPress: () => _deleteLog(log),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log.formattedDate),
              if (log.waterAdded != null)
                Text('${_t['water_added']}: ${UnitConverter.formatVolume(log.waterAdded!, _settings.volumeUnit)}'),
              if (log.waterConsumed != null)
                Text('${_t['water_consumed']}: ${UnitConverter.formatVolume(log.waterConsumed!, _settings.volumeUnit)}'),
              Text(
                '${log.fertilizers!.length} ${_t['nutrients']}',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: log.ecAfter != null
            ? Text(
                UnitConverter.formatNutrient(log.ecAfter!, _settings.nutrientUnit, _settings.ppmScale, decimals: 1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
        children: [
          _buildFertilizerDetails(log, isDark),
        ],
      ),
    );
  }

  /// Build fertilizer details section for a log
  Widget _buildFertilizerDetails(RdwcLog log, bool isDark) {
    if (log.fertilizers == null || log.fertilizers!.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<_FertilizerLogDisplay>>(
      future: _loadFertilizerDisplayData(log),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final fertilizerDisplays = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t['nutrients'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              ...fertilizerDisplays.map((display) => _buildFertilizerRow(display, log, isDark)),
            ],
          ),
        );
      },
    );
  }

  /// Build a single fertilizer row
  Widget _buildFertilizerRow(_FertilizerLogDisplay display, RdwcLog log, bool isDark) {
    final logFert = display.logFertilizer;
    final fert = display.fertilizer;

    // Calculate amounts
    final systemVolume = log.levelAfter ?? _system.currentLevel;
    final totalAmount = logFert.getTotalAmount(systemVolume);
    final perLiterAmount = logFert.getPerLiterAmount(systemVolume);

    // Format amount display
    String amountText;
    if (logFert.amountType == FertilizerAmountType.perLiter) {
      amountText = '${perLiterAmount.toStringAsFixed(1)}ml/L (${totalAmount.toStringAsFixed(0)}ml ${_t['total_amount']})';
    } else {
      amountText = '${totalAmount.toStringAsFixed(0)}ml ${_t['total_amount']} (${perLiterAmount.toStringAsFixed(1)}ml/L)';
    }

    // Calculate contribution
    String contributionText = '';
    if (fert.ecValue != null && fert.ecValue! > 0) {
      final ecContribution = perLiterAmount * fert.ecValue!;
      if (_settings.nutrientUnit == NutrientUnit.ec) {
        contributionText = '→ ${ecContribution.toStringAsFixed(2)} mS/cm';
      } else {
        final ppmContribution = UnitConverter.ecToPpm(ecContribution, _settings.ppmScale);
        contributionText = '→ ${ppmContribution.toStringAsFixed(0)} PPM';
      }
    } else if (fert.ppmValue != null && fert.ppmValue! > 0) {
      final ppmContribution = perLiterAmount * fert.ppmValue!;
      if (_settings.nutrientUnit == NutrientUnit.ppm) {
        contributionText = '→ ${ppmContribution.toStringAsFixed(0)} PPM';
      } else {
        final ecContribution = UnitConverter.ppmToEc(ppmContribution, _settings.ppmScale);
        contributionText = '→ ${ecContribution.toStringAsFixed(2)} mS/cm';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fert.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                if (contributionText.isNotEmpty)
                  Text(
                    contributionText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Load fertilizer data for display
  Future<List<_FertilizerLogDisplay>> _loadFertilizerDisplayData(RdwcLog log) async {
    if (log.fertilizers == null || log.fertilizers!.isEmpty) {
      return [];
    }

    final displays = <_FertilizerLogDisplay>[];
    for (final logFert in log.fertilizers!) {
      final fert = await _fertilizerRepo.findById(logFert.fertilizerId);
      if (fert != null) {
        displays.add(_FertilizerLogDisplay(
          logFertilizer: logFert,
          fertilizer: fert,
        ));
      }
    }
    return displays;
  }

  Widget _buildExpertActions(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'EXPERT MODE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _t['quick_actions'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Row 1: Recipe & Analytics
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RdwcRecipesScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.science, size: 20),
                    label: Text(_t['recipes'], style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RdwcAnalyticsScreen(system: _system),
                        ),
                      );
                    },
                    icon: const Icon(Icons.analytics, size: 20),
                    label: Text(_t['analytics'], style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Quick Measurement & Water Addback
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RdwcQuickMeasurementScreen(system: _system),
                        ),
                      );
                      if (result == true) _loadData();
                    },
                    icon: const Icon(Icons.science, size: 20, color: Colors.purple),
                    label: Text(_t['quick_measurement'], style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[50],
                      foregroundColor: Colors.purple[900],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RdwcAddbackFormScreen(system: _system),
                        ),
                      );
                      if (result == true) _loadData();
                    },
                    icon: const Icon(Icons.add_circle, size: 20, color: Colors.green),
                    label: Text(_t['add_addback'], style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      foregroundColor: Colors.green[900],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedPlantsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t['plants_in_system'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '${_linkedPlants.length} / ${_system.bucketCount}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_linkedPlants.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.local_florist,
                      size: 48,
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t['no_plants_in_system'],
                      style: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ..._linkedPlants.map((plant) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.local_florist, color: Colors.green),
                  title: Text(plant.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_t['bucket_number']}: ${plant.bucketNumber ?? '-'}'),
                      Text('${_t['phase']}: ${plant.phase.displayName}'),
                    ],
                  ),
                  trailing: Text(
                    '${_t['day']} ${plant.totalDays}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              )),
      ],
    );
  }

  /// ✅ Edit RDWC log
  Future<void> _editLog(RdwcLog log) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RdwcAddbackFormScreen(
          system: _system,
          existingLog: log,
        ),
      ),
    );

    if (result == true && mounted) {
      _loadData(); // Reload data
    }
  }

  /// ✅ Delete RDWC log
  Future<void> _deleteLog(RdwcLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Log?'),
        content: Text(
          'Are you sure you want to delete this ${log.logType.name} log from ${log.formattedDate}?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _rdwcRepo.deleteLog(log.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Reload data
      }
    } catch (e) {
      AppLogger.error('RdwcSystemDetailScreen', 'Error deleting log', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Helper class to display fertilizer log data
class _FertilizerLogDisplay {
  final RdwcLogFertilizer logFertilizer;
  final Fertilizer fertilizer;

  _FertilizerLogDisplay({
    required this.logFertilizer,
    required this.fertilizer,
  });
}
