// =============================================
// GROWLOG - RDWC Addback Step 2: Follow-up Measurement
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/unit_converter.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class RdwcAddbackCompleteScreen extends StatefulWidget {
  final RdwcSystem system;
  final RdwcLog pendingLog;

  const RdwcAddbackCompleteScreen({
    super.key,
    required this.system,
    required this.pendingLog,
  });

  @override
  State<RdwcAddbackCompleteScreen> createState() =>
      _RdwcAddbackCompleteScreenState();
}

class _RdwcAddbackCompleteScreenState
    extends State<RdwcAddbackCompleteScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  final _levelAfterController = TextEditingController();
  final _phAfterController = TextEditingController();
  final _ecAfterController = TextEditingController();

  late AppTranslations _t;
  late AppSettings _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _t = AppTranslations(settings.language);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _levelAfterController.dispose();
    _phAfterController.dispose();
    _ecAfterController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final levelAfter = double.tryParse(_levelAfterController.text);
    final phAfter = double.tryParse(_phAfterController.text);
    final ecAfter = double.tryParse(_ecAfterController.text);

    if (levelAfter == null || phAfter == null || ecAfter == null) {
      AppMessages.showError(context, 'Alle Felder ausfüllen');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _rdwcRepo.completeLog(
        widget.pendingLog.id!,
        ecAfter: ecAfter,
        phAfter: phAfter,
        levelAfter: levelAfter,
      );
      if (mounted) {
        AppMessages.showSuccess(context, _t['complete_addback_btn']);
        Navigator.of(context).pop(true);
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final log = widget.pendingLog;
    final ecUnit = _settings.nutrientUnit == NutrientUnit.ec ? 'mS/cm' : 'PPM';
    final ecLabel = _settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM';

    return PlantryScaffold(
      title: _t['addback_step2_title'],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Step 1 Summary (readonly)
            Card(
              color: DT.elevated,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: DT.warning, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${_t['addback_step1_summary']} ${DateFormat('dd.MM.yyyy HH:mm').format(log.logDate)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: DT.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (log.waterAdded != null)
                      _summaryRow(
                        Icons.water_drop,
                        _t['water_added'],
                        UnitConverter.formatVolume(
                            log.waterAdded!, _settings.volumeUnit),
                      ),
                    if (log.phBefore != null)
                      _summaryRow(
                        Icons.science_outlined,
                        'pH vorher',
                        log.phBefore!.toStringAsFixed(2),
                      ),
                    if (log.ecBefore != null)
                      _summaryRow(
                        Icons.science_outlined,
                        '$ecLabel vorher',
                        '${log.ecBefore!.toStringAsFixed(2)} $ecUnit',
                      ),
                    if (log.fertilizers != null && log.fertilizers!.isNotEmpty)
                      _summaryRow(
                        Icons.grass,
                        _t['nutrients'],
                        '${log.fertilizers!.length} ${_t['fertilizers']}',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Step 2 fields
            Text(
              _t['addback_step2_title'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Level after
            TextFormField(
              controller: _levelAfterController,
              decoration: InputDecoration(
                labelText: _t['level_after'],
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.water_drop),
                suffixText:
                    UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                if (double.tryParse(v) == null) return 'Ungültige Zahl';
                if (double.parse(v) > widget.system.maxCapacity) {
                  return 'Überschreitet max. Kapazität';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // pH after + EC after
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phAfterController,
                    decoration: InputDecoration(
                      labelText: 'pH ${_t['level_after']}',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.science),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                      if (double.tryParse(v) == null) return 'Ungültige Zahl';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ecAfterController,
                    decoration: InputDecoration(
                      labelText: '$ecLabel ${_t['level_after']}',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.science),
                      suffixText: ecUnit,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Pflichtfeld';
                      if (double.tryParse(v) == null) return 'Ungültige Zahl';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                    _isSaving ? '...' : _t['complete_addback_btn']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.accent,
                  foregroundColor: DT.canvas,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: DT.textSecondary),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: DT.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
