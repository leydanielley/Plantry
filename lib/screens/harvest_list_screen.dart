// =============================================
// GROWLOG - Harvest List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/widgets/plantry_chips.dart';
import 'package:growlog_app/screens/harvest_detail_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/theme/design_tokens.dart';

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

  final List<String> _filterKeys = ['all', 'drying', 'curing', 'completed'];

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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final harvests = await _harvestRepo.getAllHarvestsWithPlants();
      if (mounted) {
        setState(() {
          _harvests = harvests;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('HarvestListScreen', 'Error: $e');
      if (mounted) setState(() => _isLoading = false);
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
    final filterLabels = [
      _t['all'], 
      _t['in_drying'], 
      _t['in_curing'], 
      _t['completed']
    ];

    return PlantryScaffold(
      title: _t['harvests'],
      body: Column(
        children: [
          const SizedBox(height: 16),
          PlantryFilterChips(
            labels: filterLabels,
            selectedIndex: _filterKeys.indexOf(_filter),
            onSelected: (index) {
              setState(() => _filter = _filterKeys[index]);
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: DT.accent))
                : _filteredHarvests.isEmpty
                ? _buildEmptyState()
                : _buildHarvestList(),
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
          const Icon(Icons.grass_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(
            _filter == 'all' ? _t['no_harvests_yet'] : _t['no_harvests_found'],
            style: const TextStyle(fontSize: 20, color: DT.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _filter == 'all' ? _t['record_first_harvest'] : _t['no_harvests_filter'],
            style: const TextStyle(fontSize: 16, color: DT.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestList() {
    return RefreshIndicator(
      onRefresh: _loadHarvests,
      color: DT.accent,
      backgroundColor: DT.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        itemCount: _filteredHarvests.length,
        itemBuilder: (context, index) {
          final harvestData = _filteredHarvests[index];
          final harvest = Harvest.fromMap(harvestData);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlantryListTile(
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(harvest).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.grass_rounded, color: _getStatusColor(harvest), size: 28),
              ),
              title: harvestData['plant_name'] as String,
              subtitle: '${harvestData['plant_strain'] ?? "Unbekannt"}\n${DateFormat('dd.MM.yyyy').format(harvest.harvestDate)}${harvest.dryWeight != null ? ' • ${harvest.dryWeight!.toStringAsFixed(1)}g' : ''}',
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HarvestDetailScreen(harvestId: harvest.id!)),
                );
                _loadHarvests();
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(Harvest harvest) {
    if (harvest.isComplete) return DT.success;
    if (harvest.curingStartDate != null) return DT.info;
    if (harvest.dryingStartDate != null) return DT.warning;
    return DT.textTertiary;
  }
}
