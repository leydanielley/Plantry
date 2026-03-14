// =============================================
// GROWLOG - RDWC Systems Screen (Expert Mode)
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/unit_converter.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/screens/rdwc_system_detail_screen.dart';
import 'package:growlog_app/screens/rdwc_system_form_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/theme/design_tokens.dart';

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
      AppLogger.error('RdwcSystemsScreen', 'Error loading', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: DT.canvas,
        body: Center(child: CircularProgressIndicator(color: DT.accent)),
      );
    }

    return PlantryScaffold(
      title: _t['rdwc_systems'],
      actions: [
        IconButton(
          icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined, color: DT.textPrimary),
          onPressed: () {
            setState(() => _showArchived = !_showArchived);
            _loadData();
          },
        ),
      ],
      body: _systems.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _systems.length,
              itemBuilder: (context, index) => _buildSystemCard(_systems[index]),
            ),
      fab: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const RdwcSystemFormScreen()));
          if (res == true) _loadData();
        },
        backgroundColor: DT.accent,
        foregroundColor: DT.onAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.water_drop_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(_t['rdwc_systems'], style: const TextStyle(fontSize: 20, color: DT.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_t['no_systems_yet'], style: const TextStyle(fontSize: 16, color: DT.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSystemCard(RdwcSystem system) {
    Color statusColor = DT.success;
    if (system.isCriticallyLow) {
      statusColor = DT.error;
    } else if (system.isLowWater) {
      statusColor = DT.warning;
    } else if (system.isFull) {
      statusColor = DT.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlantryCard(
        onTap: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcSystemDetailScreen(system: system)));
          if (res == true) _loadData();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(10)),
                  child: Image.asset('assets/icons/rdwc_icon.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(system.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DT.textPrimary)),
                      if (system.description != null) Text(system.description!, style: const TextStyle(fontSize: 12, color: DT.textSecondary), maxLines: 1),
                    ],
                  ),
                ),
                if (system.archived) const Icon(Icons.inventory_2, color: DT.textTertiary, size: 18),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t['water_level'], style: const TextStyle(fontSize: 12, color: DT.textSecondary)),
                Text('${system.fillPercentage.toInt()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: system.fillPercentage / 100,
                minHeight: 6,
                backgroundColor: DT.elevated,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stat(_t['room_detail_current'], UnitConverter.formatVolume(system.currentLevel, _settings.volumeUnit)),
                _stat('Kapazität', UnitConverter.formatVolume(system.maxCapacity, _settings.volumeUnit)),
                _stat(_t['rest'], UnitConverter.formatVolume(system.remainingCapacity, _settings.volumeUnit)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: DT.textTertiary)),
        Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DT.textPrimary)),
      ],
    );
  }
}
