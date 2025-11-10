// =============================================
// GROWLOG - Plant Detail Screen (Dark Mode Ready + OPTIMIZED)
// ✅ FIX: Pagination + Lazy Loading für Logs
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/app_logger.dart';
import '../models/plant.dart';
import '../models/plant_log.dart';
import '../models/fertilizer.dart';
import '../models/log_fertilizer.dart';
import '../models/photo.dart';
import '../models/enums.dart';
import 'add_log_screen.dart';
import 'edit_plant_screen.dart';
import 'edit_log_screen.dart';
import 'plant_photo_gallery_screen.dart';
import 'add_harvest_screen.dart';
import 'harvest_detail_screen.dart';
import '../models/harvest.dart';
import '../repositories/interfaces/i_plant_log_repository.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../repositories/interfaces/i_grow_repository.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../repositories/interfaces/i_log_fertilizer_repository.dart';
import '../repositories/interfaces/i_photo_repository.dart';
import '../services/interfaces/i_harvest_service.dart';
import '../utils/app_messages.dart';
import '../di/service_locator.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;

  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ILogFertilizerRepository _logFertilizerRepo = getIt<ILogFertilizerRepository>();
  final IPhotoRepository _photoRepo = getIt<IPhotoRepository>();
  final IHarvestService _harvestService = getIt<IHarvestService>();

  final ScrollController _scrollController = ScrollController();

  late Plant _currentPlant;
  List<PlantLog> _logs = [];
  Map<int, List<LogFertilizer>> _logFertilizers = {};
  Map<int, Fertilizer> _fertilizers = {};
  Map<int, List<Photo>> _logPhotos = {};
  Harvest? _harvest;
  bool _isLoading = true;

  // ✅ FIX: Pagination für Logs
  bool _isLoadingMore = false;
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreLogs = true;

  @override
  void initState() {
    super.initState();
    _currentPlant = widget.plant;
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    // ✅ FIX: Remove listener before disposing to prevent memory leak
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ FIX: Lazy Loading für Logs
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreLogs) {
        _loadMoreLogs();
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _logs.clear();
      _logFertilizers.clear();
      _logPhotos.clear();
      _hasMoreLogs = true;
    });

    try {
      // Step 1: Plant laden (muss zuerst, weil wir die ID brauchen)
      final updatedPlant = await _plantRepo.findById(widget.plant.id!);
      if (updatedPlant == null) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
        return;
      }

      // ✅ PERFORMANCE: Step 2 - Logs, Fertilizers & Harvest parallel laden
      final results = await Future.wait([
        _logRepo.findByPlant(widget.plant.id!, limit: _pageSize, offset: 0),
        _fertilizerRepo.findAll(),
        _harvestService.getHarvestForPlant(updatedPlant),
      ]);

      final logs = results[0] as List<PlantLog>;
      final fertilizers = results[1] as List<Fertilizer>;
      final fertilizerMap = {for (var f in fertilizers) f.id!: f};
      final harvest = results[2] as Harvest?;

      // ✅ PERFORMANCE: Step 3 - Log Details parallel laden
      final logIds = logs.where((log) => log.id != null).map((log) => log.id!).toList();
      final detailResults = await Future.wait([
        _logFertilizerRepo.findByLogs(logIds),
        _photoRepo.getPhotosByLogIds(logIds),
      ]);

      final logFertilizersMap = detailResults[0] as Map<int, List<LogFertilizer>>;
      final logPhotosMap = detailResults[1] as Map<int, List<Photo>>;

      if (!mounted) return;

      setState(() {
        _currentPlant = updatedPlant;
        _logs = logs;
        _fertilizers = fertilizerMap;
        _logFertilizers = logFertilizersMap;
        _logPhotos = logPhotosMap;
        _harvest = harvest;
        _hasMoreLogs = logs.length == _pageSize;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('PlantDetailScreen', 'Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ✅ FIX: Mehr Logs nachladen beim Scrollen
  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMoreLogs) return;

    setState(() => _isLoadingMore = true);

    try {
      final newLogs = await _logRepo.findByPlant(
        _currentPlant.id!,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      // ✅ PERFORMANCE FIX: Batch-Query statt N+1
      final newLogIds = newLogs.where((log) => log.id != null).map((log) => log.id!).toList();
      final newLogFertilizers = await _logFertilizerRepo.findByLogs(newLogIds);
      final newLogPhotos = await _photoRepo.getPhotosByLogIds(newLogIds);

      // Merge in existing maps
      _logFertilizers.addAll(newLogFertilizers);
      _logPhotos.addAll(newLogPhotos);

      if (!mounted) return;

      setState(() {
        _logs.addAll(newLogs);
        _currentPage++;
        _hasMoreLogs = newLogs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('PlantDetailScreen', 'Error loading more logs: $e');
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _showLogOptions() async {
    if (_currentPlant.growId == null) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddLogScreen(plant: _currentPlant),
        ),
      );
      if (result == true) _loadData();
      return;
    }

    final plantCount = await _growRepo.getPlantCount(_currentPlant.growId!);

    if (!mounted) return;

    if (plantCount <= 1) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddLogScreen(plant: _currentPlant),
        ),
      );
      if (result == true && mounted) _loadData();
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log-Eintrag erstellen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Diese Pflanze gehört zu einem Grow mit $plantCount Pflanzen.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Was möchtest du loggen?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('single'),
            child: const Text('Nur diese Pflanze'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop('bulk'),
            icon: const Icon(Icons.group),
            label: Text('Alle $plantCount Pflanzen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'single' && mounted) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddLogScreen(plant: _currentPlant),
        ),
      );
      if (result == true && mounted) _loadData();
    } else if (choice == 'bulk') {
      final allPlants = await _plantRepo.findAll();
      final growPlantIds = allPlants
          .where((p) => p.growId == _currentPlant.growId)
          .map((p) => p.id!)
          .toList();

      if (!mounted) return;

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddLogScreen(
            plant: _currentPlant,
            bulkMode: true,
            bulkPlantIds: growPlantIds,
          ),
        ),
      );
      if (result == true && mounted) _loadData();
    }
  }

  Future<void> _deleteLog(PlantLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log löschen?'),
        content: const Text('Möchtest du diesen Log-Eintrag wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _logRepo.delete(log.id!);
        _loadData();
        if (mounted) {
          AppMessages.deletedSuccessfully(context, 'Log');
        }
      } catch (e) {
        AppLogger.error('PlantDetailScreen', 'Error deleting log: $e');
        if (mounted) {
          AppMessages.deletingError(context, e.toString());
        }
      }
    }
  }

  Future<void> _editLog(PlantLog log) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditLogScreen(
          plant: _currentPlant,
          log: log,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  void _showPhotoDialog(Photo photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(
                  File(photo.filePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 30),
                onPressed: () => _deletePhoto(photo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto(Photo photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Foto löschen?'),
        content: const Text('Möchtest du dieses Foto wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final file = File(photo.filePath);
        if (await file.exists()) {
          await file.delete();
        }

        await _photoRepo.deletePhoto(photo.id!);

        if (mounted) {
          Navigator.of(context).pop();
        }

        _loadData();

        if (mounted) {
          AppMessages.deletedSuccessfully(context, 'Foto');
        }
      } catch (e) {
        AppLogger.error('PlantDetailScreen', 'Error deleting photo: $e');
        if (mounted) {
          AppMessages.deletingError(context, e.toString());
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentPlant.name),
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PlantPhotoGalleryScreen(plant: _currentPlant),
                  ),
                );
                _loadData();
              },
              tooltip: 'Foto-Galerie',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                if (!mounted) return;
                final nav = Navigator.of(context);
                final result = await nav.push(
                  MaterialPageRoute(
                    builder: (context) => EditPlantScreen(plant: _currentPlant),
                  ),
                );
                if (result == true && mounted) {
                  nav.pop(true);
                }
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildPlantInfo(isDark),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                  ? _buildEmptyLogs()
                  : _buildLogList(isDark),
            ),
          ],
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if ((_currentPlant.phase == PlantPhase.bloom ||
                _currentPlant.phase == PlantPhase.harvest) && _harvest == null)
              FloatingActionButton.extended(
                heroTag: 'harvest',
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AddHarvestScreen(plant: _currentPlant),
                    ),
                  );
                  if (result == true) _loadData();
                },
                icon: const Icon(Icons.grass),
                label: const Text('Ernte'),
                backgroundColor: const Color(0xFF004225),
              ),
            if ((_currentPlant.phase == PlantPhase.bloom ||
                _currentPlant.phase == PlantPhase.harvest) && _harvest == null)
              const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'log',
              onPressed: () async {
                await _showLogOptions();
              },
              icon: const Icon(Icons.add),
              label: const Text('Log Entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? Colors.grey[900] : Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _getPhaseColor(_currentPlant.phase),
                child: Text(
                  _currentPlant.phase.prefix,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentPlant.strain ?? 'Unknown Strain',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _currentPlant.breeder ?? 'Unknown Breeder',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoChip(
                Icons.calendar_today,
                'Tag ${_currentPlant.totalDays}',
                isDark,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.grass,
                _currentPlant.medium.displayName,
                isDark,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.psychology,
                _currentPlant.seedType.displayName,
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(
                Icons.auto_awesome,
                '${_currentPlant.phase.displayName} (${_currentPlant.phaseDays}d)',
                isDark,
                color: _getPhaseColor(_currentPlant.phase),
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.local_florist,
                _currentPlant.containerInfo,
                isDark,
                color: Colors.brown[600],
              ),
            ],
          ),
          if (_harvest != null)
            const SizedBox(height: 12),
          if (_harvest != null && _harvest!.id != null)
            InkWell(
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => HarvestDetailScreen(
                      harvestId: _harvest!.id!,
                    ),
                  ),
                );
                _loadData();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ✅ FIX: Replace force unwrap with null-aware operator
                  color: isDark ? (Colors.green[900] ?? Colors.green).withValues(alpha: 0.3) : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green[600] ?? Colors.green,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.grass,
                      color: Colors.green[600],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✅ Geerntet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                          if (_harvest!.dryWeight != null)
                            Text(
                              '⚖️ ${_harvest!.dryWeight!.toStringAsFixed(1)}g',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          Text(
                            'Status: ${_harvest!.dryingStatus} / ${_harvest!.curingStatus}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.green[600],
                    ),
                  ],
                ),
              ),
            )
          else if (_harvest != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                // ✅ FIX: Replace force unwrap with null-aware operator
                border: Border.all(color: Colors.red[300] ?? Colors.red, width: 2),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Fehler bei Ernte-Daten',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        Text(
                          'Ernte-ID fehlt - bitte Support kontaktieren',
                          style: TextStyle(fontSize: 12, color: Colors.red[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, bool isDark, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color != null
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color != null
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLogs() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Noch keine Logs',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge den ersten Log-Eintrag hinzu!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,  // ✅ FIX: ScrollController attached
      itemCount: _logs.length + (_hasMoreLogs || _isLoadingMore ? 1 : 0),  // ✅ FIX: +1 für Loading
      padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 80),
      itemBuilder: (context, index) {
        // ✅ FIX: Loading Indicator am Ende
        if (index == _logs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final log = _logs[index];
        return _buildLogCard(log, isDark);
      },
    );
  }

  Widget _buildLogCard(PlantLog log, bool isDark) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final logFerts = log.id != null ? _logFertilizers[log.id!] : null;
    final photos = log.id != null ? _logPhotos[log.id!] : null;
    final textColor = isDark ? Colors.grey[300] : Colors.grey[700];

    // ✅ PERFORMANCE: RepaintBoundary isoliert jede Card für flüssigeres Scrolling
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                // ✅ v13: Phase-Tag PROMINENT
                if (log.phase != null && log.phaseDayNumber != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getPhaseColor(log.phase!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${log.phase!.prefix}${log.phaseDayNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  // Fallback für alte Logs ohne Phase
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getActionTypeColor(log.actionType),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Tag ${log.dayNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  log.actionType.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (photos != null && photos.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                      // ✅ FIX: Replace force unwrap with null-aware operator
                      border: Border.all(color: Colors.blue[300] ?? Colors.blue, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${photos.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // ✅ Gesamt-Tag als Info rechts
                Text(
                  'Gesamt: Tag ${log.dayNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Bearbeiten', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Löschen', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editLog(log);
                    } else if (value == 'delete') {
                      _deleteLog(log);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(log.logDate),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),

            if (photos != null && photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => _showPhotoDialog(photo),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photo.filePath),
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 120,
                                height: 120,
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                child: Icon(
                                  Icons.broken_image,
                                  color: isDark ? Colors.grey[600] : Colors.grey[600],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            if (log.actionType == ActionType.transplant) ...[
              const SizedBox(height: 8),
              if (log.containerSize != null) ...[
                Row(
                  children: [
                    Icon(Icons.local_florist, size: 16, color: Colors.brown[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${log.containerSize!.toStringAsFixed(0)}L Topf',
                      style: TextStyle(color: textColor),
                    ),
                    if (log.containerMediumAmount != null) ...[
                      Text(
                        ' • ${log.containerMediumAmount!.toStringAsFixed(1)}L Medium',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ],
                ),
              ],
              if (log.systemReservoirSize != null) ...[
                Row(
                  children: [
                    Icon(Icons.water, size: 16, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${log.systemReservoirSize!.toStringAsFixed(0)}L System',
                      style: TextStyle(color: textColor),
                    ),
                    if (log.systemBucketCount != null) ...[
                      Text(
                        ' • ${log.systemBucketCount} Buckets',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ],
                ),
              ],
              if (log.containerDrainage && log.containerDrainageMaterial != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.layers, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Drainage: ${log.containerDrainageMaterial}',
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ),
              ],
            ],

            if (log.waterAmount != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.water_drop, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${log.waterAmount}L',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ],

            if (logFerts != null && logFerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...logFerts.map((logFert) {
                final fertilizer = _fertilizers[logFert.fertilizerId];
                if (fertilizer == null) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.science, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${fertilizer.name}: ${logFert.amount.toStringAsFixed(1)}${logFert.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            if (log.phIn != null || log.ecIn != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (log.phIn != null) ...[
                    Text(
                      'pH: ${log.phIn?.toStringAsFixed(1)} ',
                      style: TextStyle(color: textColor),
                    ),
                  ],
                  if (log.ecIn != null) ...[
                    Text(
                      'EC: ${log.ecIn?.toStringAsFixed(1)}',
                      style: TextStyle(color: textColor),
                    ),
                  ],
                ],
              ),
            ],
            if (log.note != null) ...[
              const SizedBox(height: 8),
              Text(
                log.note!,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  // ✅ FIX: Replace all force unwraps with null-aware operators
  Color _getPhaseColor(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return Colors.green[300] ?? Colors.green;
      case PlantPhase.veg:
        return Colors.green[600] ?? Colors.green;
      case PlantPhase.bloom:
        return Colors.purple[400] ?? Colors.purple;
      case PlantPhase.harvest:
        return Colors.orange[600] ?? Colors.orange;
      case PlantPhase.archived:
        return Colors.grey[600] ?? Colors.grey;
    }
  }

  Color _getActionTypeColor(ActionType actionType) {
    switch (actionType) {
      case ActionType.water:
        return Colors.blue[600] ?? Colors.blue;
      case ActionType.feed:
        return Colors.green[600] ?? Colors.green;
      case ActionType.trim:
        return Colors.teal[600] ?? Colors.teal;
      case ActionType.training:
        return Colors.indigo[600] ?? Colors.indigo;
      case ActionType.note:
        return Colors.grey[600] ?? Colors.grey;
      case ActionType.phaseChange:
        return Colors.purple[600] ?? Colors.purple;
      case ActionType.transplant:
        return Colors.orange[600] ?? Colors.orange;
      case ActionType.harvest:
        return Colors.red[600] ?? Colors.red;
      case ActionType.other:
        return Colors.brown[600] ?? Colors.brown;
    }
  }
}