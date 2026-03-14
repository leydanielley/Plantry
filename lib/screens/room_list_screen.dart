// =============================================
// GROWLOG - Room List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/screens/add_room_screen.dart';
import 'package:growlog_app/screens/edit_room_screen.dart';
import 'package:growlog_app/screens/room_detail_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  List<Room> _rooms = [];
  Map<int, int> _plantCounts = {};
  bool _isLoading = true;
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadRooms();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadRooms() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final rooms = await _roomRepo.findAll();
      final plantCounts = <int, int>{};
      for (final room in rooms) {
        if (room.id != null) {
          final plants = await _plantRepo.findByRoom(room.id!);
          plantCounts[room.id!] = plants.length;
        }
      }

      if (mounted) {
        setState(() {
          _rooms = rooms;
          _plantCounts = plantCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RoomListScreen', 'Error loading rooms: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRoom(Room room) async {
    final isInUse = await _roomRepo.isInUse(room.id!);

    if (isInUse) {
      final usage = await _roomRepo.getUsageDetails(room.id!);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DT.elevated,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: DT.warning),
              const SizedBox(width: 12),
              Expanded(child: Text(_t['room_cannot_be_deleted'], style: const TextStyle(color: DT.textPrimary))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t['still_used_by'], style: const TextStyle(color: DT.textSecondary)),
              const SizedBox(height: 8),
              if (usage['plants']! > 0) Text('• ${usage['plants']} Pflanzen', style: const TextStyle(color: DT.textSecondary)),
              if (usage['grows']! > 0) Text('• ${usage['grows']} Grows', style: const TextStyle(color: DT.textSecondary)),
              if (usage['hardware']! > 0) Text('• ${usage['hardware']} Hardware', style: const TextStyle(color: DT.textSecondary)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_t['ok'], style: const TextStyle(color: DT.accent))),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(_t['delete_room_title'], style: const TextStyle(color: DT.textPrimary)),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${room.name}"?', style: const TextStyle(color: DT.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _roomRepo.delete(room.id!);
        _loadRooms();
        if (mounted) AppMessages.deletedSuccessfully(context, _t['rooms']);
      } catch (e) {
        AppLogger.error('RoomListScreen', 'Error deleting: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['rooms'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : _rooms.isEmpty
          ? _buildEmptyState()
          : _buildRoomList(),
      fab: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddRoomScreen()),
          );
          if (result == true) _loadRooms();
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
          const Icon(Icons.home_work_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(_t['no_rooms'], style: const TextStyle(fontSize: 20, color: DT.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_t['add_first_room'], style: const TextStyle(fontSize: 16, color: DT.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return RefreshIndicator(
      onRefresh: _loadRooms,
      color: DT.accent,
      backgroundColor: DT.surface,
      child: ListView.builder(
        itemCount: _rooms.length,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) => _buildRoomCard(_rooms[index]),
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final plantCount = _plantCounts[room.id] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlantryListTile(
        leading: Container(
          width: 48, height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: DT.elevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(_getIcon(room.growType), fit: BoxFit.contain),
        ),
        title: room.name,
        subtitle: '$plantCount ${_t['plants_short']} • ${room.growType?.displayName ?? "Unbekannt"}\n${(room.width * 100).toInt()}x${(room.depth * 100).toInt()}x${(room.height * 100).toInt()}cm',
        trailing: PopupMenuButton<String>(
          color: DT.elevated,
          icon: const Icon(Icons.more_vert, color: DT.textTertiary),
          onSelected: (val) async {
            if (val == 'edit') {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditRoomScreen(room: room)));
              if (res == true) _loadRooms();
            } else if (val == 'delete') {
              _deleteRoom(room);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text(_t['edit'], style: const TextStyle(color: DT.textPrimary))),
            PopupMenuItem(value: 'delete', child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
          ],
        ),
        onTap: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)));
          if (res == true) _loadRooms();
        },
      ),
    );
  }

  String _getIcon(GrowType? type) {
    if (type == GrowType.indoor) return 'assets/icons/room_icon.png';
    if (type == GrowType.outdoor) return 'assets/icons/outdoor_icon.png';
    return 'assets/icons/greenhouse_icon.png';
  }
}
