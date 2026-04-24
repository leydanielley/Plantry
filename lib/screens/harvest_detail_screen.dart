// =============================================
// GROWLOG - Harvest Detail Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/screens/edit_harvest_screen.dart';
import 'package:growlog_app/screens/harvest_drying_screen.dart';
import 'package:growlog_app/screens/harvest_curing_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class HarvestDetailScreen extends StatefulWidget {
  final int harvestId;
  const HarvestDetailScreen({super.key, required this.harvestId});

  @override
  State<HarvestDetailScreen> createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  Harvest? _harvest;
  Map<String, dynamic>? _harvestWithPlant;
  Room? _room;
  bool _isLoading = true;
  late AppTranslations _t;

  @override
  void initState() {
    super.initState();
    _loadHarvest();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  Future<void> _loadHarvest() async {
    setState(() => _isLoading = true);
    try {
      final hwp = await _harvestRepo.getHarvestWithPlant(widget.harvestId);
      final h = await _harvestRepo.getHarvestById(widget.harvestId);
      Room? room;
      if (hwp != null) {
        final plantId = hwp['plant_id'] as int?;
        if (plantId != null) {
          final plant = await _plantRepo.findById(plantId);
          if (plant != null) {
            final roomId = plant.roomId;
            if (roomId != null) {
              room = await _roomRepo.findById(roomId);
            }
          }
        }
      }
      if (mounted)
        setState(() {
          _harvest = h;
          _harvestWithPlant = hwp;
          _room = room;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(
        backgroundColor: DT.canvas,
        body: Center(child: CircularProgressIndicator(color: DT.accent)),
      );
    if (_harvest == null)
      return const Scaffold(
        backgroundColor: DT.canvas,
        body: Center(
          child: Text(
            'Ernte nicht gefunden',
            style: TextStyle(color: DT.textPrimary),
          ),
        ),
      );

    return PlantryScaffold(
      title: 'Ernte Details',
      actions: [
        IconButton(
          icon: const Icon(Icons.edit, color: DT.textPrimary),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EditHarvestScreen(harvest: _harvest!),
              ),
            );
            _loadHarvest();
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: DT.error),
          onPressed: _delete,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          children: [
            _buildPlantHeader(),
            const SizedBox(height: 16),
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildActions(),
            const SizedBox(height: 16),
            _buildSection(_t['harvest_weight_section'], Icons.scale, [
              _row(
                _t['harvest_wet_weight'],
                '${_harvest!.wetWeight?.toStringAsFixed(1) ?? "—"}g',
              ),
              _row(
                _t['harvest_dry_weight'],
                '${_harvest!.dryWeight?.toStringAsFixed(1) ?? "—"}g',
              ),
              if (_harvest!.weightLossPercentage != null)
                _row(
                  _t['harvest_weight_loss'],
                  '${_harvest!.weightLossPercentage!.toStringAsFixed(1)}%',
                  highlight: true,
                ),
            ]),
            if (_harvest!.dryWeight != null &&
                _room != null &&
                (_room!.area > 0 ||
                    (_room!.lightWatts != null && _room!.lightWatts! > 0))) ...[
              const SizedBox(height: 16),
              _buildSection(_t['harvest_yield_section'], Icons.bar_chart, [
                if (_room!.area > 0)
                  _row(
                    _t['harvest_yield_per_sqm'],
                    '${(_harvest!.dryWeight! / _room!.area).toStringAsFixed(1)} g/m²',
                    highlight: true,
                  ),
                if (_room!.lightWatts != null && _room!.lightWatts! > 0)
                  _row(
                    _t['yield_per_watt_label'],
                    '${(_harvest!.dryWeight! / _room!.lightWatts!).toStringAsFixed(1)} ${_t['yield_per_watt']}',
                    highlight: true,
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            _buildSection(_t['harvest_drying_section'], Icons.dry_cleaning, [
              _row(_t['harvest_start'], _format(_harvest!.dryingStartDate)),
              _row(_t['harvest_end'], _format(_harvest!.dryingEndDate)),
              _row(_t['harvest_status'], _harvest!.dryingStatus),
            ]),
            const SizedBox(height: 16),
            _buildSection(_t['harvest_curing_section'], Icons.inventory_2, [
              _row(_t['harvest_start'], _format(_harvest!.curingStartDate)),
              _row(_t['harvest_end'], _format(_harvest!.curingEndDate)),
              _row(_t['harvest_status'], _harvest!.curingStatus),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantHeader() {
    return PlantryCard(
      child: Row(
        children: [
          const Icon(Icons.grass_rounded, color: DT.success, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _harvestWithPlant?['plant_name'] ?? 'Pflanze',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DT.textPrimary,
                  ),
                ),
                Text(
                  _harvestWithPlant?['plant_strain'] ?? 'Unbekannter Strain',
                  style: const TextStyle(fontSize: 14, color: DT.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _harvest!.isComplete
        ? 'Fertig'
        : (_harvest!.curingStartDate != null ? 'In Curing' : 'In Trocknung');
    final color = _harvest!.isComplete
        ? DT.success
        : (_harvest!.curingStartDate != null ? DT.info : DT.warning);

    return PlantryCard(
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 12),
          Text(
            status,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            DateFormat('dd.MM.yyyy').format(_harvest!.harvestDate),
            style: const TextStyle(color: DT.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        PlantryButton(
          label: 'Trocknung bearbeiten',
          icon: Icons.dry_cleaning,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HarvestDryingScreen(harvestId: widget.harvestId),
            ),
          ).then((_) => _loadHarvest()),
          fullWidth: true,
          isPrimary: false,
        ),
        const SizedBox(height: 8),
        if (_harvest!.dryingEndDate != null)
          PlantryButton(
            label: 'Curing bearbeiten',
            icon: Icons.inventory_2,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    HarvestCuringScreen(harvestId: widget.harvestId),
              ),
            ).then((_) => _loadHarvest()),
            fullWidth: true,
            isPrimary: false,
          ),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return PlantryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: DT.accent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: DT.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: DT.border),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String l, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: const TextStyle(fontSize: 13, color: DT.textSecondary),
          ),
          Text(
            v,
            style: TextStyle(
              fontSize: 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              color: highlight ? DT.error : DT.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime? d) =>
      d != null ? DateFormat('dd.MM.yyyy').format(d) : '—';

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(
          _t['delete_confirm'],
          style: const TextStyle(color: DT.textPrimary),
        ),
        content: Text(
          _t['delete_harvest_confirm'],
          style: const TextStyle(color: DT.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t['cancel'],
              style: const TextStyle(color: DT.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t['delete'], style: const TextStyle(color: DT.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _harvestRepo.deleteHarvest(widget.harvestId);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }
}
