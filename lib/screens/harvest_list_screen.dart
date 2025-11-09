// =============================================
// GROWLOG - Harvest List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_logger.dart';
import '../models/harvest.dart';
import '../repositories/interfaces/i_harvest_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';
import 'harvest_detail_screen.dart';
import '../di/service_locator.dart';

class HarvestListScreen extends StatefulWidget {
  const HarvestListScreen({super.key});

  @override
  State<HarvestListScreen> createState() => _HarvestListScreenState();
}

class _HarvestListScreenState extends State<HarvestListScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  
  List<Map<String, dynamic>> _harvests = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, drying, curing, completed
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadHarvests();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadHarvests() async {
    setState(() => _isLoading = true);

    try {
      AppLogger.info('HarvestListScreen', 'Loading harvests...');
      final harvests = await _harvestRepo.getAllHarvestsWithPlants();
      AppLogger.info('HarvestListScreen', 'Loaded ${harvests.length} harvests');

      setState(() {
        _harvests = harvests;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('HarvestListScreen', 'Error: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredHarvests {
    switch (_filter) {
      case 'drying':
        return _harvests.where((h) {
          final harvest = Harvest.fromMap(h);
          return harvest.dryingStartDate != null && harvest.dryingEndDate == null;
        }).toList();
      case 'curing':
        return _harvests.where((h) {
          final harvest = Harvest.fromMap(h);
          return harvest.curingStartDate != null && harvest.curingEndDate == null;
        }).toList();
      case 'completed':
        return _harvests.where((h) {
          final harvest = Harvest.fromMap(h);
          return harvest.isComplete;
        }).toList();
      default:
        return _harvests;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['harvests']),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: AppConstants.paddingMedium,
            color: Colors.green[50],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(_t['all'], 'all'),
                  const SizedBox(width: AppConstants.spacingSmall),
                  _buildFilterChip(_t['in_drying'], 'drying'),
                  const SizedBox(width: AppConstants.spacingSmall),
                  _buildFilterChip(_t['in_curing'], 'curing'),
                  const SizedBox(width: AppConstants.spacingSmall),
                  _buildFilterChip(_t['completed'], 'completed'),
                ],
              ),
            ),
          ),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHarvests.isEmpty
                    ? _buildEmptyState()
                    : _buildHarvestList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      selectedColor: Colors.green[200],
      checkmarkColor: Colors.green[700],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.grass, 
            size: AppConstants.emptyStateIconSize, 
            color: Colors.grey[400]
          ),
          const SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _filter == 'all' ? _t['no_harvests_yet'] : _t['no_harvests_found'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge, 
              color: Colors.grey[600]
            ),
          ),
          const SizedBox(height: AppConstants.emptyStateSpacingMiddle),
          Text(
            _filter == 'all' 
                ? _t['record_first_harvest'] 
                : _t['no_harvests_filter'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium, 
              color: Colors.grey[500]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestList() {
    return ListView.builder(
      padding: AppConstants.listPadding,
      itemCount: _filteredHarvests.length,
      itemBuilder: (context, index) {
        final harvestData = _filteredHarvests[index];
        final harvest = Harvest.fromMap(harvestData);
        
        return Card(
          margin: AppConstants.cardMarginVertical,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(harvest),
              child: const Icon(Icons.grass, color: Colors.white),
            ),
            title: Text(
              harvestData['plant_name'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (harvestData['plant_strain'] != null)
                  Text(harvestData['plant_strain'] as String),
                const SizedBox(height: AppConstants.spacingXs),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today, 
                      size: AppConstants.fontSizeSmall, 
                      color: Colors.grey[600]
                    ),
                    const SizedBox(width: AppConstants.listItemIconSpacing),
                    Text(
                      DateFormat('dd.MM.yyyy').format(harvest.harvestDate),
                      style: TextStyle(
                        fontSize: AppConstants.fontSizeSmall, 
                        color: Colors.grey[600]
                      ),
                    ),
                    if (harvest.dryWeight != null) ...[
                      const SizedBox(width: AppConstants.listItemSpacingMedium),
                      Icon(
                        Icons.scale, 
                        size: AppConstants.fontSizeSmall, 
                        color: Colors.grey[600]
                      ),
                      const SizedBox(width: AppConstants.listItemIconSpacing),
                      Text(
                        '${harvest.dryWeight!.toStringAsFixed(1)}g',
                        style: TextStyle(
                          fontSize: AppConstants.fontSizeSmall,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppConstants.spacingXs),
                Text(
                  '${harvest.dryingStatus} • ${harvest.curingStatus}',
                  style: TextStyle(
                    fontSize: AppConstants.roomDimensionsFontSize, 
                    color: Colors.grey[500]
                  ),
                ),
              ],
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios, 
              size: AppConstants.spacingMedium
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HarvestDetailScreen(harvestId: harvest.id!),
                ),
              );
              _loadHarvests();
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(Harvest harvest) {
    if (harvest.isComplete) return Colors.green;
    if (harvest.curingStartDate != null) return Colors.purple;
    if (harvest.dryingStartDate != null) return Colors.orange;
    return Colors.grey;
  }
}
