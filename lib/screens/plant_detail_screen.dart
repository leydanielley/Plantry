// =============================================
// GROWLOG - Plant Detail Screen
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/log_fertilizer.dart';
import 'package:growlog_app/models/photo.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/screens/add_log_screen.dart';
import 'package:growlog_app/screens/edit_plant_screen.dart';
import 'package:growlog_app/screens/edit_log_screen.dart';
import 'package:growlog_app/screens/plant_photo_gallery_screen.dart';
import 'package:growlog_app/screens/add_harvest_screen.dart';
import 'package:growlog_app/screens/harvest_detail_screen.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_log_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/services/interfaces/i_harvest_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';

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
  
  late AppTranslations _t;
  final ScrollController _scrollController = ScrollController();

  late Plant _currentPlant;
  List<PlantLog> _logs = [];
  Map<int, List<LogFertilizer>> _logFertilizers = {};
  Map<int, Fertilizer> _fertilizers = {};
  Map<int, List<Photo>> _logPhotos = {};
  Harvest? _harvest;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _showTimeline = false;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMoreLogs) _loadMoreLogs();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _logs.clear();
      _hasMoreLogs = true;
    });

    try {
      final updatedPlant = await _plantRepo.findById(widget.plant.id!);
      if (updatedPlant == null) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final results = await Future.wait([
        _logRepo.findByPlant(widget.plant.id!, limit: _pageSize, offset: 0),
        _fertilizerRepo.findAll(),
        _harvestService.getHarvestForPlant(updatedPlant),
      ]);

      final logs = results[0] as List<PlantLog>;
      final fertilizers = results[1] as List<Fertilizer>;
      final harvest = results[2] as Harvest?;

      final logIds = logs.map((l) => l.id!).whereType<int>().toList();
      final detailResults = await Future.wait([
        _logFertilizerRepo.findByLogs(logIds),
        _photoRepo.getPhotosByLogIds(logIds),
      ]);

      if (mounted) {
        setState(() {
          _currentPlant = updatedPlant;
          _logs = logs;
          _fertilizers = {for (final f in fertilizers) f.id!: f};
          _logFertilizers = detailResults[0] as Map<int, List<LogFertilizer>>;
          _logPhotos = detailResults[1] as Map<int, List<Photo>>;
          _harvest = harvest;
          _hasMoreLogs = logs.length == _pageSize;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('PlantDetail', 'Error', e);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMore || !_hasMoreLogs) return;
    setState(() => _isLoadingMore = true);
    try {
      final newLogs = await _logRepo.findByPlant(_currentPlant.id!, limit: _pageSize, offset: _currentPage * _pageSize);
      final newLogIds = newLogs.map((l) => l.id!).whereType<int>().toList();
      final newFerts = await _logFertilizerRepo.findByLogs(newLogIds);
      final newPhotos = await _photoRepo.getPhotosByLogIds(newLogIds);

      if (mounted) {
        setState(() {
          _logs.addAll(newLogs);
          _logFertilizers.addAll(newFerts);
          _logPhotos.addAll(newPhotos);
          _currentPage++;
          _hasMoreLogs = newLogs.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _showLogOptions() async {
    if (_currentPlant.growId == null) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: _currentPlant)));
      if (result == true && mounted) _loadData();
      return;
    }

    final plantCount = await _growRepo.getPlantCount(_currentPlant.growId!);
    if (!mounted) return;

    if (plantCount <= 1) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: _currentPlant)));
      if (result == true && mounted) _loadData();
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(_t['create_entry'], style: const TextStyle(color: DT.textPrimary)),
        content: Text(_t['log_scope_question'], style: const TextStyle(color: DT.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'single'), child: Text(_t['only_this'])),
          TextButton(onPressed: () => Navigator.pop(context, 'bulk'), child: Text(_t['all_plants'], style: const TextStyle(color: DT.accent))),
        ],
      ),
    );

    if (choice == 'single' && mounted) {
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: _currentPlant)));
      if (result == true && mounted) _loadData();
    } else if (choice == 'bulk' && mounted) {
      final allPlants = await _plantRepo.findAll();
      if (!mounted) return;
      final growPlantIds = allPlants.where((p) => p.growId == _currentPlant.growId).map((p) => p.id!).toList();
      final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: _currentPlant, bulkMode: true, bulkPlantIds: growPlantIds)));
      if (result == true && mounted) _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _currentPlant.name,
      onBack: () => Navigator.pop(context, true),
      actions: [
        IconButton(
          icon: const Icon(Icons.photo_library, color: DT.textPrimary),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => PlantPhotoGalleryScreen(plant: _currentPlant)));
            _loadData();
          },
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: DT.textPrimary),
          onPressed: () async {
            final nav = Navigator.of(context);
            final res = await nav.push(MaterialPageRoute(builder: (_) => EditPlantScreen(plant: _currentPlant)));
            if (res == true) nav.pop(true);
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildViewToggle()),
                if (_showTimeline)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      child: _buildTimeline(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          if (i == _logs.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: DT.accent)));
                          return _buildLogCard(_logs[i]);
                        },
                        childCount: _logs.length + (_hasMoreLogs ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
      fab: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_harvest == null && (_currentPlant.phase == PlantPhase.bloom || _currentPlant.phase == PlantPhase.harvest))
            FloatingActionButton.extended(
              heroTag: 'harvest',
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddHarvestScreen(plant: _currentPlant)));
                if (res == true) _loadData();
              },
              backgroundColor: DT.accent,
              foregroundColor: DT.onAccent,
              label: Text(_t['plant_detail_harvest']),
              icon: const Icon(Icons.grass),
            ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'log',
            onPressed: _showLogOptions,
            backgroundColor: DT.accent,
            foregroundColor: DT.onAccent,
            label: Text(_t['plant_detail_log_entry']),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          PlantryCard(
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: _getPhaseColor(_currentPlant.phase).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                  child: Center(child: Text(_currentPlant.phase.prefix, style: TextStyle(color: _getPhaseColor(_currentPlant.phase), fontSize: 24, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentPlant.strain ?? _t['plant_detail_unknown_strain'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DT.textPrimary)),
                      Text(_currentPlant.breeder ?? _t['plant_detail_unknown_breeder'], style: const TextStyle(fontSize: 14, color: DT.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _infoBox(Icons.calendar_today, '${_currentPlant.totalDays} Tage', 'Alter')),
              const SizedBox(width: 12),
              Expanded(child: _infoBox(Icons.eco, _currentPlant.medium.displayName, 'Medium')),
              const SizedBox(width: 12),
              Expanded(child: _infoBox(Icons.psychology, _currentPlant.seedType.displayName, 'Typ')),
            ],
          ),
          if (_harvest != null) ...[
            const SizedBox(height: 12),
            PlantryCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HarvestDetailScreen(harvestId: _harvest!.id!))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: DT.success),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${_t['harvested_weight']} ${_harvest!.dryWeight?.toStringAsFixed(1) ?? "0"}g', style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary))),
                  const Icon(Icons.chevron_right, color: DT.textTertiary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String val, String label) {
    return PlantryCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, color: DT.accent, size: 20),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DT.textPrimary), textAlign: TextAlign.center),
          Text(label, style: const TextStyle(fontSize: 10, color: DT.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildLogCard(PlantLog log) {
    final ferts = _logFertilizers[log.id] ?? [];
    final photos = _logPhotos[log.id] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlantryCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getPhaseColor(log.phase ?? _currentPlant.phase), borderRadius: BorderRadius.circular(8)),
                  child: Text('${log.phase?.prefix ?? ""}${log.phaseDayNumber ?? ""}', style: const TextStyle(color: DT.canvas, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(log.actionType.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: DT.textPrimary))),
                Text(DateFormat('dd.MM.yy').format(log.logDate), style: const TextStyle(fontSize: 11, color: DT.textTertiary)),
                PopupMenuButton(
                  color: DT.elevated,
                  icon: const Icon(Icons.more_vert, size: 18, color: DT.textTertiary),
                  onSelected: (v) {
                    if (v == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => EditLogScreen(plant: _currentPlant, log: log))).then((_) => _loadData());
                    if (v == 'delete') _deleteLog(log);
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'edit', child: Text(_t['edit'], style: const TextStyle(color: DT.textPrimary))),
                    PopupMenuItem(value: 'delete', child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
                  ],
                ),
              ],
            ),
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photos.length,
                  itemBuilder: (ctx, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: InteractiveViewer(
                            child: Image.file(File(photos[i].filePath), fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(photos[i].filePath), width: 80, height: 80, fit: BoxFit.cover)),
                    ),
                  ),
                ),
              ),
            ],
            if (log.note != null && log.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(log.note!, style: const TextStyle(fontSize: 14, color: DT.textSecondary)),
            ],
            if (ferts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ferts.map((f) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: DT.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text('${_fertilizers[f.fertilizerId]?.name ?? "Dünger"}: ${f.amount}${f.unit}', style: const TextStyle(fontSize: 11, color: DT.accent)),
                )).toList(),
              ),
            ],
            if (log.waterAmount != null || log.phIn != null || log.ecIn != null) ...[
              const SizedBox(height: 8),
              Text('${log.waterAmount != null ? "${log.waterAmount}L " : ""}${log.phIn != null ? "pH: ${log.phIn} " : ""}${log.ecIn != null ? "EC: ${log.ecIn}" : ""}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DT.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: DT.elevated,
          borderRadius: BorderRadius.circular(DT.radiusButton),
          border: Border.all(color: DT.glassBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(child: _toggleBtn(_t['view_list'], !_showTimeline, () => setState(() => _showTimeline = false))),
            Expanded(child: _toggleBtn(_t['view_timeline'], _showTimeline, () => setState(() => _showTimeline = true))),
          ],
        ),
      ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DT.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(DT.radiusButton),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? DT.accent : DT.textSecondary,
          ),
        ),
      ),
    );
  }

  IconData _actionIcon(ActionType t) {
    switch (t) {
      case ActionType.water: return Icons.water_drop;
      case ActionType.feed: return Icons.science;
      case ActionType.trim: return Icons.content_cut;
      case ActionType.transplant: return Icons.swap_vert;
      case ActionType.training: return Icons.architecture;
      case ActionType.note: return Icons.notes;
      case ActionType.phaseChange: return Icons.flag;
      case ActionType.harvest: return Icons.agriculture;
      case ActionType.other: return Icons.more_horiz;
    }
  }

  Color _dotColor(ActionType t) {
    switch (t) {
      case ActionType.water:
      case ActionType.feed:
        return DT.secondary;
      case ActionType.phaseChange:
        return DT.accent;
      case ActionType.harvest:
        return DT.success;
      default:
        return DT.textSecondary;
    }
  }

  Widget _buildTimeline() {
    if (_logs.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(_logs.length, (i) {
        final log = _logs[i];
        final isFirst = i == 0;
        final isLast = i == _logs.length - 1;
        final isPhaseChange = log.actionType == ActionType.phaseChange;
        final isHarvest = log.actionType == ActionType.harvest;
        final dot = _dotColor(log.actionType);
        final dotSize = isPhaseChange ? 20.0 : 14.0;
        final lineColor = DT.textTertiary;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left timeline column
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    // Top line segment
                    if (!isFirst)
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: Container(width: 2, color: isPhaseChange ? DT.accent.withValues(alpha: 0.5) : lineColor),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    // Dot
                    Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dot,
                        boxShadow: isPhaseChange || isHarvest ? DT.glowShadow(dot) : null,
                      ),
                      child: Center(
                        child: Icon(
                          _actionIcon(log.actionType),
                          size: dotSize * 0.65,
                          color: isPhaseChange || isHarvest ? DT.onAccent : DT.canvas,
                        ),
                      ),
                    ),
                    // Bottom line segment
                    if (!isLast)
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(width: 2, color: lineColor),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right content column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: isPhaseChange
                        ? BoxDecoration(
                            color: DT.accent.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(DT.radiusCard),
                            border: Border.all(color: DT.accent.withValues(alpha: 0.3), width: 0.8),
                          )
                        : BoxDecoration(
                            color: DT.glassBackground,
                            borderRadius: BorderRadius.circular(DT.radiusCard),
                            border: Border.all(color: DT.glassBorder, width: 0.5),
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.actionType.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isPhaseChange ? 14 : 13,
                                  color: isPhaseChange ? DT.accent : DT.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              DateFormat('dd.MM.yyyy').format(log.logDate),
                              style: const TextStyle(fontSize: 11, color: DT.textTertiary),
                            ),
                          ],
                        ),
                        if (log.phaseDayNumber != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_t['timeline_day']} ${log.phaseDayNumber}',
                            style: const TextStyle(fontSize: 11, color: DT.textTertiary),
                          ),
                        ],
                        if (isPhaseChange && log.phase != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getPhaseColor(log.phase!).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(DT.radiusChip),
                            ),
                            child: Text(
                              log.phase!.prefix,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getPhaseColor(log.phase!),
                              ),
                            ),
                          ),
                        ],
                        if (log.note != null && log.note!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            log.note!,
                            style: const TextStyle(fontSize: 13, color: DT.textSecondary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _deleteLog(PlantLog log) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['confirm_delete'], style: const TextStyle(color: DT.textPrimary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
      ],
    ));
    if (ok == true) {
      await _logRepo.delete(log.id!);
      _loadData();
    }
  }

  Color _getPhaseColor(PlantPhase p) {
    switch (p) {
      case PlantPhase.seedling: return DT.success;
      case PlantPhase.veg: return DT.accent;
      case PlantPhase.bloom: return Colors.purple;
      case PlantPhase.harvest: return Colors.orange;
      case PlantPhase.archived: return DT.textTertiary;
    }
  }
}
