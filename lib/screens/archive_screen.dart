// =============================================
// GROWLOG - Archive Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/rdwc_repository.dart';
import 'package:growlog_app/repositories/room_repository.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with SingleTickerProviderStateMixin {
  final PlantRepository _plantRepo = PlantRepository();
  final RdwcRepository _rdwcRepo = RdwcRepository();
  final RoomRepository _roomRepo = RoomRepository();

  late TabController _tabController;
  late AppTranslations _t;
  List<Plant> _plants = [];
  List<RdwcSystem> _systems = [];
  List<Room> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Future.wait([_plantRepo.findArchived(), _rdwcRepo.getArchivedSystems(), _roomRepo.findArchived()]);
      if (mounted) {
        setState(() {
          _plants = res[0] as List<Plant>;
          _systems = res[1] as List<RdwcSystem>;
          _rooms = res[2] as List<Room>;
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
      title: _t['archive_title'],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: DT.accent,
        labelColor: DT.accent,
        unselectedLabelColor: DT.textTertiary,
        tabs: [Tab(text: _t['archive_tab_plants']), const Tab(text: 'RDWC'), Tab(text: _t['archive_tab_rooms'])],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : TabBarView(
              controller: _tabController,
              children: [_buildList(_plants, Icons.eco), _buildList(_systems, Icons.water_drop), _buildList(_rooms, Icons.home)],
            ),
    );
  }

  Widget _buildList(List<dynamic> items, IconData icon) {
    if (items.isEmpty) return Center(child: Text(_t['no_entries'], style: const TextStyle(color: DT.textTertiary)));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final itemName = item is Plant ? item.name : item is RdwcSystem ? item.name : (item as Room).name;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PlantryListTile(
            leading: Icon(icon, color: DT.warning, size: 20),
            title: itemName,
            subtitle: _t['tap_to_restore'],
            onTap: () => _confirmRestore(item),
          ),
        );
      },
    );
  }

  Future<void> _confirmRestore(dynamic item) async {
    final itemName = item is Plant ? item.name : item is RdwcSystem ? item.name : (item as Room).name;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['restore_confirm'], style: const TextStyle(color: DT.textPrimary)),
      content: Text('"$itemName" wird wieder aktiviert.', style: const TextStyle(color: DT.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t['restore'], style: const TextStyle(color: DT.accent))),
      ],
    ));
    if (ok == true) {
      if (item is Plant) await _plantRepo.restore(item.id!);
      if (item is RdwcSystem) await _rdwcRepo.restoreSystem(item.id!);
      if (item is Room) await _roomRepo.restore(item.id!);
      _loadData();
    }
  }
}
