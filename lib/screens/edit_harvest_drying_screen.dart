// =============================================
// GROWLOG - Edit Harvest Drying Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class EditHarvestDryingScreen extends StatefulWidget {
  final Harvest harvest;

  const EditHarvestDryingScreen({super.key, required this.harvest});

  @override
  State<EditHarvestDryingScreen> createState() =>
      _EditHarvestDryingScreenState();
}

class _EditHarvestDryingScreenState extends State<EditHarvestDryingScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  late AppTranslations _t;
  final _formKey = GlobalKey<FormState>();

  DateTime? _dryingStartDate;
  DateTime? _dryingEndDate;
  final TextEditingController _methodController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();

  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dryingStartDate = widget.harvest.dryingStartDate;
    _dryingEndDate = widget.harvest.dryingEndDate;
    _methodController.text = widget.harvest.dryingMethod ?? '';
    _temperatureController.text =
        widget.harvest.dryingTemperature?.toString() ?? '';
    _humidityController.text = widget.harvest.dryingHumidity?.toString() ?? '';
  }

  @override
  void dispose() {
    _methodController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      int? dryingDays;
      if (_dryingStartDate != null && _dryingEndDate != null) {
        dryingDays = _dryingEndDate!.difference(_dryingStartDate!).inDays;
      }

      final updated = widget.harvest.copyWith(
        dryingStartDate: _dryingStartDate,
        dryingEndDate: _dryingEndDate,
        dryingDays: dryingDays,
        dryingMethod: _methodController.text.isNotEmpty
            ? _methodController.text
            : null,
        dryingTemperature: double.tryParse(_temperatureController.text),
        dryingHumidity: double.tryParse(_humidityController.text),
        updatedAt: DateTime.now(),
      );

      await _harvestRepo.updateHarvest(updated);

      if (mounted) {
        Navigator.pop(context, true);
        AppMessages.showSuccess(context, 'Trocknung aktualisiert! ✅');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: 'Trocknung bearbeiten',
      actions: [
        if (!_isSaving)
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
      ],
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DT.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DT.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.dry_cleaning, color: DT.warning),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Trocknungs-Daten',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start Date
              _buildDateField(
                label: 'Start-Datum',
                date: _dryingStartDate,
                icon: Icons.play_arrow,
                color: DT.warning,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dryingStartDate ?? DateTime.now(),
                    firstDate: widget.harvest.harvestDate,
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (date != null) {
                    setState(() => _dryingStartDate = date);
                  }
                },
                onClear: () => setState(() => _dryingStartDate = null),
              ),
              const SizedBox(height: 16),

              // End Date
              _buildDateField(
                label: 'End-Datum',
                date: _dryingEndDate,
                icon: Icons.stop,
                color: DT.success,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _dryingEndDate ?? DateTime.now(),
                    firstDate: _dryingStartDate ?? widget.harvest.harvestDate,
                    lastDate: DateTime.now().add(const Duration(days: 120)),
                  );
                  if (date != null) {
                    setState(() => _dryingEndDate = date);
                  }
                },
                onClear: () => setState(() => _dryingEndDate = null),
              ),
              const SizedBox(height: 20),

              // Duration Info
              if (_dryingStartDate != null && _dryingEndDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DT.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: DT.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Dauer: ${_dryingEndDate!.difference(_dryingStartDate!).inDays} Tage',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DT.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Method
              TextFormField(
                controller: _methodController,
                decoration: InputDecoration(
                  labelText: 'Trocknungs-Methode',
                  hintText: 'z.B. Hängend, Netz, Box',
                  prefixIcon: const Icon(Icons.dashboard),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Method Suggestions
              Wrap(
                spacing: 8,
                children: ['Hängend', 'Netz', 'Box', 'Rack'].map((method) {
                  return ActionChip(
                    label: Text(method),
                    onPressed: () => _methodController.text = method,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Temperature & Humidity
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _temperatureController,
                      decoration: InputDecoration(
                        labelText: 'Temperatur',
                        hintText: '18-22',
                        suffixText: '°C',
                        prefixIcon: const Icon(Icons.thermostat),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _humidityController,
                      decoration: InputDecoration(
                        labelText: 'Luftfeuchte',
                        hintText: '50-60',
                        suffixText: '%',
                        prefixIcon: const Icon(Icons.water_drop),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DT.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: DT.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: DT.warning,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Tipps',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...[
                      'Temperatur: 18-22°C ideal',
                      'Luftfeuchtigkeit: 50-60%',
                      'Dauer: 7-14 Tage typisch',
                      'Dunkel und gut belüftet',
                    ].map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: DT.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DT.surface,
          boxShadow: [
            BoxShadow(
              color: DT.canvas.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: Text(_t['cancel']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Speichert...' : 'Speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.warning,
                  foregroundColor: DT.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: DT.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: DT.textSecondary),
                  ),
                  Text(
                    date != null
                        ? DateFormat('dd.MM.yyyy').format(date)
                        : _t['edit_harvest_not_set'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: date != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: date != null ? DT.textPrimary : DT.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null && onClear != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
                color: DT.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
