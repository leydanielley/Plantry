// =============================================
// GROWLOG - Grow Detail Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/screens/plant_detail_screen.dart';
import 'package:growlog_app/screens/add_log_screen.dart';
import 'package:growlog_app/screens/add_plant_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/database/database_helper.dart';

class GrowDetailScreen extends StatefulWidget {
  final Grow grow;
  const GrowDetailScreen({super.key, required this.grow});

  @override
  State<GrowDetailScreen> createState() => _GrowDetailScreenState();
}

class _GrowDetailScreenState extends State<GrowDetailScreen> {
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  List<Plant> _plants = [];
  List<Map<String, dynamic>> _fertilizerUsage = [];
  List<Harvest> _harvests = [];
  Room? _room;
  late AppTranslations _t;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadPlants();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) setState(() => _t = AppTranslations(settings.language));
  }

  Future<void> _loadPlants() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final all = await _plantRepo.findAll();
      final growPlants = all.where((p) => p.growId == widget.grow.id).toList();
      List<Map<String, dynamic>> fertilizerUsage = [];
      if (growPlants.isNotEmpty) {
        final plantIds = growPlants.map((p) => p.id!).toList();
        final placeholders = List.filled(plantIds.length, '?').join(',');
        final db = await DatabaseHelper.instance.database;
        fertilizerUsage = await db.rawQuery('''
          SELECT f.id, f.name, f.brand, f.npk,
                 SUM(lf.amount) as total_ml,
                 COUNT(DISTINCT lf.log_id) as uses
          FROM log_fertilizers lf
          JOIN plant_logs pl ON lf.log_id = pl.id
          JOIN fertilizers f ON lf.fertilizer_id = f.id
          WHERE pl.plant_id IN ($placeholders)
          GROUP BY f.id
          ORDER BY total_ml DESC
        ''', plantIds);
      }
      final harvests = widget.grow.id != null
          ? await _harvestRepo.getHarvestsByGrowId(widget.grow.id!)
          : <Harvest>[];
      Room? room;
      if (widget.grow.roomId != null) {
        room = await _roomRepo.findById(widget.grow.roomId!);
      }
      if (mounted) setState(() { _plants = growPlants; _fertilizerUsage = fertilizerUsage; _harvests = harvests; _room = room; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: widget.grow.name,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Column(
              children: [
                _buildHeader(),
                if (_harvests.isNotEmpty) _buildYieldCard(),
                if (_fertilizerUsage.isNotEmpty) _buildFertilizerUsage(),
                Expanded(child: _plants.isEmpty ? _buildEmpty() : _buildList()),
              ],
            ),
      fab: _plants.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddOptions,
              backgroundColor: DT.accent,
              foregroundColor: DT.onAccent,
              icon: const Icon(Icons.add),
              label: Text(_t['grow_detail_add_plant_dialog_title']),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add',
                  onPressed: _showAddOptions,
                  backgroundColor: DT.accent,
                  foregroundColor: DT.onAccent,
                  icon: const Icon(Icons.add),
                  label: Text(_t['grow_detail_plant_tab']),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'log',
                  onPressed: _bulkLog,
                  backgroundColor: DT.secondary,
                  foregroundColor: DT.canvas,
                  icon: const Icon(Icons.edit_note),
                  label: Text(_t['grow_detail_bulk_log_tab']),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: PlantryCard(
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.eco_rounded, color: DT.accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.grow.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DT.textPrimary)),
                      Text(widget.grow.status, style: const TextStyle(fontSize: 13, color: DT.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Tag ${widget.grow.totalDays}', 'Alter'),
                _stat('${_plants.length}', 'Pflanzen'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DT.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 11, color: DT.textSecondary)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.spa_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 16),
          Text(_t['grow_detail_no_plants_title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DT.textPrimary)),
          Text(_t['grow_detail_no_plants_subtitle'], style: const TextStyle(color: DT.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildYieldCard() {
    final totalDry = _harvests.fold<double>(0, (sum, h) => sum + (h.dryWeight ?? 0));
    final harvestsWithDry = _harvests.where((h) => h.dryWeight != null).length;
    final avgPerPlant = harvestsWithDry > 0 ? totalDry / harvestsWithDry : null;
    final area = _room?.area;
    final gPerSqm = (totalDry > 0 && area != null && area > 0) ? totalDry / area : null;
    final lightWatts = _room?.lightWatts;
    final gPerWatt = (totalDry > 0 && lightWatts != null && lightWatts > 0) ? totalDry / lightWatts : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t['grow_yield_section'].toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: DT.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          PlantryCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _yieldStat('${_harvests.length}', _t['grow_yield_harvests']),
                    if (totalDry > 0)
                      _yieldStat('${totalDry.toStringAsFixed(1)}g', _t['grow_yield_total_dry']),
                    if (avgPerPlant != null)
                      _yieldStat('${avgPerPlant.toStringAsFixed(1)}g', _t['grow_yield_avg_per_plant']),
                    if (gPerSqm != null)
                      _yieldStat(gPerSqm.toStringAsFixed(1), 'g/m²'),
                    if (gPerWatt != null)
                      _yieldStat(gPerWatt.toStringAsFixed(1), _t['yield_per_watt']),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yieldStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DT.accent)),
        Text(label, style: const TextStyle(fontSize: 11, color: DT.textSecondary)),
      ],
    );
  }

  Widget _buildFertilizerUsage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DÜNGER-VERBRAUCH',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              color: DT.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          PlantryCard(
            child: Column(
              children: [
                for (int i = 0; i < _fertilizerUsage.length; i++) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fertilizerUsage[i]['name'] as String? ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: DT.textPrimary,
                              ),
                            ),
                            Text(
                              [
                                _fertilizerUsage[i]['brand'] as String?,
                                _fertilizerUsage[i]['npk'] as String?,
                              ].where((s) => s != null && s.isNotEmpty).join(' • '),
                              style: const TextStyle(
                                fontSize: 11,
                                color: DT.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_fertilizerUsage[i]['total_ml']} ml',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: DT.accent,
                            ),
                          ),
                          Text(
                            '${_fertilizerUsage[i]['uses']}× genutzt',
                            style: const TextStyle(
                              fontSize: 10,
                              color: DT.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (i < _fertilizerUsage.length - 1)
                    const Divider(color: DT.border, height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: _plants.length,
      itemBuilder: (ctx, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PlantryListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(_getEmoji(_plants[i].phase), style: const TextStyle(fontSize: 24))),
          ),
          title: _plants[i].name,
          subtitle: '${_plants[i].strain ?? "Unbekannt"} • Tag ${_plants[i].totalDays}',
          onTap: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: _plants[i])));
            if (res == true) _loadPlants();
          },
        ),
      ),
    );
  }

  String _getEmoji(PlantPhase p) {
    switch (p) {
      case PlantPhase.seedling: return '🌱';
      case PlantPhase.veg: return '🌿';
      case PlantPhase.bloom: return '🌸';
      case PlantPhase.harvest: return '✂️';
      case PlantPhase.archived: return '📦';
    }
  }

  Future<void> _showAddOptions() async {
    final res = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['grow_detail_add_plant_dialog_title'], style: const TextStyle(color: DT.textPrimary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'existing'), child: Text(_t['assign'], style: const TextStyle(color: DT.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, 'new'), child: Text(_t['create_new'], style: const TextStyle(color: DT.accent))),
      ],
    ));
    if (!mounted) return;
    if (res == 'new') {
      final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPlantScreen(preselectedGrowId: widget.grow.id)));
      if (r == true) _loadPlants();
    } else if (res == 'existing') {
      _assignExisting();
    }
  }

  Future<void> _assignExisting() async {
    final all = await _plantRepo.findAll();
    final avail = all.where((p) => p.growId != widget.grow.id).toList();
    if (!mounted) return;
    if (avail.isEmpty) { AppMessages.showSuccess(context, 'Keine verfügbaren Pflanzen'); return; }

    final sel = await showDialog<Plant>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['select_plant'], style: const TextStyle(color: DT.textPrimary)),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(
        shrinkWrap: true,
        itemCount: avail.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(avail[i].name, style: const TextStyle(color: DT.textPrimary)),
          onTap: () => Navigator.pop(ctx, avail[i]),
        ),
      )),
    ));
    if (sel != null) {
      await _plantRepo.save(sel.copyWith(growId: widget.grow.id));
      _loadPlants();
    }
  }

  Future<void> _bulkLog() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddLogScreen(plant: _plants.first, bulkMode: true, bulkPlantIds: _plants.map((p) => p.id!).toList())));
    if (res == true) _loadPlants();
  }
}
