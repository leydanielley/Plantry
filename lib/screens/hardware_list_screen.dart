// =============================================
// GROWLOG - Hardware List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/hardware.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_hardware_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/screens/add_hardware_screen.dart';
import 'package:growlog_app/screens/edit_hardware_screen.dart';
import 'package:growlog_app/di/service_locator.dart';

class HardwareListScreen extends StatefulWidget {
  final int roomId;
  final String roomName;

  const HardwareListScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<HardwareListScreen> createState() => _HardwareListScreenState();
}

class _HardwareListScreenState extends State<HardwareListScreen> {
  final IHardwareRepository _hardwareRepo = getIt<IHardwareRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  List<Hardware> _hardware = [];
  bool _isLoading = true;
  bool _showInactive = false;
  int _totalWattage = 0;
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadHardware();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadHardware() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final hardware = _showInactive
          ? await _hardwareRepo.findByRoom(widget.roomId)
          : await _hardwareRepo.findActiveByRoom(widget.roomId);
      final wattage = await _hardwareRepo.getTotalWattageByRoom(widget.roomId);

      if (mounted) {
        setState(() {
          _hardware = hardware;
          _totalWattage = wattage;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('HardwareListScreen', 'Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHardware(Hardware hardware) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(_t['delete_hardware_title'], style: const TextStyle(color: DT.textPrimary)),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${hardware.name}"?', style: const TextStyle(color: DT.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _hardwareRepo.delete(hardware.id!);
        _loadHardware();
        if (mounted) AppMessages.deletedSuccessfully(context, _t['hardware']);
      } catch (e) {
        AppLogger.error('HardwareListScreen', 'Error deleting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: '${_t['hardware']} - ${widget.roomName}',
      actions: [
        IconButton(
          icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off, color: DT.textPrimary),
          onPressed: () {
            setState(() => _showInactive = !_showInactive);
            _loadHardware();
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Column(
              children: [
                _buildStatsCard(),
                Expanded(
                  child: _hardware.isEmpty
                      ? _buildEmptyState()
                      : _buildHardwareList(),
                ),
              ],
            ),
      fab: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => AddHardwareScreen(roomId: widget.roomId)),
          );
          if (result == true) _loadHardware();
        },
        backgroundColor: DT.accent,
        foregroundColor: DT.onAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PlantryCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(Icons.devices, '${_hardware.length}', _t['hardware_items']),
            _buildStatItem(Icons.bolt, '$_totalWattage W', _t['total_wattage']),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: DT.warning, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: DT.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 12, color: DT.textSecondary)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.devices_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(_t['no_hardware'], style: const TextStyle(fontSize: 20, color: DT.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_t['add_first_hardware'], style: const TextStyle(fontSize: 16, color: DT.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildHardwareList() {
    final grouped = <HardwareCategory, List<Hardware>>{};
    for (final hw in _hardware) {
      grouped.putIfAbsent(hw.type.category, () => []).add(hw);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final category = grouped.keys.elementAt(index);
        final items = grouped[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(category.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
            ),
            ...items.map((hw) => _buildHardwareCard(hw)),
          ],
        );
      },
    );
  }

  Widget _buildHardwareCard(Hardware hw) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlantryListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: hw.active ? DT.warning.withValues(alpha: 0.1) : DT.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(hw.type.icon, color: hw.active ? DT.warning : DT.textTertiary, size: 28),
        ),
        title: hw.displayName,
        subtitle: '${hw.type.displayName}${hw.wattage != null ? " • ${hw.wattage}W" : ""}\n${hw.brand ?? ""} ${hw.model ?? ""}',
        trailing: PopupMenuButton<String>(
          color: DT.elevated,
          icon: const Icon(Icons.more_vert, color: DT.textTertiary),
          onSelected: (val) async {
            if (val == 'edit') {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditHardwareScreen(hardware: hw)));
              if (res == true) _loadHardware();
            } else if (val == 'delete') {
              _deleteHardware(hw);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text(_t['edit'], style: const TextStyle(color: DT.textPrimary))),
            PopupMenuItem(value: 'delete', child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
          ],
        ),
        onTap: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditHardwareScreen(hardware: hw)));
          if (res == true) _loadHardware();
        },
      ),
    );
  }
}
