// =============================================
// GROWLOG - Hardware List Screen
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/hardware.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_hardware_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';
import 'add_hardware_screen.dart';
import 'edit_hardware_screen.dart';
import '../di/service_locator.dart';

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
      AppLogger.error('HardwareListScreen', 'Error loading hardware: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteHardware(Hardware hardware) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['delete_hardware_title']),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${hardware.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t['delete']),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _hardwareRepo.delete(hardware.id!);
        _loadHardware();
        if (mounted) {
          AppMessages.deletedSuccessfully(context, _t['hardware']);
        }
      } catch (e) {
        AppLogger.error('HardwareListScreen', 'Error deleting: $e');
        if (mounted) {
          AppMessages.deletingError(context, e.toString());
        }
      }
    }
  }

  Future<void> _toggleActive(Hardware hardware) async {
    try {
      if (hardware.active) {
        await _hardwareRepo.deactivate(hardware.id!);
      } else {
        await _hardwareRepo.activate(hardware.id!);
      }
      _loadHardware();
    } catch (e) {
      AppLogger.error('HardwareListScreen', 'Error toggling active: $e');
      if (mounted) {
        AppMessages.showError(context, 'Fehler beim Aktivieren/Deaktivieren');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_t['hardware']} - ${widget.roomName}'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showInactive ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() => _showInactive = !_showInactive);
              _loadHardware();
            },
            tooltip: _showInactive ? _t['hide_inactive'] : _t['show_inactive'],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddHardwareScreen(roomId: widget.roomId),
            ),
          );
          if (result == true) _loadHardware();
        },
        backgroundColor: Colors.orange[700],
        icon: const Icon(Icons.add),
        label: Text(_t['hardware']),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: AppConstants.statsCardMargin,
      color: Colors.orange[50],
      child: Padding(
        padding: AppConstants.statsCardPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              Icons.devices,
              '${_hardware.length}',
              _t['hardware_items'],
            ),
            _buildStatItem(
              Icons.bolt,
              '$_totalWattage W',
              _t['total_wattage'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange[700], size: AppConstants.statsIconSize),
        const SizedBox(height: AppConstants.spacingSmall),
        Text(
          value,
          style: TextStyle(
            fontSize: AppConstants.statsValueFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.orange[900],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: AppConstants.statsLabelFontSize,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices,
            size: AppConstants.emptyStateIconSize,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _t['no_hardware'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppConstants.emptyStateSpacingMiddle),
          Text(
            _t['add_first_hardware'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareList() {
    // Gruppiere nach Kategorie
    final grouped = <HardwareCategory, List<Hardware>>{};
    for (final hw in _hardware) {
      grouped.putIfAbsent(hw.type.category, () => []).add(hw);
    }

    return ListView.builder(
      padding: AppConstants.paddingHorizontalMedium,
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final category = grouped.keys.elementAt(index);
        final items = grouped[category]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppConstants.paddingVerticalSmall,
              child: Text(
                category.displayName,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeBody,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...items.map((hw) => _buildHardwareCard(hw)),
            const SizedBox(height: AppConstants.spacingSmall),
          ],
        );
      },
    );
  }

  Widget _buildHardwareCard(Hardware hardware) {
    // ✅ PERFORMANCE: RepaintBoundary isoliert jede Card für flüssigeres Scrolling
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: AppConstants.spacingSmall),
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: hardware.active ? Colors.orange[700] : Colors.grey[400],
          child: Icon(
            hardware.type.icon,
            color: Colors.white,
            size: AppConstants.iconSizeMedium,
          ),
        ),
        title: Text(
          hardware.displayName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: hardware.active ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hardware.type.displayName,
              style: TextStyle(
                fontSize: AppConstants.fontSizeSmall,
                color: Colors.grey[600],
              ),
            ),
            if (hardware.brand != null || hardware.model != null)
              Text(
                hardware.hardwareInfo,
                style: TextStyle(
                  fontSize: AppConstants.roomDimensionsFontSize,
                  color: Colors.grey[500],
                ),
              ),
            if (hardware.wattage != null)
              Text(
                hardware.wattageDisplay,
                style: TextStyle(
                  fontSize: AppConstants.roomDimensionsFontSize,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(
            Icons.more_vert, 
            size: AppConstants.popupMenuIconSize, 
            color: Colors.grey[600]
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    Icons.edit, 
                    size: AppConstants.popupMenuIconSize, 
                    color: Colors.blue[700]
                  ),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['edit'], style: TextStyle(color: Colors.blue[700])),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    hardware.active ? Icons.visibility_off : Icons.visibility,
                    size: AppConstants.popupMenuIconSize,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(
                    hardware.active ? _t['deactivate'] : _t['activate'],
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete, 
                    size: AppConstants.popupMenuIconSize, 
                    color: Colors.red
                  ),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['delete'], style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditHardwareScreen(hardware: hardware),
                ),
              ).then((result) {
                if (result == true) _loadHardware();
              });
            } else if (value == 'toggle') {
              _toggleActive(hardware);
            } else if (value == 'delete') {
              _deleteHardware(hardware);
            }
          },
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditHardwareScreen(hardware: hardware),
            ),
          ).then((result) {
            if (result == true) _loadHardware();
          });
        },
      ),
      ),
    );
  }
}
