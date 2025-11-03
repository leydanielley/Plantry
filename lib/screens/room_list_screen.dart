// =============================================
// GROWLOG - Room List Screen (✅ Custom Icons)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/room.dart';
import '../models/enums.dart';
import '../repositories/room_repository.dart';
import '../repositories/plant_repository.dart';
import '../repositories/settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';
import 'add_room_screen.dart';
import 'edit_room_screen.dart';
import 'room_detail_screen.dart';

class RoomListScreen extends StatefulWidget {
  const RoomListScreen({super.key});

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final RoomRepository _roomRepo = RoomRepository();
  final PlantRepository _plantRepo = PlantRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

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
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final rooms = await _roomRepo.findAll();

      // Lade Pflanzen-Anzahl pro Raum
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteRoom(Room room) async {
    final plantCount = _plantCounts[room.id] ?? 0;

    if (plantCount > 0) {
      // Raum hat Pflanzen - warnen
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t['room_cannot_be_deleted']),
          content: Text(
            _t['delete_room_with_plants']
                .replaceAll('{name}', room.name)
                .replaceAll('{count}', plantCount.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t['ok']),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['delete_room_title']),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${room.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t['delete'], style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _roomRepo.delete(room.id!);
        _loadRooms();
        if (mounted) {
          AppMessages.deletedSuccessfully(context, _t['rooms']);
        }
      } catch (e) {
        AppLogger.error('RoomListScreen', 'Error deleting: $e');
        if (mounted) {
          AppMessages.deletingError(context, e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['rooms']),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddRoomScreen()),
              );
              if (result == true) _loadRooms();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
          ? _buildEmptyState()
          : _buildRoomList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddRoomScreen()),
          );
          if (result == true) _loadRooms();
        },
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_work,
            size: AppConstants.emptyStateIconSize,
            color: Colors.grey[400],
          ),
          SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _t['no_rooms'],
            style: TextStyle(
              fontSize: AppConstants.emptyStateTitleFontSize,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: AppConstants.emptyStateSpacingMiddle),
          Text(
            _t['add_first_room'],
            style: TextStyle(
              fontSize: AppConstants.emptyStateSubtitleFontSize,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        itemCount: _rooms.length,
        padding: AppConstants.listPadding,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return _buildRoomCard(room);
        },
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final plantCount = _plantCounts[room.id] ?? 0;

    return Card(
      margin: AppConstants.cardMarginVertical,
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(6),
          child: Image.asset(
            _getGrowTypeIconPath(room.growType),
            fit: BoxFit.contain,
          ),
        ),
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (room.description != null)
              Text(room.description!),
            SizedBox(height: AppConstants.spacingXs),
            Row(
              children: [
                Icon(
                    Icons.spa,
                    size: AppConstants.listItemIconSize,
                    color: Colors.grey[600]
                ),
                SizedBox(width: AppConstants.listItemIconSpacing),
                Text(
                  '$plantCount ${_t['plants_short']}',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: AppConstants.fontSizeSmall
                  ),
                ),
                SizedBox(width: AppConstants.listItemSpacingMedium),
                if (room.growType != null) ...[
                  Icon(
                      Icons.category,
                      size: AppConstants.listItemIconSize,
                      color: Colors.grey[600]
                  ),
                  SizedBox(width: AppConstants.listItemIconSpacing),
                  Text(
                    room.growType!.displayName,
                    style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: AppConstants.fontSizeSmall
                    ),
                  ),
                ],
              ],
            ),
            if (room.width > 0 && room.depth > 0) ...[
              SizedBox(height: AppConstants.spacingXs / 2),
              Text(
                '${(room.width * 100).toStringAsFixed(0)}cm × ${(room.depth * 100).toStringAsFixed(0)}cm × ${(room.height * 100).toStringAsFixed(0)}cm',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: AppConstants.roomDimensionsFontSize
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['edit']),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['delete'], style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditRoomScreen(room: room),
                ),
              );
              if (result == true) _loadRooms();
            } else if (value == 'delete') {
              _deleteRoom(room);
            }
          },
        ),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RoomDetailScreen(room: room),
            ),
          );
          if (result == true) _loadRooms();
        },
      ),
    );
  }

  // ✅ Custom Icon Paths für Room Types
  String _getGrowTypeIconPath(GrowType? type) {
    if (type == null) return 'assets/icons/room_icon.png';
    switch (type) {
      case GrowType.indoor:
        return 'assets/icons/room_icon.png';
      case GrowType.outdoor:
        return 'assets/icons/outdoor_icon.png';
      case GrowType.greenhouse:
        return 'assets/icons/greenhouse_icon.png';
    }
  }
}