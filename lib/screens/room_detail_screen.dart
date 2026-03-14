// =============================================
// GROWLOG - Room Detail Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/hardware.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_hardware_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/screens/edit_room_screen.dart';
import 'package:growlog_app/screens/plant_detail_screen.dart';
import 'package:growlog_app/screens/hardware_list_screen.dart';
import 'package:growlog_app/screens/rdwc_system_detail_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/theme/design_tokens.dart';

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

  late AppTranslations _t;
  List<Plant> _plants = [];
  List<Hardware> _hardware = [];
  RdwcSystem? _rdwcSystem;
  int _totalWattage = 0;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final res = await Future.wait([
        _plantRepo.findByRoom(widget.room.id!),
        _hardwareRepo.findActiveByRoom(widget.room.id!),
        _hardwareRepo.getTotalWattageByRoom(widget.room.id!),
        if (widget.room.rdwcSystemId != null) _rdwcRepo.getSystemById(widget.room.rdwcSystemId!) else Future.value(null),
      ]);
      if (mounted) {
        setState(() {
          _plants = res[0] as List<Plant>;
          _hardware = res[1] as List<Hardware>;
          _totalWattage = res[2] as int;
          _rdwcSystem = res[3] as RdwcSystem?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: widget.room.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: DT.textPrimary),
          onPressed: () async {
            final nav = Navigator.of(context);
            final res = await nav.push(MaterialPageRoute(builder: (_) => EditRoomScreen(room: widget.room)));
            if (res == true) nav.pop(true);
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: DT.accent,
              backgroundColor: DT.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _buildHeader(),
                  if (_rdwcSystem != null) ...[const SizedBox(height: 12), _buildRdwc()],
                  const SizedBox(height: 24),
                  _buildSectionHeader('Hardware', Icons.devices, () => Navigator.push(context, MaterialPageRoute(builder: (_) => HardwareListScreen(roomId: widget.room.id!, roomName: widget.room.name))).then((_) => _loadData())),
                  ..._hardware.take(3).map((hw) => _buildHwTile(hw)),
                  if (_hardware.isEmpty) _empty('Keine Hardware'),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Pflanzen', Icons.spa, null),
                  ..._plants.map((p) => _buildPlantTile(p)),
                  if (_plants.isEmpty) _empty('Keine Pflanzen'),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return PlantryCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(12)),
                child: Icon(_getIcon(widget.room.growType), color: DT.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.room.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DT.textPrimary)),
                    Text(widget.room.growType?.displayName ?? "Unbekannt", style: const TextStyle(fontSize: 13, color: DT.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('${(widget.room.width * 100).toInt()}x${(widget.room.depth * 100).toInt()}cm', 'Fläche'),
              _stat('${_totalWattage}W', 'Leistung'),
              _stat('${_plants.length}', 'Pflanzen'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRdwc() {
    final s = _rdwcSystem!;
    return PlantryCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RdwcSystemDetailScreen(system: s))).then((_) => _loadData()),
      child: Row(
        children: [
          Image.asset('assets/icons/rdwc_icon.png', width: 32, height: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RDWC System', style: TextStyle(fontSize: 12, color: DT.textSecondary)),
                Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DT.textPrimary)),
              ],
            ),
          ),
          Text('${s.fillPercentage.toInt()}%', style: TextStyle(color: s.fillPercentage < 20 ? DT.error : DT.info, fontWeight: FontWeight.bold)),
          const Icon(Icons.chevron_right, color: DT.textTertiary),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, VoidCallback? onMore) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DT.textSecondary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
          const Spacer(),
          if (onMore != null) TextButton(onPressed: onMore, child: Text(_t['show_all'], style: const TextStyle(color: DT.accent, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildHwTile(Hardware hw) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PlantryListTile(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(hw.type.icon, color: DT.warning, size: 20),
        title: hw.displayName,
        subtitle: '${hw.type.displayName}${hw.wattage != null ? " • ${hw.wattage}W" : ""}',
      ),
    );
  }

  Widget _buildPlantTile(Plant p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PlantryListTile(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Text(_getEmoji(p.phase), style: const TextStyle(fontSize: 20)),
        title: p.name,
        subtitle: 'Tag ${p.totalDays} • ${p.strain ?? "Unbekannt"}',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: p))).then((_) => _loadData()),
      ),
    );
  }

  Widget _stat(String v, String l) => Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary)), Text(l, style: const TextStyle(fontSize: 10, color: DT.textSecondary))]);
  Widget _empty(String t) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t, style: const TextStyle(color: DT.textTertiary))));
  IconData _getIcon(GrowType? t) => t == GrowType.indoor ? Icons.home : t == GrowType.outdoor ? Icons.park : Icons.home_work;
  String _getEmoji(PlantPhase p) => p == PlantPhase.seedling ? '🌱' : p == PlantPhase.veg ? '🌿' : p == PlantPhase.bloom ? '🌸' : p == PlantPhase.harvest ? '✂️' : '📦';
}
