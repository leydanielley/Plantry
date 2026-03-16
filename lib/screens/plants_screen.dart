// =============================================
// GROWLOG - Plants Screen (GROUPED BY GROWS)
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/screens/plant_detail_screen.dart';
import 'package:growlog_app/screens/add_plant_screen.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class PlantsScreen extends StatefulWidget {
  const PlantsScreen({super.key});

  @override
  State<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends State<PlantsScreen> {
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  List<Plant> _allPlants = [];
  List<Grow> _allGrows = [];
  Map<int, Room> _roomsById = {};
  Map<int?, List<Plant>> _plantsByGrow = {};
  final Set<int?> _expandedGrows = {};
  bool _isLoading = true;
  bool _showOrphansOnly = false;
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadData();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final plants = _showOrphansOnly
          ? await _plantRepo.findOrphans()
          : await _plantRepo.findAll();

      final grows = await _growRepo.getAll(includeArchived: true);
      final rooms = await _roomRepo.findAll();

      final Map<int, Room> roomMap = {};
      for (final room in rooms) {
        if (room.id != null) {
          roomMap[room.id!] = room;
        }
      }

      final Map<int?, List<Plant>> grouped = {};
      for (final plant in plants) {
        if (!grouped.containsKey(plant.growId)) {
          grouped[plant.growId] = [];
        }
        grouped[plant.growId]!.add(plant);
      }

      if (mounted) {
        setState(() {
          _allPlants = plants;
          _allGrows = grows;
          _roomsById = roomMap;
          _plantsByGrow = grouped;
          // expand new groups by default, preserve collapsed state for existing ones
          for (final id in grouped.keys) {
            _expandedGrows.add(id);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('PlantsScreen', 'Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getGrowName(int? growId) {
    if (growId == null) return _t['without_grow'];
    final grow = _allGrows.firstWhere(
      (g) => g.id == growId,
      orElse: () => Grow(name: _t['unknown_grow'], startDate: DateTime.now()),
    );
    return grow.name;
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['plants'],
      actions: [
        IconButton(
          icon: Icon(
            _showOrphansOnly ? Icons.warning_amber : Icons.filter_list,
            color: _showOrphansOnly ? DT.warning : DT.textPrimary,
          ),
          tooltip: _showOrphansOnly
              ? 'Alle Pflanzen anzeigen'
              : 'Verwaiste Pflanzen anzeigen',
          onPressed: () {
            setState(() {
              _showOrphansOnly = !_showOrphansOnly;
            });
            _loadData();
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : _buildContent(),
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddPlantScreen()),
          );
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add),
        label: Text(_t['new_plant']),
      ),
    );
  }

  Widget _buildContent() {
    if (_allPlants.isEmpty) {
      return _buildEmptyState();
    }

    final items = _buildFlatItemList();

    if (_showOrphansOnly) {
      items.insert(0, _buildOrphanWarningBanner());
      items.insert(1, const SizedBox(height: 16));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  List<Widget> _buildFlatItemList() {
    final List<Widget> items = [];

    final sortedGrowIds = _plantsByGrow.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return 0;
      });

    for (final growId in sortedGrowIds) {
      final plants = _plantsByGrow[growId]!;
      final isExpanded = _expandedGrows.contains(growId);

      items.add(_buildGrowHeader(growId, plants.length, isExpanded));
      items.add(const SizedBox(height: 12));

      if (isExpanded) {
        for (final plant in plants) {
          items.add(_buildPlantCard(plant));
          items.add(const SizedBox(height: 8));
        }
      }

      items.add(const SizedBox(height: 24));
    }

    return items;
  }

  Widget _buildGrowHeader(int? growId, int plantCount, bool isExpanded) {
    final growName = _getGrowName(growId);
    IconData headerIcon = Icons.park;
    Color iconColor = DT.success;

    if (growId != null) {
      final grow = _allGrows.firstWhere(
        (g) => g.id == growId,
        orElse: () => Grow(name: '', startDate: DateTime.now()),
      );

      if (grow.roomId != null && _roomsById.containsKey(grow.roomId)) {
        final room = _roomsById[grow.roomId];
        if (room != null && room.growType != null) {
          switch (room.growType!) {
            case GrowType.indoor:
              headerIcon = Icons.home;
              iconColor = DT.info;
              break;
            case GrowType.outdoor:
              headerIcon = Icons.park;
              iconColor = DT.success;
              break;
            case GrowType.greenhouse:
              headerIcon = Icons.home_work;
              iconColor = DT.warning;
              break;
          }
        }
      } else {
        headerIcon = Icons.spa;
      }
    }

    return GestureDetector(
      onTap: () => setState(() {
        if (isExpanded) {
          _expandedGrows.remove(growId);
        } else {
          _expandedGrows.add(growId);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: DT.surface,
          borderRadius: BorderRadius.circular(DT.radiusCard),
          border: Border.all(color: DT.glassBorder),
        ),
        child: Row(
          children: [
            Icon(headerIcon, size: 24, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    growName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: DT.textPrimary,
                    ),
                  ),
                  Text(
                    '$plantCount ${plantCount == 1 ? _t['plant'] : _t['plants_count']}',
                    style: const TextStyle(fontSize: 13, color: DT.textSecondary),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: isExpanded ? 0 : -0.5,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down, color: DT.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantCard(Plant plant) {
    return PlantryListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: DT.elevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _getPhaseEmoji(plant.phase),
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
      title: plant.name,
      subtitle: '${plant.strain ?? _t['unknown_strain']} • ${_t['day']} ${plant.totalDays} • ${_getPhaseName(plant.phase)}',
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => PlantDetailScreen(plant: plant)),
        );
        if (result == true) _loadData();
      },
    );
  }

  Widget _buildOrphanWarningBanner() {
    return const PlantryCard(
      radius: 12,
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: DT.warning, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verwaiste Pflanzen',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: DT.warning,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Diese Pflanzen haben keinen Grow und keinen Raum zugewiesen. Bitte weise sie einem Grow zu.',
                  style: TextStyle(color: DT.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.spa_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(
            _showOrphansOnly ? 'Keine verwaisten Pflanzen!' : _t['no_plants_available'],
            style: const TextStyle(
              fontSize: 20,
              color: DT.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showOrphansOnly ? 'Alles ist korrekt zugewiesen.' : _t['create_first_plant'],
            style: const TextStyle(fontSize: 16, color: DT.textSecondary),
          ),
        ],
      ),
    );
  }

  String _getPhaseName(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling: return _t['seedling'];
      case PlantPhase.veg: return _t['veg'];
      case PlantPhase.bloom: return _t['bloom'];
      case PlantPhase.harvest: return _t['harvest'];
      case PlantPhase.archived: return _t['phase_archived'];
    }
  }

  String _getPhaseEmoji(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling: return '🌱';
      case PlantPhase.veg: return '🌿';
      case PlantPhase.bloom: return '🌸';
      case PlantPhase.harvest: return '✂️';
      case PlantPhase.archived: return '📦';
    }
  }
}
