// =============================================
// GROWLOG - Harvest Detail Screen (Enhanced) - FIXED
// =============================================
// CRITICAL: This file was accidentally truncated.
// Copy this ENTIRE file to: F:\ProjectX\growlog_app\lib\screens\harvest_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../utils/translations.dart'; // ✅ AUDIT FIX: i18n
import '../models/harvest.dart';
import '../repositories/interfaces/i_harvest_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart'; // ✅ AUDIT FIX: i18n
import 'edit_harvest_screen.dart';
import 'harvest_drying_screen.dart';
import 'harvest_curing_screen.dart';
import 'harvest_quality_screen.dart';
import '../di/service_locator.dart';

class HarvestDetailScreen extends StatefulWidget {
  final int harvestId;

  const HarvestDetailScreen({super.key, required this.harvestId});

  @override
  State<HarvestDetailScreen> createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>(); // ✅ AUDIT FIX: i18n

  Harvest? _harvest;
  Map<String, dynamic>? _harvestWithPlant;
  late AppTranslations _t; // ✅ AUDIT FIX: i18n
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTranslations(); // ✅ AUDIT FIX: i18n
    _loadHarvest();
  }

  Future<void> _initTranslations() async {
    // ✅ AUDIT FIX: i18n
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadHarvest() async {
    setState(() => _isLoading = true);

    AppLogger.info('HarvestDetailScreen', '🟢 Loading harvest with ID: ${widget.harvestId}');

    try {
      final harvestWithPlant = await _harvestRepo.getHarvestWithPlant(widget.harvestId);
      final harvest = await _harvestRepo.getHarvestById(widget.harvestId);

      AppLogger.info('HarvestDetailScreen', '✅ Harvest loaded: $harvest');
      AppLogger.info('HarvestDetailScreen', '✅ HarvestWithPlant: $harvestWithPlant');

      setState(() {
        _harvest = harvest;
        _harvestWithPlant = harvestWithPlant;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('HarvestDetailScreen', '❌ Error: $e');
      AppLogger.error('HarvestDetailScreen', '❌ StackTrace: $stackTrace');
      setState(() => _isLoading = false);

      if (mounted) {
        AppMessages.showError(context, 
'Fehler beim Laden: $e');
      }
    }
  }

  Future<void> _deleteHarvest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(child: Text(_t['harvest_detail_delete_title'])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['harvest_detail_delete_message'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Pflanze wird auf BLOOM zurückgesetzt',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Die zugehörige Pflanze wird automatisch wieder in die Blüte-Phase versetzt. '
                    'Alle Harvest-Daten (Gewichte, Drying/Curing) gehen verloren.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _harvestRepo.deleteHarvest(widget.harvestId);
        if (mounted) {
          Navigator.pop(context, true);
          AppMessages.showSuccess(context,
_t['harvest_detail_deleted']);
        }
      } catch (e) {
        if (mounted) {
          AppMessages.showError(context,
'Fehler: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t['harvest_detail_title']),
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_harvest == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t['harvest_detail_title']),
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              Text(
                _t['harvest_detail_not_found'],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${widget.harvestId}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Zurück'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t['harvest_detail_details_title']),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditHarvestScreen(harvest: _harvest!),
                ),
              );
              if (result == true) _loadHarvest();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteHarvest,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_harvestWithPlant != null) _buildPlantInfo(),
            const SizedBox(height: 20),
            _buildStatusOverview(),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 20),
            _buildWeightSection(),
            const SizedBox(height: 16),
            _buildDryingSection(),
            const SizedBox(height: 16),
            _buildCuringSection(),
            const SizedBox(height: 16),
            if (_harvest!.thcPercentage != null || _harvest!.cbdPercentage != null || _harvest!.terpeneProfile != null)
              _buildQualitySection(),
            const SizedBox(height: 16),
            if (_harvest!.rating != null || _harvest!.tasteNotes != null || _harvest!.effectNotes != null || _harvest!.overallNotes != null)
              _buildRatingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOverview() {
    final isComplete = _harvest!.isComplete;
    final inDrying = _harvest!.dryingStartDate != null && _harvest!.dryingEndDate == null;
    final inCuring = _harvest!.curingStartDate != null && _harvest!.curingEndDate == null;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isComplete) {
      statusColor = Colors.green;
      statusText = 'Abgeschlossen';
      statusIcon = Icons.check_circle;
    } else if (inCuring) {
      statusColor = Colors.purple;
      statusText = 'In Curing';
      statusIcon = Icons.inventory_2;
    } else if (inDrying) {
      statusColor = Colors.orange;
      statusText = 'In Trocknung';
      statusIcon = Icons.dry_cleaning;
    } else {
      statusColor = Colors.grey;
      statusText = 'Gestartet';
      statusIcon = Icons.schedule;
    }

    return Card(
      color: statusColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Text(
                        'Ernte vom ${DateFormat('dd.MM.yyyy').format(_harvest!.harvestDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_harvest!.dryWeight != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_harvest!.dryWeight!.toStringAsFixed(1)}g',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    return Row(
      children: [
        _buildTimelineStep('Ernte', Icons.grass, true, Colors.green),
        _buildTimelineConnector(true),
        _buildTimelineStep('Trocknung', Icons.dry_cleaning, _harvest!.dryingStartDate != null, Colors.orange),
        _buildTimelineConnector(_harvest!.dryingEndDate != null),
        _buildTimelineStep('Curing', Icons.inventory_2, _harvest!.curingStartDate != null, Colors.purple),
        _buildTimelineConnector(_harvest!.curingEndDate != null),
        _buildTimelineStep('Fertig', Icons.check_circle, _harvest!.isComplete, Colors.green),
      ],
    );
  }

  Widget _buildTimelineStep(String label, IconData icon, bool isActive, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? color : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 30),
        color: isActive ? Colors.green : Colors.grey[300],
      ),
    );
  }

  // ✅ UPDATED VERSION - Only show buttons when previous phase is complete
  Widget _buildQuickActions() {
    List<Widget> actions = [];

    // Always show Drying button
    actions.add(
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HarvestDryingScreen(harvestId: widget.harvestId),
              ),
            );
            _loadHarvest();
          },
          icon: const Icon(Icons.dry_cleaning),
          label: const Text('Zur Trocknung'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );

    // Only show Curing if Drying is complete
    if (_harvest!.dryingEndDate != null && _harvest!.dryWeight != null) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HarvestCuringScreen(harvestId: widget.harvestId),
                ),
              );
              _loadHarvest();
            },
            icon: const Icon(Icons.inventory_2),
            label: const Text('Zum Curing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    // Only show Quality Control if Curing is complete
    if (_harvest!.curingEndDate != null) {
      actions.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HarvestQualityScreen(harvestId: widget.harvestId),
                ),
              );
              _loadHarvest();
            },
            icon: const Icon(Icons.science),
            label: const Text('Zur Quality Control'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['harvest_detail_phases_title'],
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...actions.map((action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: action,
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.scale, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(_t['harvest_detail_weight_title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            if (_harvest!.wetWeight != null || _harvest!.dryWeight != null)
              _buildWeightVisual()
            else
              Text(_t['harvest_detail_no_weight_data']),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightVisual() {
    final hasWet = _harvest!.wetWeight != null;
    final hasDry = _harvest!.dryWeight != null;
    final loss = _harvest!.weightLossPercentage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (hasWet) ...[
              Expanded(child: _buildWeightBar(_t['harvest_detail_wet_weight'], _harvest!.wetWeight!, Colors.blue, Icons.water_drop)),
              const SizedBox(width: 12),
            ],
            if (hasDry)
              Expanded(child: _buildWeightBar(_t['harvest_detail_dry_weight'], _harvest!.dryWeight!, Colors.green, Icons.grass)),
          ],
        ),
        if (loss != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF37474F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_down, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gewichtsverlust: ${loss.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                      ),
                      if (hasWet && hasDry)
                        Text(
                          '${(_harvest!.wetWeight! - _harvest!.dryWeight!).toStringAsFixed(1)}g Wasser verloren',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeightBar(String label, double weight, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('${weight.toStringAsFixed(1)}g', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildDryingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dry_cleaning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                const Text('Trocknung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildStatusBadge(_harvest!.dryingStatus, Colors.orange),
              ],
            ),
            const Divider(height: 20),
            if (_harvest!.dryingStartDate != null) ...[
              _buildInfoRow('Start', DateFormat('dd.MM.yyyy').format(_harvest!.dryingStartDate!)),
              if (_harvest!.dryingEndDate != null)
                _buildInfoRow('Ende', DateFormat('dd.MM.yyyy').format(_harvest!.dryingEndDate!)),
              if (_harvest!.calculatedDryingDays != null)
                _buildInfoRow('Dauer', '${_harvest!.calculatedDryingDays} Tage', highlight: true),
              if (_harvest!.dryingMethod != null)
                _buildInfoRow('Methode', _harvest!.dryingMethod!),
              if (_harvest!.dryingTemperature != null)
                _buildInfoRow('Temperatur', '${_harvest!.dryingTemperature!.toStringAsFixed(1)}°C'),
              if (_harvest!.dryingHumidity != null)
                _buildInfoRow('Luftfeuchtigkeit', '${_harvest!.dryingHumidity!.toStringAsFixed(0)}%'),
            ] else
              const Text('Trocknung noch nicht gestartet'),
          ],
        ),
      ),
    );
  }

  Widget _buildCuringSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text('Curing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildStatusBadge(_harvest!.curingStatus, Colors.purple),
              ],
            ),
            const Divider(height: 20),
            if (_harvest!.curingStartDate != null) ...[
              _buildInfoRow('Start', DateFormat('dd.MM.yyyy').format(_harvest!.curingStartDate!)),
              if (_harvest!.curingEndDate != null)
                _buildInfoRow('Ende', DateFormat('dd.MM.yyyy').format(_harvest!.curingEndDate!)),
              if (_harvest!.calculatedCuringDays != null)
                _buildInfoRow('Dauer', '${_harvest!.calculatedCuringDays} Tage', highlight: true),
              if (_harvest!.curingMethod != null)
                _buildInfoRow('Methode', _harvest!.curingMethod!),
              if (_harvest!.curingNotes != null)
                _buildInfoRow(_t['harvest_detail_notes_label'], _harvest!.curingNotes!),
            ] else
              const Text('Curing noch nicht gestartet'),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(_t['harvest_detail_quality_title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            if (_harvest!.thcPercentage != null)
              _buildPercentageBar('THC', _harvest!.thcPercentage!, Colors.red),
            if (_harvest!.cbdPercentage != null) ...[
              const SizedBox(height: 12),
              _buildPercentageBar('CBD', _harvest!.cbdPercentage!, Colors.green),
            ],
            if (_harvest!.terpeneProfile != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Terpene', _harvest!.terpeneProfile!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text('Bewertung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            if (_harvest!.rating != null) _buildRatingRow(_harvest!.rating!),
            if (_harvest!.tasteNotes != null) _buildInfoRow('Geschmack', _harvest!.tasteNotes!),
            if (_harvest!.effectNotes != null) _buildInfoRow('Wirkung', _harvest!.effectNotes!),
            if (_harvest!.overallNotes != null) _buildInfoRow(_t['harvest_detail_overall_notes'], _harvest!.overallNotes!),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF37474F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF546E7A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.grass, color: Colors.white70, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_harvestWithPlant!['plant_name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                if (_harvestWithPlant!['plant_strain'] != null)
                  Text(_harvestWithPlant!['plant_strain'] as String, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                if (_harvestWithPlant!['plant_breeder'] != null)
                  Text(_harvestWithPlant!['plant_breeder'] as String, style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(int rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('Bewertung', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          ...List.generate(5, (index) {
            return Icon(
              index < rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 24,
            );
          }),
          const SizedBox(width: 8),
          Text('$rating/5', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
