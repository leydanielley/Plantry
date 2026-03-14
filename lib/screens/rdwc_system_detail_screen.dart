// =============================================
// GROWLOG - RDWC System Detail Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/utils/unit_converter.dart';
import 'package:growlog_app/screens/rdwc_addback_form_screen.dart';
import 'package:growlog_app/screens/rdwc_system_form_screen.dart';
import 'package:growlog_app/screens/rdwc_recipes_screen.dart';
import 'package:growlog_app/screens/rdwc_analytics_screen.dart';
import 'package:growlog_app/screens/rdwc_quick_measurement_screen.dart';
import 'package:growlog_app/screens/nutrient_calculator_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

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

  late RdwcSystem _system;
  List<RdwcLog> _logs = [];
  List<Plant> _linkedPlants = [];
  double? _avgConsumption;
  bool _isLoading = true;
  late AppSettings _settings;
  late AppTranslations _t;

  @override
  void initState() {
    super.initState();
    _system = widget.system;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _settingsRepo.getSettings(),
        _rdwcRepo.getRecentLogsWithFertilizers(_system.id!, limit: 20),
        _rdwcRepo.getConsumptionStats(_system.id!, days: 30),
        _rdwcRepo.getSystemById(_system.id!),
        _plantRepo.findByRdwcSystem(_system.id!),
      ]);

      if (mounted) {
        setState(() {
          _settings = results[0] as AppSettings;
          _t = AppTranslations(_settings.language);
          _logs = results[1] as List<RdwcLog>;
          final stats = results[2] as Map<String, dynamic>;
          final avg = (stats['average'] as num?)?.toDouble() ?? 0.0;
          _avgConsumption = avg > 0 ? avg : null;
          if (results[3] != null) _system = results[3] as RdwcSystem;
          _linkedPlants = results[4] as List<Plant>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: DT.canvas, body: Center(child: CircularProgressIndicator(color: DT.accent)));

    return PlantryScaffold(
      title: _system.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: DT.textPrimary),
          onPressed: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcSystemFormScreen(system: _system)));
            if (res == true) _loadData();
          },
        ),
        PopupMenuButton<String>(
          color: DT.elevated,
          icon: const Icon(Icons.more_vert, color: DT.textPrimary),
          onSelected: (val) {
            if (val == 'archive') _archive();
            if (val == 'delete') _delete();
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'archive', child: Text(_system.archived ? _t['unarchive'] : _t['archive'], style: const TextStyle(color: DT.textPrimary))),
            PopupMenuItem(value: 'delete', child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
          ],
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: DT.accent,
        backgroundColor: DT.surface,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLevelCard(),
              const SizedBox(height: 16),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildExpertActions(),
              const SizedBox(height: 24),
              _sectionTitle(_t['plants_in_system']),
              ..._linkedPlants.map((p) => _buildPlantTile(p)),
              if (_linkedPlants.isEmpty) _empty(_t['no_plants_assigned']),
              const SizedBox(height: 24),
              _sectionTitle(_t['addback_log']),
              ..._logs.map((l) => _buildLogTile(l)),
              if (_logs.isEmpty) _empty(_t['no_logs_available']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard() {
    final statusColor = _system.isCriticallyLow ? DT.error : (_system.isLowWater ? DT.warning : DT.info);

    return PlantryCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t['fill_percentage'], style: const TextStyle(color: DT.textSecondary, fontSize: 13)),
                  Text('${_system.fillPercentage.toInt()}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: statusColor)),
                ],
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      value: _system.fillPercentage / 100,
                      strokeWidth: 8,
                      backgroundColor: DT.elevated,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Icon(Icons.water_drop, color: statusColor, size: 30),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _subStat(_t['room_detail_current'], UnitConverter.formatVolume(_system.currentLevel, _settings.volumeUnit)),
              _subStat(_t['max'], UnitConverter.formatVolume(_system.maxCapacity, _settings.volumeUnit)),
              _subStat(_t['rest'], UnitConverter.formatVolume(_system.remainingCapacity, _settings.volumeUnit)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: PlantryCard(
            child: Column(
              children: [
                const Icon(Icons.trending_down, color: DT.info, size: 20),
                const SizedBox(height: 4),
                Text(_avgConsumption != null ? UnitConverter.formatVolume(_avgConsumption!, _settings.volumeUnit, decimals: 1) : '—', style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary)),
                Text(_t['avg_per_day'], style: const TextStyle(fontSize: 10, color: DT.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PlantryCard(
            child: Column(
              children: [
                const Icon(Icons.shopping_basket_outlined, color: DT.warning, size: 20),
                const SizedBox(height: 4),
                Text('${_system.bucketCount}', style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary)),
                Text(_t['buckets'], style: const TextStyle(fontSize: 10, color: DT.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpertActions() {
    return PlantryCard(
      isFlat: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_t['quick_actions'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _actionBtn(_t['addback_action'], Icons.add_circle_outline, DT.success, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcAddbackFormScreen(system: _system))).then((_) => _loadData())),
              _actionBtn(_t['measurement_action'], Icons.science_outlined, DT.info, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcQuickMeasurementScreen(system: _system))).then((_) => _loadData())),
              _actionBtn(_t['recipes'], Icons.menu_book, DT.accent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RdwcRecipesScreen()))),
              _actionBtn(_t['analytics'], Icons.analytics_outlined, DT.info, () => Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcAnalyticsScreen(system: _system)))),
              _actionBtn('Rechner', Icons.calculate_outlined, DT.warning, () => Navigator.push(context, MaterialPageRoute(builder: (_) => NutrientCalculatorScreen(system: _system)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String l, IconData i, Color c, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.2))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, color: c, size: 16),
            const SizedBox(width: 6),
            Text(l, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantTile(Plant p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PlantryListTile(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Text(p.bucketNumber != null ? '#${p.bucketNumber}' : '🌱', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DT.accent)),
        title: p.name,
        subtitle: 'Tag ${p.totalDays} • ${p.phase.displayName}',
      ),
    );
  }

  Widget _buildLogTile(RdwcLog l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PlantryListTile(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(_logIcon(l.logType), color: _logColor(l.logType), size: 20),
        title: _logLabel(l.logType),
        subtitle: '${DateFormat('dd.MM HH:mm').format(l.logDate)}${l.waterAdded != null ? " • +${l.waterAdded}L" : ""}',
        trailing: l.ecAfter != null ? Text(UnitConverter.formatNutrient(l.ecAfter!, _settings.nutrientUnit, _settings.ppmScale), style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary)) : null,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcAddbackFormScreen(system: _system, existingLog: l))).then((_) => _loadData()),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));
  Widget _subStat(String l, String v) => Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary)), Text(l, style: const TextStyle(fontSize: 10, color: DT.textSecondary))]);
  Widget _empty(String t) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t, style: const TextStyle(color: DT.textTertiary, fontSize: 13))));

  IconData _logIcon(RdwcLogType t) => t == RdwcLogType.addback ? Icons.add_circle : t == RdwcLogType.fullChange ? Icons.sync : t == RdwcLogType.measurement ? Icons.science : Icons.build;
  Color _logColor(RdwcLogType t) => t == RdwcLogType.addback ? DT.success : t == RdwcLogType.fullChange ? DT.secondary : t == RdwcLogType.measurement ? DT.info : DT.warning;
  String _logLabel(RdwcLogType t) => t == RdwcLogType.addback ? 'Addback' : t == RdwcLogType.fullChange ? 'Wechsel' : t == RdwcLogType.measurement ? 'Messung' : 'Wartung';

  Future<void> _archive() async {
    await _rdwcRepo.archiveSystem(_system.id!, !_system.archived);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['delete_confirm'], style: const TextStyle(color: DT.textPrimary)),
      content: Text(_t['delete_system_confirm'], style: const TextStyle(color: DT.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
      ],
    ));
    if (ok == true) { await _rdwcRepo.deleteSystem(_system.id!); if (!mounted) return; Navigator.pop(context, true); }
  }
}
