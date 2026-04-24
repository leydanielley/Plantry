// =============================================
// GROWLOG - RDWC Quick Measurement Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
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
  DateTime _logDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  RdwcLog? _pendingLog;
  bool _useAsCompletion = false;

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
    final results = await Future.wait([
      _settingsRepo.getSettings(),
      _rdwcRepo.getPendingLog(widget.system.id!),
    ]);
    if (mounted) {
      final settings = results[0] as AppSettings;
      final pending = results[1] as RdwcLog?;
      setState(() {
        _settings = settings;
        _t = AppTranslations(settings.language);
        _pendingLog = pending;
        _isLoading = false;
      });
      if (pending != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showPendingDialog(pending),
        );
      }
    }
  }

  void _showPendingDialog(RdwcLog pending) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFFFF9800), size: 20),
            const SizedBox(width: 8),
            Text(
              _t['pending_addback_found'],
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          '${_t['addback_step1_summary']} ${DateFormat('dd.MM.yyyy HH:mm').format(pending.logDate)}.\n\n${_t['use_as_completion']}?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _useAsCompletion = false);
              Navigator.pop(ctx, false);
            },
            child: Text(
              _t['only_snapshot'],
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _useAsCompletion = true);
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
            ),
            child: Text(
              _t['use_as_completion'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
      final level = double.tryParse(_levelController.text) ?? 0.0;
      final ph = _phController.text.isNotEmpty
          ? double.tryParse(_phController.text)
          : null;
      final ec = _ecController.text.isNotEmpty
          ? double.tryParse(_ecController.text)
          : null;

      if (_useAsCompletion && _pendingLog != null) {
        // Complete the pending addback with these measurements
        await _rdwcRepo.completeLog(
          _pendingLog!.id!,
          ecAfter: ec ?? 0.0,
          phAfter: ph ?? 0.0,
          levelAfter: level,
        );
      } else {
        final log = RdwcLog(
          systemId: widget.system.id!,
          logType: RdwcLogType.measurement,
          logDate: _logDate,
          levelAfter: level,
          phAfter: ph,
          ecAfter: ec,
          note: _noteController.text.isNotEmpty ? _noteController.text : null,
        );
        await _rdwcRepo.createLog(log);
        await _rdwcRepo.updateSystemLevel(widget.system.id!, level);
      }

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

    return PlantryScaffold(
      titleWidget: Row(
        children: [
          const Icon(Icons.science, color: Colors.purple),
          const SizedBox(width: 8),
          Text(_t['quick_measurement']),
        ],
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

            // Date picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _logDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (!mounted) return;
                if (picked != null) setState(() => _logDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _t['date'],
                  prefixIcon: const Icon(
                    Icons.calendar_today,
                    color: Colors.purple,
                  ),
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  DateFormat('dd.MM.yyyy').format(_logDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Current Level
            TextFormField(
              controller: _levelController,
              decoration: InputDecoration(
                labelText: _t['current_level'],
                hintText: _t['rdwc_hint_level'],
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
                hintText: _t['rdwc_hint_ph'],
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
                hintText: _t['rdwc_hint_ec'],
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
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
