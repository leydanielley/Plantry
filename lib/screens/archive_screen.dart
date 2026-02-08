// =============================================
// GROWLOG - Archive Screen
// View and restore archived plants, RDWC systems, and rooms
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/repositories/plant_repository.dart';
import 'package:growlog_app/repositories/rdwc_repository.dart';
import 'package:growlog_app/repositories/room_repository.dart';
import 'package:growlog_app/utils/app_logger.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen>
    with SingleTickerProviderStateMixin {
  final PlantRepository _plantRepo = PlantRepository();
  final RdwcRepository _rdwcRepo = RdwcRepository();
  final RoomRepository _roomRepo = RoomRepository();

  late TabController _tabController;

  List<Plant> _archivedPlants = [];
  List<RdwcSystem> _archivedSystems = [];
  List<Room> _archivedRooms = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final plants = await _plantRepo.findArchived();
      final systems = await _rdwcRepo.getArchivedSystems();
      final rooms = await _roomRepo.findArchived();

      if (mounted) {
        setState(() {
          _archivedPlants = plants;
          _archivedSystems = systems;
          _archivedRooms = rooms;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('ArchiveScreen', 'Failed to load archived items', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePlant(Plant plant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.unarchive, color: Colors.green),
            SizedBox(width: 12),
            Text('Pflanze wiederherstellen?'),
          ],
        ),
        content: Text(
          'Möchten Sie "${plant.name}" wiederherstellen?\n\n'
          'Die Pflanze und alle zugehörigen Logs werden wiederhergestellt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _plantRepo.restore(plant.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${plant.name} wurde wiederhergestellt'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        AppLogger.error('ArchiveScreen', 'Failed to restore plant', e);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Fehler: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _restoreSystem(RdwcSystem system) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.unarchive, color: Colors.green),
            SizedBox(width: 12),
            Text('System wiederherstellen?'),
          ],
        ),
        content: Text(
          'Möchten Sie "${system.name}" wiederherstellen?\n\n'
          'Das System und alle zugehörigen Logs werden wiederhergestellt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _rdwcRepo.restoreSystem(system.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${system.name} wurde wiederhergestellt'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        AppLogger.error('ArchiveScreen', 'Failed to restore system', e);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Fehler: ${e.toString()}')));
        }
      }
    }
  }

  Future<void> _restoreRoom(Room room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.unarchive, color: Colors.green),
            SizedBox(width: 12),
            Text('Raum wiederherstellen?'),
          ],
        ),
        content: Text('Möchten Sie "${room.name}" wiederherstellen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Wiederherstellen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _roomRepo.restore(room.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${room.name} wurde wiederhergestellt'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData();
        }
      } catch (e) {
        AppLogger.error('ArchiveScreen', 'Failed to restore room', e);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Fehler: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archiv'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.eco),
              text: 'Pflanzen (${_archivedPlants.length})',
            ),
            Tab(
              icon: const Icon(Icons.water_drop),
              text: 'RDWC (${_archivedSystems.length})',
            ),
            Tab(
              icon: const Icon(Icons.meeting_room),
              text: 'Räume (${_archivedRooms.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlantsList(isDark),
                _buildSystemsList(isDark),
                _buildRoomsList(isDark),
              ],
            ),
    );
  }

  Widget _buildPlantsList(bool isDark) {
    if (_archivedPlants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Keine archivierten Pflanzen',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _archivedPlants.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final plant = _archivedPlants[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: Icon(Icons.eco, color: Colors.orange[700]),
            ),
            title: Text(
              plant.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              plant.strain ?? 'Keine Sorte',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.unarchive, color: Colors.green),
              onPressed: () => _restorePlant(plant),
              tooltip: 'Wiederherstellen',
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemsList(bool isDark) {
    if (_archivedSystems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Keine archivierten RDWC-Systeme',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _archivedSystems.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final system = _archivedSystems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: Icon(Icons.water_drop, color: Colors.orange[700]),
            ),
            title: Text(
              system.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${system.maxCapacity.toStringAsFixed(1)}L Kapazität',
              style: TextStyle(color: Colors.grey[600]),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.unarchive, color: Colors.green),
              onPressed: () => _restoreSystem(system),
              tooltip: 'Wiederherstellen',
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomsList(bool isDark) {
    if (_archivedRooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Keine archivierten Räume',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _archivedRooms.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final room = _archivedRooms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: Icon(Icons.meeting_room, color: Colors.orange[700]),
            ),
            title: Text(
              room.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: room.description != null
                ? Text(
                    room.description!,
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.unarchive, color: Colors.green),
              onPressed: () => _restoreRoom(room),
              tooltip: 'Wiederherstellen',
            ),
          ),
        );
      },
    );
  }
}
