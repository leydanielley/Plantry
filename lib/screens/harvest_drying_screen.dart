// =============================================
// GROWLOG - Harvest Drying Screen (View Mode) - FIXED
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/screens/edit_harvest_drying_screen.dart';
import 'package:growlog_app/screens/harvest_curing_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class HarvestDryingScreen extends StatefulWidget {
  final int harvestId;

  const HarvestDryingScreen({super.key, required this.harvestId});

  @override
  State<HarvestDryingScreen> createState() => _HarvestDryingScreenState();
}

class _HarvestDryingScreenState extends State<HarvestDryingScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  Harvest? _harvest;
  bool _isLoading = true;
  late AppTranslations _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _loadHarvest();
  }

  Future<void> _loadHarvest() async {
    // ✅ FIX: Add mounted check before setState
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final harvest = await _harvestRepo.getHarvestById(widget.harvestId);
      if (!mounted) return;
      setState(() {
        _harvest = harvest;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _startDrying() async {
    if (_harvest == null) return;

    try {
      final updated = _harvest!.copyWith(
        dryingStartDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _harvestRepo.updateHarvest(updated);
      _loadHarvest();

      if (mounted) {
        AppMessages.showSuccess(context, 'Trocknung gestartet! 🌿');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _endDrying() async {
    if (_harvest == null) return;

    // ✅ Zeige Dialog zum Erfassen des Trockengewichts (Datum = heute)
    final TextEditingController dryWeightController = TextEditingController();

    try {
      final weight = await showDialog<double>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.scale, color: DT.success),
              const SizedBox(width: 12),
              Text(_t['end_drying_title']),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_harvest!.wetWeight != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: DT.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DT.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop, color: DT.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Nassgewicht: ${_harvest!.wetWeight!.toStringAsFixed(1)}g',
                        style: const TextStyle(
                          fontSize: 14,
                          color: DT.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: dryWeightController,
                decoration: InputDecoration(
                  labelText: _t['dry_weight_label'],
                  hintText: 'z.B. 100',
                  suffixText: 'g',
                  prefixIcon: const Icon(Icons.grass),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              // ✅ FIX: Use dialogContext instead of context for proper navigation
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t['cancel']),
            ),
            ElevatedButton(
              onPressed: () {
                final w = double.tryParse(dryWeightController.text);
                if (w != null && w > 0) {
                  // ✅ FIX: Use dialogContext instead of context
                  Navigator.pop(dialogContext, w);
                } else {
                  AppMessages.showSuccess(
                    dialogContext,
                    'Bitte gültiges Gewicht eingeben',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.accent,
                foregroundColor: DT.canvas,
              ),
              child: Text(_t['finish']),
            ),
          ],
        ),
      );

      if (weight == null) return;

      // ✅ Datum automatisch auf heute setzen
      final updated = _harvest!.copyWith(
        dryingEndDate: DateTime.now(),
        dryWeight: weight,
        updatedAt: DateTime.now(),
      );
      await _harvestRepo.updateHarvest(updated);
      _loadHarvest();

      if (mounted) {
        AppMessages.showSuccess(context, 'Trocknung beendet! ✅');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    } finally {
      // ✅ FIX: Dispose controller to prevent memory leak
      dryWeightController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trocknung'),
          backgroundColor: DT.warning,
          foregroundColor: DT.canvas,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_harvest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trocknung'),
          backgroundColor: DT.warning,
          foregroundColor: DT.canvas,
        ),
        body: const Center(child: Text('Ernte nicht gefunden')),
      );
    }

    final hasStarted = _harvest!.dryingStartDate != null;
    final hasEnded = _harvest!.dryingEndDate != null;
    final isActive = hasStarted && !hasEnded;

    return PlantryScaffold(
      title: 'Trocknung',
      actions: [
        if (hasStarted)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditHarvestDryingScreen(harvest: _harvest!),
                ),
              );
              if (result == true) _loadHarvest();
            },
          ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(hasStarted, hasEnded, isActive),
            const SizedBox(height: 20),
            if (hasStarted) ...[_buildDataCard(), const SizedBox(height: 20)],
            if (!hasStarted)
              _buildStartButton()
            else if (isActive)
              _buildEndButton(),
            if (hasEnded) ...[
              const SizedBox(height: 20),
              _buildNextStepButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool hasStarted, bool hasEnded, bool isActive) {
    Color color;
    IconData icon;
    String status;
    String subtitle;

    if (hasEnded) {
      color = DT.success;
      icon = Icons.check_circle;
      status = 'Abgeschlossen';
      subtitle = 'Trocknung erfolgreich beendet';
    } else if (isActive) {
      color = DT.warning;
      icon = Icons.dry_cleaning;
      status = 'In Trocknung';
      subtitle = 'Laufender Trocknungsprozess';
    } else {
      color = DT.textTertiary;
      icon = Icons.schedule;
      status = _t['not_started'];
      subtitle = _t['ready_to_start'];
    }

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: DT.canvas, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: DT.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dry_cleaning, color: DT.warning),
                SizedBox(width: 8),
                Text(
                  'Trocknungs-Daten',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            if (_harvest!.dryingStartDate != null)
              _buildInfoRow(
                'Start',
                DateFormat('dd.MM.yyyy').format(_harvest!.dryingStartDate!),
                Icons.play_arrow,
                DT.warning,
              ),
            if (_harvest!.dryingEndDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Ende',
                DateFormat('dd.MM.yyyy').format(_harvest!.dryingEndDate!),
                Icons.stop,
                DT.success,
              ),
            ],
            if (_harvest!.calculatedDryingDays != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Dauer',
                '${_harvest!.calculatedDryingDays} Tage',
                Icons.timer,
                DT.secondary,
                highlight: true,
              ),
            ],
            if (_harvest!.dryingMethod != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Methode',
                _harvest!.dryingMethod!,
                Icons.dashboard,
                DT.info,
              ),
            ],
            if (_harvest!.dryingTemperature != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Temperatur',
                '${_harvest!.dryingTemperature!.toStringAsFixed(1)}°C',
                Icons.thermostat,
                DT.error,
              ),
            ],
            if (_harvest!.dryingHumidity != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Luftfeuchtigkeit',
                '${_harvest!.dryingHumidity!.toStringAsFixed(0)}%',
                Icons.water_drop,
                DT.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: DT.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            fontSize: highlight ? 18 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startDrying,
        icon: const Icon(Icons.play_arrow),
        label: Text(_t['start_drying_now']),
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.warning,
          foregroundColor: DT.canvas,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEndButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _endDrying,
        icon: const Icon(Icons.stop),
        label: Text(_t['end_drying']),
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.accent,
          foregroundColor: DT.canvas,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildNextStepButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HarvestCuringScreen(harvestId: widget.harvestId),
            ),
          );
          _loadHarvest();
        },
        icon: const Icon(Icons.arrow_forward),
        label: Text(_t['continue_to_curing']),
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.info,
          foregroundColor: DT.textPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
