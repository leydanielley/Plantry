// =============================================
// GROWLOG - Plants Screen (GROUPED BY GROWS)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/plant.dart';
import '../models/grow.dart';
import '../models/room.dart';
import '../models/enums.dart';
import '../repositories/plant_repository.dart';
import '../repositories/grow_repository.dart';
import '../repositories/room_repository.dart';
import 'plant_detail_screen.dart';
import 'add_plant_screen.dart';
import '../widgets/widgets.dart';
import '../repositories/settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';

class PlantsScreen extends StatefulWidget {
  const PlantsScreen({super.key});

  @override
  State<PlantsScreen> createState() => _PlantsScreenState();
}

class _PlantsScreenState extends State<PlantsScreen> {
  final PlantRepository _plantRepo = PlantRepository();
  final GrowRepository _growRepo = GrowRepository();
  final RoomRepository _roomRepo = RoomRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  
  List<Plant> _allPlants = [];
  List<Grow> _allGrows = [];
  Map<int, Room> _roomsById = {};
  Map<int?, List<Plant>> _plantsByGrow = {};
  bool _isLoading = true;
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
    setState(() => _isLoading = true);

    try {
      // Load all plants, grows and rooms
      final plants = await _plantRepo.findAll();
      final grows = await _growRepo.getAll(includeArchived: true);
      final rooms = await _roomRepo.findAll();

      // Create room map by id
      final Map<int, Room> roomMap = {};
      for (var room in rooms) {
        if (room.id != null) {
          roomMap[room.id!] = room;
        }
      }

      // Group plants by growId
      final Map<int?, List<Plant>> grouped = {};
      
      for (var plant in plants) {
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
      orElse: () => Grow(
        name: _t['unknown_grow'],
        startDate: DateTime.now(),
      ),
    );
    
    return grow.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['plants']),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddPlantScreen(),
            ),
          );
          if (result == true) _loadData();
        },
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add),
        label: Text(_t['new_plant']),
      ),
    );
  }

  Widget _buildContent() {
    if (_allPlants.isEmpty) {
      return _buildEmptyState();
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return ListView(
      padding: EdgeInsets.only(
        left: AppConstants.spacingMedium,
        right: AppConstants.spacingMedium,
        top: AppConstants.spacingMedium,
        bottom: bottomPadding > 0 
            ? bottomPadding + AppConstants.fabBottomPaddingSmall 
            : AppConstants.fabBottomPaddingLarge,
      ),
      children: _buildGroupedPlants(),
    );
  }

  List<Widget> _buildGroupedPlants() {
    final List<Widget> widgets = [];

    // Sort grows: first with grow, then without grow
    final sortedGrowIds = _plantsByGrow.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;  // null (without grow) comes last
        if (b == null) return -1;
        return 0;
      });

    for (var growId in sortedGrowIds) {
      final plants = _plantsByGrow[growId]!;
      
      widgets.add(_buildGrowHeader(growId, plants.length));
      widgets.add(SizedBox(height: AppConstants.borderRadiusMedium));
      
      for (var plant in plants) {
        widgets.add(_buildPlantCard(plant));
        widgets.add(SizedBox(height: AppConstants.spacingSmall));
      }
      
      widgets.add(SizedBox(height: AppConstants.spacingLarge));
    }

    return widgets;
  }

  Widget _buildGrowHeader(int? growId, int plantCount) {
    final growName = _getGrowName(growId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get room icon from grow
    IconData headerIcon = Icons.park;  // Default: Outdoor
    Color? iconColor = Colors.green[600];
    
    if (growId != null) {
      final grow = _allGrows.firstWhere(
        (g) => g.id == growId,
        orElse: () => Grow(name: '', startDate: DateTime.now()),
      );


      AppLogger.debug('PlantsScreen', 'Grow "${grow.name}" has roomId: ${grow.roomId}');
      if (grow.roomId != null && _roomsById.containsKey(grow.roomId)) {
        final room = _roomsById[grow.roomId];
        AppLogger.debug('PlantsScreen', 'Found room: ${room?.name} with type: ${room?.growType}');
        if (room != null && room.growType != null) {
          switch (room.growType!) {
            case GrowType.indoor:
              headerIcon = Icons.home;
              iconColor = Colors.blue[600];
              break;
            case GrowType.outdoor:
              headerIcon = Icons.park;
              iconColor = Colors.green[600];
              break;
            case GrowType.greenhouse:
              headerIcon = Icons.home_work;
              iconColor = Colors.orange[600];
              break;
          }
        }
      } else {
        // Grow hat keinen Room - default Icon
        headerIcon = Icons.spa;
        iconColor = Colors.green[600];
      }
    }
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.growHeaderPaddingHorizontal,
        vertical: AppConstants.growHeaderPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkModePrimary : AppConstants.lightModePrimary,
        borderRadius: BorderRadius.circular(AppConstants.growHeaderBorderRadius),
      ),
      child: Row(
        children: [
          // Room Icon
          Icon(
            headerIcon,
            size: AppConstants.growHeaderEmojiSize,
            color: iconColor,
          ),
          
          SizedBox(width: AppConstants.growHeaderSpacing),
          
          // Grow Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  growName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$plantCount ${plantCount == 1 ? _t['plant'] : _t['plants_count']}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Arrow
          Container(
            padding: EdgeInsets.all(AppConstants.plantCardArrowPadding),
            decoration: BoxDecoration(
              color: isDark ? AppConstants.darkModeSecondary : AppConstants.lightModeSecondary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: AppConstants.plantCardArrowSize,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantCard(Plant plant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppConstants.darkModePrimary : AppConstants.lightModePrimary,
        borderRadius: BorderRadius.circular(AppConstants.plantCardBorderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.plantCardBorderRadius),
          onTap: () async {
            final result = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlantDetailScreen(plant: plant),
              ),
            );
            if (result == true) {
              _loadData();
            }
          },
          child: Padding(
            padding: EdgeInsets.all(AppConstants.plantCardPadding),
            child: Row(
              children: [
                // Phase Emoji Container
                Container(
                  padding: EdgeInsets.all(AppConstants.plantCardEmojiBgPadding),
                  decoration: BoxDecoration(
                    color: isDark ? AppConstants.darkModeSecondary : AppConstants.lightModeSecondary,
                    borderRadius: BorderRadius.circular(AppConstants.plantCardEmojiBgRadius),
                  ),
                  child: Text(
                    _getPhaseEmoji(plant.phase),
                    style: TextStyle(fontSize: AppConstants.plantCardEmojiSize),
                  ),
                ),
                
                SizedBox(width: AppConstants.spacingMedium),
                
                // Plant Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppConstants.spacingXs),
                      Text(
                        plant.strain ?? _t['unknown_strain'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: AppConstants.spacingSmall),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: AppConstants.listItemIconSize,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          SizedBox(width: AppConstants.listItemIconSpacing),
                          Text(
                            '${_t['day']} ${plant.totalDays}',
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontSize: AppConstants.fontSizeSmall,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: AppConstants.spacingMedium),
                          Icon(
                            Icons.label,
                            size: AppConstants.listItemIconSize,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                          SizedBox(width: AppConstants.listItemIconSpacing),
                          Text(
                            _getPhaseName(plant.phase),
                            style: TextStyle(
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                              fontSize: AppConstants.fontSizeSmall,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                Container(
                  padding: EdgeInsets.all(AppConstants.plantCardArrowPadding),
                  decoration: BoxDecoration(
                    color: isDark ? AppConstants.darkModeSecondary : AppConstants.lightModeSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: AppConstants.plantCardArrowSize,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlantPotIcon(
            size: AppConstants.emptyStateIconSize,
            leavesColor: Colors.grey[400],
            stemColor: Colors.grey[500],
            potColor: Colors.grey[400],
          ),
          SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _t['no_plants_available'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppConstants.emptyStateSpacingMiddle),
          Text(
            _t['create_first_plant'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Color _getPhaseColor(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return Colors.green[300]!;
      case PlantPhase.veg:
        return Colors.green[600]!;
      case PlantPhase.bloom:
        return Colors.purple[400]!;
      case PlantPhase.harvest:
        return Colors.orange[600]!;
      case PlantPhase.archived:
        return Colors.grey[600]!;
    }
  }

  String _getPhaseName(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return _t['seedling'];
      case PlantPhase.veg:
        return _t['veg'];
      case PlantPhase.bloom:
        return _t['bloom'];
      case PlantPhase.harvest:
        return _t['harvest'];
      case PlantPhase.archived:
        return _t['phase_archived'];
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
