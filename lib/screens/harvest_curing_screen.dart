// =============================================
// GROWLOG - Harvest Curing Screen (View Mode)
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/screens/edit_harvest_curing_screen.dart';
import 'package:growlog_app/screens/harvest_quality_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class HarvestCuringScreen extends StatefulWidget {
  final int harvestId;

  const HarvestCuringScreen({super.key, required this.harvestId});

  @override
  State<HarvestCuringScreen> createState() => _HarvestCuringScreenState();
}

class _HarvestCuringScreenState extends State<HarvestCuringScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  Harvest? _harvest;
  bool _isLoading = true;
  late AppTranslations _t;
  final _curingMethodController = TextEditingController();
  final _curingNotesController = TextEditingController();

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

  @override
  void dispose() {
    _curingMethodController.dispose();
    _curingNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadHarvest() async {
    setState(() => _isLoading = true);
    try {
      final harvest = await _harvestRepo.getHarvestById(widget.harvestId);
      setState(() {
        _harvest = harvest;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _startCuring() async {
    if (_harvest == null) return;

    // ✅ Zeige Dialog zum Erfassen der Curing-Methode beim START
    final result = await _showStartCuringDialog();
    if (result == null) return; // User hat abgebrochen

    try {
      final updated = _harvest!.copyWith(
        curingStartDate: result['startDate'] as DateTime,
        curingMethod: result['method'] as String?,
        curingNotes: result['notes'] as String?,
        updatedAt: DateTime.now(),
      );
      await _harvestRepo.updateHarvest(updated);
      _loadHarvest();

      if (mounted) {
        AppMessages.showSuccess(context, 'Curing gestartet! 📦');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _showStartCuringDialog() async {
    _curingMethodController.text = _harvest!.curingMethod ?? 'Glass Jars';
    _curingNotesController.text = _harvest!.curingNotes ?? '';
    DateTime selectedStartDate = DateTime.now();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.inventory_2, color: DT.info),
                  const SizedBox(width: 12),
                  Text(_t['start_curing_btn']),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Start Date Picker
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedStartDate,
                          firstDate:
                              _harvest!.dryingEndDate ?? _harvest!.harvestDate,
                          lastDate: DateTime.now().add(const Duration(days: 7)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            selectedStartDate = date;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Curing-Start',
                          prefixIcon: const Icon(
                            Icons.calendar_today,
                            color: DT.info,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd.MM.yyyy').format(selectedStartDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Method
                    TextFormField(
                      controller: _curingMethodController,
                      decoration: InputDecoration(
                        labelText: 'Curing-Methode',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintText: 'z.B. Glass Jars, Grove Bags',
                        prefixIcon: const Icon(
                          Icons.dashboard,
                          color: DT.info,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Method Suggestion Chips
                    Wrap(
                      spacing: 8,
                      children:
                          [
                                'Glass Jars',
                                'Grove Bags',
                                'CVault',
                                'Vacuum Sealed',
                              ]
                              .map(
                                (method) => ActionChip(
                                  label: Text(
                                    method,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () {
                                    _curingMethodController.text = method;
                                    setDialogState(() {});
                                  },
                                  backgroundColor:
                                      _curingMethodController.text == method
                                      ? DT.info.withValues(alpha: 0.2)
                                      : null,
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _curingNotesController,
                      decoration: InputDecoration(
                        labelText: 'Notizen (optional)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        hintText: 'Burping Schedule, Besonderheiten...',
                        prefixIcon: const Icon(
                          Icons.note,
                          color: DT.info,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_t['cancel']),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, {
                      'startDate': selectedStartDate,
                      'method': _curingMethodController.text.isNotEmpty
                          ? _curingMethodController.text
                          : null,
                      'notes': _curingNotesController.text.isNotEmpty
                          ? _curingNotesController.text
                          : null,
                    });
                  },
                  icon: const Icon(Icons.check),
                  label: Text(_t['start_btn']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.info,
                    foregroundColor: DT.textPrimary,
                  ),
                ),
              ],
            );
          },
        ),
    );
  }

  Future<void> _endCuring() async {
    if (_harvest == null) return;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: _harvest!.curingStartDate ?? _harvest!.harvestDate,
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    try {
      final updated = _harvest!.copyWith(
        curingEndDate: date,
        updatedAt: DateTime.now(),
      );
      await _harvestRepo.updateHarvest(updated);
      _loadHarvest();

      if (mounted) {
        AppMessages.showSuccess(context, 'Curing abgeschlossen! 🎉');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Curing'),
          backgroundColor: DT.info,
          foregroundColor: DT.textPrimary,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_harvest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Curing'),
          backgroundColor: DT.info,
          foregroundColor: DT.textPrimary,
        ),
        body: const Center(child: Text('Ernte nicht gefunden')),
      );
    }

    final hasStarted = _harvest!.curingStartDate != null;
    final hasEnded = _harvest!.curingEndDate != null;
    final isActive = hasStarted && !hasEnded;

    return PlantryScaffold(
      title: 'Curing',
      actions: [
        if (hasStarted)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditHarvestCuringScreen(harvest: _harvest!),
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
      subtitle = 'Curing erfolgreich beendet';
    } else if (isActive) {
      color = DT.info;
      icon = Icons.inventory_2;
      status = 'In Curing';
      subtitle = 'Laufender Fermentations-Prozess';
    } else {
      color = DT.info;
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
                Icon(Icons.inventory_2, color: DT.info),
                SizedBox(width: 8),
                Text(
                  'Curing-Daten',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),

            if (_harvest!.curingStartDate != null)
              _buildInfoRow(
                'Start',
                DateFormat('dd.MM.yyyy').format(_harvest!.curingStartDate!),
                Icons.play_arrow,
                DT.info,
              ),

            if (_harvest!.curingEndDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Ende',
                DateFormat('dd.MM.yyyy').format(_harvest!.curingEndDate!),
                Icons.stop,
                DT.success,
              ),
            ],

            if (_harvest!.calculatedCuringDays != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Dauer',
                '${_harvest!.calculatedCuringDays} Tage',
                Icons.timer,
                DT.secondary,
                highlight: true,
              ),
            ],

            if (_harvest!.curingMethod != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Methode',
                _harvest!.curingMethod!,
                Icons.dashboard,
                DT.info,
              ),
            ],

            if (_harvest!.curingNotes != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Notizen',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DT.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(_harvest!.curingNotes!),
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
        onPressed: _startCuring,
        icon: const Icon(Icons.play_arrow),
        label: Text(_t['start_curing_now']),
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

  Widget _buildEndButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _endCuring,
        icon: const Icon(Icons.stop),
        label: Text(_t['end_curing']),
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
                  HarvestQualityScreen(harvestId: widget.harvestId),
            ),
          );
          _loadHarvest();
        },
        icon: const Icon(Icons.arrow_forward),
        label: Text(_t['continue_to_quality']),
        style: ElevatedButton.styleFrom(
          backgroundColor: DT.secondary,
          foregroundColor: DT.canvas,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
