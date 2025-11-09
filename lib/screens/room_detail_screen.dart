// =============================================
// GROWLOG - Room Detail Screen (✅ BUG FIX #5: CM statt Meter anzeigen)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/room.dart';
import '../models/plant.dart';
import '../models/hardware.dart';
import '../models/rdwc_system.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../repositories/interfaces/i_hardware_repository.dart';
import '../repositories/interfaces/i_rdwc_repository.dart';
import 'edit_room_screen.dart';
import 'plant_detail_screen.dart';
import 'hardware_list_screen.dart';
import 'rdwc_system_detail_screen.dart';
import '../di/service_locator.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;

  const RoomDetailScreen({super.key, required this.room});

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IHardwareRepository _hardwareRepo = getIt<IHardwareRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();

  List<Plant> _plants = [];
  List<Hardware> _hardware = [];
  RdwcSystem? _rdwcSystem;
  int _totalWattage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // ✅ PERFORMANCE: Parallel laden für schnellere Ladezeit
      final futures = <Future>[
        _plantRepo.findByRoom(widget.room.id!),
        _hardwareRepo.findActiveByRoom(widget.room.id!),
        _hardwareRepo.getTotalWattageByRoom(widget.room.id!),
        if (widget.room.rdwcSystemId != null)
          _rdwcRepo.getSystemById(widget.room.rdwcSystemId!)
        else
          Future.value(null),
      ];

      final results = await Future.wait(futures);

      final plants = results[0] as List<Plant>;
      final hardware = results[1] as List<Hardware>;
      final wattage = results[2] as int;
      final rdwcSystem = results[3] as RdwcSystem?;

      if (mounted) {
        setState(() {
          _plants = plants;
          _hardware = hardware;
          _rdwcSystem = rdwcSystem;
          _totalWattage = wattage;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RoomDetailScreen', 'Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              if (!mounted) return;
              final nav = Navigator.of(context);
              final result = await nav.push(
                MaterialPageRoute(
                  builder: (context) => EditRoomScreen(room: widget.room),
                ),
              );
              if (result == true && mounted) {
                nav.pop(true);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 80),
          children: [
            _buildRoomInfoCard(),
            if (_rdwcSystem != null) _buildRdwcSystemCard(),
            _buildHardwareSection(),
            _buildPlantsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRdwcSystemCard() {
    if (_rdwcSystem == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final system = _rdwcSystem!;

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

    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RdwcSystemDetailScreen(system: system),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.water_damage,
                    color: statusColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RDWC System',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          system.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Füllstand',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${system.fillPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktuell',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${system.currentLevel.toStringAsFixed(1)}L',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kapazität',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${system.maxCapacity.toStringAsFixed(0)}L',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (system.description != null && system.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  system.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getGrowTypeColor(widget.room.growType),
                  child: Icon(
                    _getGrowTypeIcon(widget.room.growType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.room.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.room.growType != null)
                        Text(
                          widget.room.growType!.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.room.description != null &&
                widget.room.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.room.description!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // ✅ BUG FIX #5: Meter → CM umrechnen (× 100)
                if (widget.room.width > 0 && widget.room.depth > 0)
                  _buildInfoChip(
                    Icons.straighten,
                    '${(widget.room.width * 100).toStringAsFixed(0)}cm × ${(widget.room.depth * 100).toStringAsFixed(0)}cm',
                  ),
                if (widget.room.height > 0)
                  _buildInfoChip(
                    Icons.height,
                    '${(widget.room.height * 100).toStringAsFixed(0)}cm Höhe',
                  ),
                if (widget.room.wateringSystem != null)
                  _buildInfoChip(
                    Icons.water_drop,
                    widget.room.wateringSystem!.displayName,
                  ),
                _buildInfoChip(
                  Icons.spa,
                  '${_plants.length} Pflanze(n)',
                  color: Colors.green[600],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color != null ? Colors.white : Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color != null ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[700],
              child: const Icon(Icons.devices, color: Colors.white),
            ),
            title: const Text(
              'Hardware',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${_hardware.length} Items • $_totalWattage W Gesamt'),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HardwareListScreen(
                      roomId: widget.room.id!,
                      roomName: widget.room.name,
                    ),
                  ),
                );
                _loadData();
              },
            ),
          ),
          if (_hardware.isNotEmpty) ...[
            const Divider(height: 1),
            ..._hardware.take(3).map((hw) => ListTile(
              dense: true,
              leading: Icon(
                hw.type.icon,
                color: Colors.orange[700],
                size: 24,
              ),
              title: Text(hw.displayName),
              subtitle: Text(hw.type.displayName),
              trailing: hw.wattage != null
                  ? Text(
                hw.wattageDisplay,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange[700],
                ),
              )
                  : null,
            )),
            if (_hardware.length > 3)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '+ ${_hardware.length - 3} weitere...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Keine Hardware erfasst',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlantsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[700],
              child: const Icon(Icons.spa, color: Colors.white),
            ),
            title: const Text(
              'Pflanzen',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${_plants.length} Pflanze(n) in diesem Raum'),
          ),
          if (_plants.isNotEmpty) ...[
            const Divider(height: 1),
            ..._plants.map((plant) => ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getPhaseEmoji(plant.phase),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Text(plant.name),
              subtitle: Text('${plant.strain ?? 'Unknown'} • Tag ${plant.totalDays}'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PlantDetailScreen(plant: plant),
                  ),
                );
                _loadData();
              },
            )),
          ] else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Keine Pflanzen in diesem Raum',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getGrowTypeColor(GrowType? type) {
    if (type == null) return Colors.grey[600]!;
    switch (type) {
      case GrowType.indoor:
        return Colors.blue[600]!;
      case GrowType.outdoor:
        return Colors.green[600]!;
      case GrowType.greenhouse:
        return Colors.orange[600]!;
    }
  }

  IconData _getGrowTypeIcon(GrowType? type) {
    if (type == null) return Icons.home;
    switch (type) {
      case GrowType.indoor:
        return Icons.home;
      case GrowType.outdoor:
        return Icons.park;
      case GrowType.greenhouse:
        return Icons.home_work;
    }
  }

  String _getPhaseEmoji(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return '🌱';
      case PlantPhase.veg:
        return '🌿';
      case PlantPhase.bloom:
        return '🌸';
      case PlantPhase.harvest:
        return '✂️';
      case PlantPhase.archived:
        return '📦';
    }
  }
}