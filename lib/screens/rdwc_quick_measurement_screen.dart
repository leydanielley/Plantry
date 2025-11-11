// =============================================
// GROWLOG - RDWC Quick Measurement Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';

class RdwcQuickMeasurementScreen extends StatefulWidget {
  final RdwcSystem system;

  const RdwcQuickMeasurementScreen({super.key, required this.system});

  @override
  State<RdwcQuickMeasurementScreen> createState() =>
      _RdwcQuickMeasurementScreenState();
}

class _RdwcQuickMeasurementScreenState
    extends State<RdwcQuickMeasurementScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late TextEditingController _levelController;
  late TextEditingController _phController;
  late TextEditingController _ecController;
  late TextEditingController _noteController;

  late AppTranslations _t;
  late AppSettings _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _levelController = TextEditingController(
      text: widget.system.currentLevel.toStringAsFixed(1),
    );
    _phController = TextEditingController();
    _ecController = TextEditingController();
    _noteController = TextEditingController();
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
    _levelController.dispose();
    _phController.dispose();
    _ecController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // ✅ CRITICAL FIX: Use tryParse to prevent crash on invalid input
      final level = double.tryParse(_levelController.text) ?? 0.0;
      final ph = _phController.text.isNotEmpty
          ? double.tryParse(_phController.text)
          : null;
      final ec = _ecController.text.isNotEmpty
          ? double.tryParse(_ecController.text)
          : null;

      final log = RdwcLog(
        systemId: widget.system.id!,
        logType: RdwcLogType.measurement,
        logDate: DateTime.now(),
        levelAfter: level,
        phAfter: ph,
        ecAfter: ec,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      await _rdwcRepo.createLog(log);

      // Update system level
      await _rdwcRepo.updateSystemLevel(widget.system.id!, level);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.showSuccess(context, _t['log_created']);
      }
    } catch (e) {
      AppLogger.error('RdwcQuickMeasurementScreen', 'Error saving', e);
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context, _t['error_saving']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.science, color: Colors.purple),
            const SizedBox(width: 8),
            Text(_t['quick_measurement']),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t['quick_measurement_hint'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Current Level
            TextFormField(
              controller: _levelController,
              decoration: InputDecoration(
                labelText: _t['current_level'],
                hintText: 'e.g. 50',
                prefixIcon: const Icon(Icons.water_drop),
                suffixText: _settings.volumeUnit == VolumeUnit.liter
                    ? 'L'
                    : 'gal',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _t['level_required'];
                }
                final number = double.tryParse(value);
                if (number == null || number < 0) {
                  return _t['invalid_number'];
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // pH
            TextFormField(
              controller: _phController,
              decoration: InputDecoration(
                labelText: '${_t['current_ph']} (${_t['optional']})',
                hintText: 'e.g. 5.8',
                prefixIcon: const Icon(Icons.water),
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final number = double.tryParse(value);
                  if (number == null || number < 0 || number > 14) {
                    return _t['invalid_ph'];
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // EC
            TextFormField(
              controller: _ecController,
              decoration: InputDecoration(
                labelText: '${_t['current_ec']} (${_t['optional']})',
                hintText: 'e.g. 1.8',
                prefixIcon: const Icon(Icons.analytics),
                suffixText: 'mS/cm',
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final number = double.tryParse(value);
                  if (number == null || number < 0) {
                    return _t['invalid_number'];
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: '${_t['note']} (${_t['optional']})',
                hintText: _t['add_notes_here'],
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? _t['saving'] : _t['save']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
