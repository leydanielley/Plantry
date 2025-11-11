// =============================================
// GROWLOG - RDWC Addback Logging Form
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/rdwc_log_fertilizer.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/database/database_helper.dart'; // ✅ FIX: For transaction support
import 'package:growlog_app/utils/unit_converter.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';

class RdwcAddbackFormScreen extends StatefulWidget {
  final RdwcSystem system;
  final RdwcLog? existingLog; // ✅ Optional: For editing existing logs

  const RdwcAddbackFormScreen({
    super.key,
    required this.system,
    this.existingLog,
  });

  @override
  State<RdwcAddbackFormScreen> createState() => _RdwcAddbackFormScreenState();
}

class _RdwcAddbackFormScreenState extends State<RdwcAddbackFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();

  late TextEditingController _levelBeforeController;
  late TextEditingController _waterAddedController;
  late TextEditingController _levelAfterController;
  late TextEditingController _phBeforeController;
  late TextEditingController _ecBeforeController;
  late TextEditingController _phAfterController;
  late TextEditingController _ecAfterController;
  late TextEditingController _noteController;
  late TextEditingController _currentLevelController; // For measurement
  late TextEditingController _currentPhController; // For measurement
  late TextEditingController _currentEcController; // For measurement

  RdwcLogType _logType = RdwcLogType.addback;

  // Maintenance checklist
  bool _cleanedPumps = false;
  bool _changedFilters = false;
  bool _checkedTubes = false;
  bool _cleanedReservoir = false;
  bool _cleanedAirstones = false;

  // Full change
  bool _reservoirCleanedOnChange = false;
  bool _isLoading = true;
  bool _isSaving = false;
  final bool _autoCalculate = true;
  late AppTranslations _t;
  late AppSettings _settings;

  // v8: Fertilizer tracking (Expert Mode)
  List<Fertilizer> _availableFertilizers = [];
  final List<_FertilizerEntry> _addedFertilizers = [];
  RdwcRecipe? _loadedRecipe;

  @override
  void initState() {
    super.initState();
    _levelBeforeController = TextEditingController();
    _waterAddedController = TextEditingController();
    _levelAfterController = TextEditingController();
    _phBeforeController = TextEditingController();
    _ecBeforeController = TextEditingController();
    _phAfterController = TextEditingController();
    _ecAfterController = TextEditingController();
    _noteController = TextEditingController();
    _currentLevelController = TextEditingController();
    _currentPhController = TextEditingController();
    _currentEcController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    final fertilizers = await _fertilizerRepo.findAll();
    if (mounted) {
      setState(() {
        _settings = settings;
        _t = AppTranslations(settings.language);
        _availableFertilizers = fertilizers;
        _isLoading = false;
      });

      // ✅ Load existing log data if editing
      if (widget.existingLog != null) {
        _loadExistingLogData();
      } else {
        // Pre-fill current level as "level before"
        _levelBeforeController.text = widget.system.currentLevel
            .toStringAsFixed(1);
      }
    }
  }

  /// ✅ Load existing log data into form fields
  void _loadExistingLogData() {
    final log = widget.existingLog!;

    _logType = log.logType;
    _noteController.text = log.note ?? '';

    switch (log.logType) {
      case RdwcLogType.addback:
        _levelBeforeController.text = log.levelBefore?.toString() ?? '';
        _waterAddedController.text = log.waterAdded?.toString() ?? '';
        _levelAfterController.text = log.levelAfter?.toString() ?? '';
        _phBeforeController.text = log.phBefore?.toString() ?? '';
        _ecBeforeController.text = log.ecBefore?.toString() ?? '';
        _phAfterController.text = log.phAfter?.toString() ?? '';
        _ecAfterController.text = log.ecAfter?.toString() ?? '';
        break;
      case RdwcLogType.fullChange:
        _phAfterController.text = log.phAfter?.toString() ?? '';
        _ecAfterController.text = log.ecAfter?.toString() ?? '';
        // Note: Reservoir cleaned flag is stored in note field, user can edit note
        break;
      case RdwcLogType.measurement:
        _currentLevelController.text = log.levelAfter?.toString() ?? '';
        _currentPhController.text = log.phAfter?.toString() ?? '';
        _currentEcController.text = log.ecAfter?.toString() ?? '';
        break;
      case RdwcLogType.maintenance:
        // Note: Maintenance tasks are stored in note field, user can edit note
        break;
    }

    // Load fertilizers
    if (log.fertilizers != null) {
      for (final logFert in log.fertilizers!) {
        final fertilizer = _availableFertilizers.firstWhere(
          (f) => f.id == logFert.fertilizerId,
          orElse: () => Fertilizer(
            id: logFert.fertilizerId,
            name: 'Unknown',
            brand: null,
            npk: null,
          ),
        );
        final amountController = TextEditingController(
          text: logFert.amount.toString(),
        );
        _addedFertilizers.add(
          _FertilizerEntry(
            fertilizer: fertilizer,
            amountController: amountController,
            amountType: logFert.amountType,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _levelBeforeController.dispose();
    _waterAddedController.dispose();
    _levelAfterController.dispose();
    _phBeforeController.dispose();
    _ecBeforeController.dispose();
    _phAfterController.dispose();
    _ecAfterController.dispose();
    _noteController.dispose();
    _currentLevelController.dispose();
    _currentPhController.dispose();
    _currentEcController.dispose();
    // Dispose fertilizer controllers
    for (final entry in _addedFertilizers) {
      entry.amountController.dispose();
    }
    super.dispose();
  }

  void _calculateLevelAfter() {
    if (!_autoCalculate) return;

    final levelBefore = double.tryParse(_levelBeforeController.text);
    final waterAdded = double.tryParse(_waterAddedController.text);

    if (levelBefore != null && waterAdded != null) {
      final levelAfter = levelBefore + waterAdded;
      _levelAfterController.text = levelAfter.toStringAsFixed(1);
    }
  }

  // v8: Add fertilizer to the list
  void _addFertilizer(Fertilizer fertilizer) {
    setState(() {
      _addedFertilizers.add(
        _FertilizerEntry(
          fertilizer: fertilizer,
          amountController: TextEditingController(),
          amountType: FertilizerAmountType.perLiter,
        ),
      );
    });
  }

  // v8: Remove fertilizer from the list
  void _removeFertilizer(int index) {
    setState(() {
      _addedFertilizers[index].amountController.dispose();
      _addedFertilizers.removeAt(index);
    });
  }

  // v8: Calculate estimated EC from added fertilizers
  double? _calculateEstimatedEc() {
    if (_addedFertilizers.isEmpty) return null;

    final levelAfter = double.tryParse(_levelAfterController.text);
    if (levelAfter == null || levelAfter <= 0) return null;

    double totalEc = 0;
    for (final entry in _addedFertilizers) {
      final amount = double.tryParse(entry.amountController.text);
      if (amount == null || entry.fertilizer.ecValue == null) return null;

      final perLiterAmount = entry.amountType == FertilizerAmountType.perLiter
          ? amount
          : amount / levelAfter;

      totalEc += perLiterAmount * entry.fertilizer.ecValue!;
    }

    return totalEc;
  }

  // v8: Calculate individual fertilizer contribution
  String _calculateFertilizerContribution(_FertilizerEntry entry) {
    final levelAfter = double.tryParse(_levelAfterController.text);
    final amount = double.tryParse(entry.amountController.text);

    if (levelAfter == null ||
        levelAfter <= 0 ||
        amount == null ||
        amount <= 0) {
      return '';
    }

    final perLiterAmount = entry.amountType == FertilizerAmountType.perLiter
        ? amount
        : amount / levelAfter;

    if (entry.fertilizer.ecValue != null && entry.fertilizer.ecValue! > 0) {
      final ecContribution = perLiterAmount * entry.fertilizer.ecValue!;
      if (_settings.nutrientUnit == NutrientUnit.ec) {
        return '→ ${ecContribution.toStringAsFixed(2)} mS/cm';
      } else {
        final ppmContribution = UnitConverter.ecToPpm(
          ecContribution,
          _settings.ppmScale,
        );
        return '→ ${ppmContribution.toStringAsFixed(0)} PPM';
      }
    } else if (entry.fertilizer.ppmValue != null &&
        entry.fertilizer.ppmValue! > 0) {
      final ppmContribution = perLiterAmount * entry.fertilizer.ppmValue!;
      if (_settings.nutrientUnit == NutrientUnit.ppm) {
        return '→ ${ppmContribution.toStringAsFixed(0)} PPM';
      } else {
        final ecContribution = UnitConverter.ppmToEc(
          ppmContribution,
          _settings.ppmScale,
        );
        return '→ ${ecContribution.toStringAsFixed(2)} mS/cm';
      }
    }

    return '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String successMessage;
      final isEditing = widget.existingLog != null;

      switch (_logType) {
        case RdwcLogType.measurement:
          // Simple measurement: just current values
          await _saveMeasurement();
          successMessage = isEditing
              ? 'Measurement updated!'
              : 'Measurement logged successfully!';
          break;

        case RdwcLogType.fullChange:
          // Full reservoir change with new fertilizers
          await _saveFullChange();
          successMessage = isEditing
              ? 'Full change updated!'
              : 'Full change logged successfully!';
          break;

        case RdwcLogType.maintenance:
          // Maintenance with checklist
          await _saveMaintenance();
          successMessage = isEditing
              ? 'Maintenance updated!'
              : 'Maintenance logged successfully!';
          break;

        case RdwcLogType.addback:
          // Water addback with fertilizers
          await _saveAddback();
          successMessage = isEditing
              ? 'Addback updated!'
              : 'Addback logged successfully!';
          break;
      }

      // ✅ FIX: Show success message BEFORE popping to avoid using disposed context
      if (mounted) {
        AppMessages.showSuccess(context, successMessage);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('RdwcAddbackFormScreen', 'Error saving log', e);
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context, 'Error saving log: $e');
      }
    }
  }

  /// ✅ Helper: Save or update log based on whether we're editing
  Future<int> _saveOrUpdateLog(RdwcLog log) async {
    if (widget.existingLog != null) {
      // Update existing log
      final updatedLog = log.copyWith(id: widget.existingLog!.id);
      await _rdwcRepo.updateLog(updatedLog);
      return widget.existingLog!.id!;
    } else {
      // Create new log
      return await _rdwcRepo.createLog(log);
    }
  }

  /// Save measurement log (simple, just current values)
  Future<RdwcLog> _saveMeasurement() async {
    final currentLevel = double.tryParse(_currentLevelController.text);
    final currentPh = double.tryParse(_currentPhController.text);
    final currentEc = double.tryParse(_currentEcController.text);
    final note = _noteController.text.trim();

    final log = RdwcLog(
      systemId: widget.system.id!,
      logType: RdwcLogType.measurement,
      levelAfter: currentLevel,
      phAfter: currentPh,
      ecAfter: currentEc,
      note: note.isNotEmpty ? note : null,
    );

    await _saveOrUpdateLog(log);
    return log;
  }

  /// Save addback log (existing logic)
  Future<RdwcLog> _saveAddback() async {
    final levelBefore = double.tryParse(_levelBeforeController.text);
    final waterAdded = double.tryParse(_waterAddedController.text);
    final levelAfter = double.tryParse(_levelAfterController.text);
    final phBefore = double.tryParse(_phBeforeController.text);
    final ecBefore = double.tryParse(_ecBeforeController.text);
    final phAfter = double.tryParse(_phAfterController.text);
    final ecAfter = double.tryParse(_ecAfterController.text);
    final note = _noteController.text.trim();

    // Calculate water consumed
    // ✅ FIX: Correct formula: consumed = (before + added) - after
    double? waterConsumed;
    if (levelBefore != null && levelAfter != null && waterAdded != null) {
      waterConsumed = (levelBefore + waterAdded) - levelAfter;
      // Ensure positive value (data validation issue if negative)
      if (waterConsumed < 0) waterConsumed = 0;
    }

    final log = RdwcLog(
      systemId: widget.system.id!,
      logType: RdwcLogType.addback,
      levelBefore: levelBefore,
      waterAdded: waterAdded,
      levelAfter: levelAfter,
      waterConsumed: waterConsumed,
      phBefore: phBefore,
      ecBefore: ecBefore,
      phAfter: phAfter,
      ecAfter: ecAfter,
      note: note.isNotEmpty ? note : null,
    );

    final logId = await _saveOrUpdateLog(log);

    // Save fertilizers if any were added
    await _saveFertilizers(logId);

    return log;
  }

  /// Save full change log
  Future<RdwcLog> _saveFullChange() async {
    final levelAfter = double.tryParse(_levelAfterController.text);
    final phBefore = double.tryParse(_phBeforeController.text);
    final ecBefore = double.tryParse(_ecBeforeController.text);
    final phAfter = double.tryParse(_phAfterController.text);
    final ecAfter = double.tryParse(_ecAfterController.text);

    // Build note with checklist info
    final noteBuilder = StringBuffer();
    if (_noteController.text.trim().isNotEmpty) {
      noteBuilder.write(_noteController.text.trim());
      noteBuilder.write('\n\n');
    }
    if (_reservoirCleanedOnChange) {
      noteBuilder.write('✓ Reservoir cleaned\n');
    }

    final log = RdwcLog(
      systemId: widget.system.id!,
      logType: RdwcLogType.fullChange,
      levelAfter: levelAfter,
      waterAdded: levelAfter, // For full change, water added = new level
      phBefore: phBefore,
      ecBefore: ecBefore,
      phAfter: phAfter,
      ecAfter: ecAfter,
      note: noteBuilder.toString().trim().isNotEmpty
          ? noteBuilder.toString().trim()
          : null,
    );

    final logId = await _saveOrUpdateLog(log);

    // Save fertilizers for the new water
    await _saveFertilizers(logId);

    return log;
  }

  /// Save maintenance log
  Future<RdwcLog> _saveMaintenance() async {
    final phBefore = double.tryParse(_phBeforeController.text);
    final ecBefore = double.tryParse(_ecBeforeController.text);
    final phAfter = double.tryParse(_phAfterController.text);
    final ecAfter = double.tryParse(_ecAfterController.text);

    // Build note with checklist
    final noteBuilder = StringBuffer();
    if (_noteController.text.trim().isNotEmpty) {
      noteBuilder.write(_noteController.text.trim());
      noteBuilder.write('\n\n');
    }

    noteBuilder.write('=== Maintenance Checklist ===\n');
    if (_cleanedPumps) noteBuilder.write('✓ Pumps cleaned\n');
    if (_changedFilters) noteBuilder.write('✓ Filters changed\n');
    if (_checkedTubes) noteBuilder.write('✓ Tubes checked\n');
    if (_cleanedReservoir) noteBuilder.write('✓ Reservoir cleaned\n');
    if (_cleanedAirstones) noteBuilder.write('✓ Airstones cleaned\n');

    final log = RdwcLog(
      systemId: widget.system.id!,
      logType: RdwcLogType.maintenance,
      phBefore: phBefore,
      ecBefore: ecBefore,
      phAfter: phAfter,
      ecAfter: ecAfter,
      note: noteBuilder.toString().trim(),
    );

    await _saveOrUpdateLog(log);
    return log;
  }

  /// Helper: Save fertilizers to a log
  /// ✅ FIX: Use transaction to ensure atomic operation (delete + insert)
  Future<void> _saveFertilizers(int logId) async {
    if (_addedFertilizers.isEmpty && widget.existingLog == null) return;

    final db = await DatabaseHelper.instance.database;

    // ✅ FIX: Wrap in transaction for atomicity
    await db.transaction((txn) async {
      // When editing: delete old fertilizers first to avoid duplicates
      if (widget.existingLog != null) {
        await txn.delete(
          'rdwc_log_fertilizers',
          where: 'rdwc_log_id = ?',
          whereArgs: [logId],
        );
      }

      // Insert new fertilizers
      for (final entry in _addedFertilizers) {
        final amount = double.tryParse(entry.amountController.text);
        if (amount != null && amount > 0) {
          final fertilizerLog = RdwcLogFertilizer(
            rdwcLogId: logId,
            fertilizerId: entry.fertilizer.id!,
            amount: amount,
            amountType: entry.amountType,
          );
          await txn.insert('rdwc_log_fertilizers', fertilizerLog.toMap());
        }
      }
    });
  }

  // v8: Build fertilizer section widgets (Expert Mode)
  List<Widget> _buildFertilizerSection() {
    final widgets = <Widget>[];

    // Section header with recipe loading
    widgets.add(
      Row(
        children: [
          Text(
            _t['nutrients'],
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_loadedRecipe == null)
            TextButton.icon(
              onPressed: _showRecipePickerDialog,
              icon: const Icon(Icons.science, size: 18),
              label: Text(_t['load_recipe']),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            )
          else
            TextButton.icon(
              onPressed: _clearRecipe,
              icon: const Icon(Icons.clear, size: 18),
              label: Text(_t['clear_recipe']),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
    widgets.add(const SizedBox(height: 8));

    // Show loaded recipe info
    if (_loadedRecipe != null) {
      widgets.add(
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_t['recipe_loaded']}: ${_loadedRecipe!.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 13,
                      ),
                    ),
                    if (_loadedRecipe!.targetEc != null ||
                        _loadedRecipe!.targetPh != null)
                      Text(
                        [
                          if (_loadedRecipe!.targetEc != null)
                            'EC: ${_loadedRecipe!.targetEc!.toStringAsFixed(1)}',
                          if (_loadedRecipe!.targetPh != null)
                            'pH: ${_loadedRecipe!.targetPh!.toStringAsFixed(1)}',
                        ].join(' | '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    // Added fertilizers list
    for (int i = 0; i < _addedFertilizers.length; i++) {
      final entry = _addedFertilizers[i];
      final contribution = _calculateFertilizerContribution(entry);

      widgets.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.fertilizer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: () => _removeFertilizer(i),
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: entry.amountController,
                        decoration: InputDecoration(
                          labelText: _t['amount'],
                          border: const OutlineInputBorder(),
                          suffixText: 'ml',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) =>
                            setState(() {}), // Trigger rebuild for contribution
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: SegmentedButton<FertilizerAmountType>(
                        segments: [
                          ButtonSegment<FertilizerAmountType>(
                            value: FertilizerAmountType.perLiter,
                            label: Text(
                              _t['per_liter'],
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          ButtonSegment<FertilizerAmountType>(
                            value: FertilizerAmountType.total,
                            label: Text(
                              _t['total_amount'],
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                        selected: {entry.amountType},
                        onSelectionChanged:
                            (Set<FertilizerAmountType> newSelection) {
                              setState(
                                () => entry.amountType = newSelection.first,
                              );
                            },
                      ),
                    ),
                  ],
                ),
                // Show individual contribution
                if (contribution.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.analytics,
                          size: 16,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          contribution,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
    }

    // Add fertilizer button
    if (_availableFertilizers.isNotEmpty) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _showAddFertilizerDialog(),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(_t['add_fertilizer']),
        ),
      );
    }

    // Estimated EC (if calculable)
    final estimatedEc = _calculateEstimatedEc();
    if (estimatedEc != null) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Card(
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  '${_t['estimated_ec']}: ${estimatedEc.toStringAsFixed(2)} mS/cm',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  // v8: Show dialog to select a fertilizer to add
  Future<void> _showAddFertilizerDialog() async {
    // Filter out already added fertilizers
    final availableToAdd = _availableFertilizers.where((fert) {
      return !_addedFertilizers.any((entry) => entry.fertilizer.id == fert.id);
    }).toList();

    if (availableToAdd.isEmpty) {
      AppMessages.showInfo(context, _t['all_fertilizers_added']);
      return;
    }

    final selected = await showDialog<Fertilizer>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['select_fertilizer']),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableToAdd.length,
            itemBuilder: (context, index) {
              final fertilizer = availableToAdd[index];
              return ListTile(
                title: Text(fertilizer.name),
                subtitle: fertilizer.ecValue != null
                    ? Text('EC: ${fertilizer.ecValue} mS/cm per ml')
                    : null,
                onTap: () => Navigator.pop(context, fertilizer),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t['cancel']),
          ),
        ],
      ),
    );

    if (selected != null) {
      _addFertilizer(selected);
    }
  }

  /// Build measurement form fields (simple)
  List<Widget> _buildMeasurementFields() {
    return [
      Text(
        'Quick Measurement',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _currentLevelController,
        decoration: InputDecoration(
          labelText: _t['current_level'],
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.water_drop),
          suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _currentPhController,
              decoration: const InputDecoration(
                labelText: 'pH',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _currentEcController,
              decoration: InputDecoration(
                labelText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'EC'
                    : 'PPM',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Build maintenance form fields (checklist)
  List<Widget> _buildMaintenanceFields() {
    return [
      Text(
        'Maintenance Checklist',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        title: const Text('Pumps cleaned'),
        value: _cleanedPumps,
        onChanged: (value) => setState(() => _cleanedPumps = value ?? false),
        dense: true,
      ),
      CheckboxListTile(
        title: const Text('Filters changed'),
        value: _changedFilters,
        onChanged: (value) => setState(() => _changedFilters = value ?? false),
        dense: true,
      ),
      CheckboxListTile(
        title: const Text('Tubes checked'),
        value: _checkedTubes,
        onChanged: (value) => setState(() => _checkedTubes = value ?? false),
        dense: true,
      ),
      CheckboxListTile(
        title: const Text('Reservoir cleaned'),
        value: _cleanedReservoir,
        onChanged: (value) =>
            setState(() => _cleanedReservoir = value ?? false),
        dense: true,
      ),
      CheckboxListTile(
        title: const Text('Airstones cleaned'),
        value: _cleanedAirstones,
        onChanged: (value) =>
            setState(() => _cleanedAirstones = value ?? false),
        dense: true,
      ),
      const SizedBox(height: 16),
      Text(
        'pH / EC (optional)',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _phBeforeController,
              decoration: InputDecoration(
                labelText: 'pH ${_t['level_before']}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _ecBeforeController,
              decoration: InputDecoration(
                labelText:
                    '${_settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM'} ${_t['level_before']}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science_outlined),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _ecAfterController,
              decoration: InputDecoration(
                labelText:
                    '${_settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM'} ${_t['level_after']}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Build full change form fields
  List<Widget> _buildFullChangeFields() {
    return [
      Text(
        'Old Water',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _phBeforeController,
              decoration: const InputDecoration(
                labelText: 'Old pH',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _ecBeforeController,
              decoration: InputDecoration(
                labelText:
                    'Old ${_settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM'}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science_outlined),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        'New Water',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _levelAfterController,
        decoration: InputDecoration(
          labelText: _t['level_after'],
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.water_drop),
          suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'New water level is required';
          }
          final number = double.tryParse(value);
          if (number == null) return 'Invalid number';
          if (number > widget.system.maxCapacity) {
            return 'Cannot exceed max capacity';
          }
          return null;
        },
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _phAfterController,
              decoration: const InputDecoration(
                labelText: 'New pH',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.science),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _ecAfterController,
              decoration: InputDecoration(
                labelText:
                    'New ${_settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM'}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      CheckboxListTile(
        title: const Text('Reservoir cleaned during change'),
        value: _reservoirCleanedOnChange,
        onChanged: (value) =>
            setState(() => _reservoirCleanedOnChange = value ?? false),
      ),
    ];
  }

  /// Build addback form fields (existing logic)
  List<Widget> _buildAddbackFields() {
    return [
      Text(
        'Water',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _levelBeforeController,
        decoration: InputDecoration(
          labelText: _t['level_before'],
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.water_drop_outlined),
          suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _calculateLevelAfter(),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _waterAddedController,
        decoration: InputDecoration(
          labelText: _t['water_added'],
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.add_circle),
          suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _calculateLevelAfter(),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _levelAfterController,
        decoration: InputDecoration(
          labelText: _t['level_after'],
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.water_drop),
          suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Level after is required';
          }
          final number = double.tryParse(value);
          if (number == null) return 'Invalid number';
          if (number > widget.system.maxCapacity) {
            return 'Cannot exceed max capacity';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      Text(
        'pH / EC',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _phBeforeController,
              decoration: InputDecoration(
                labelText: 'pH ${_t['level_before']}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _ecBeforeController,
              decoration: InputDecoration(
                labelText:
                    '${_settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM'} ${_t['level_before']}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science_outlined),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _ecAfterController,
              decoration: InputDecoration(
                labelText:
                    '${_settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM'} ${_t['level_after']}',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.science),
                suffixText: _settings.nutrientUnit == NutrientUnit.ec
                    ? 'mS/cm'
                    : 'PPM',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Get title based on log type
  String _getTitle() {
    switch (_logType) {
      case RdwcLogType.measurement:
        return 'Quick Measurement';
      case RdwcLogType.fullChange:
        return _t['full_change'];
      case RdwcLogType.maintenance:
        return _t['maintenance'];
      case RdwcLogType.addback:
        return _t['add_addback'];
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(_getTitle())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // System info card
            Card(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.water_damage, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.system.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_t['current_level']}: ${UnitConverter.formatVolume(widget.system.currentLevel, _settings.volumeUnit)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Log Type Selector (Prominent)
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DropdownButtonFormField<RdwcLogType>(
                  initialValue: _logType,
                  decoration: InputDecoration(
                    labelText: _t['log_type'],
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.category),
                    filled: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: RdwcLogType.addback,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_t['water_addback']),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: RdwcLogType.fullChange,
                      child: Row(
                        children: [
                          const Icon(Icons.sync, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(_t['full_change']),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: RdwcLogType.maintenance,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.build,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_t['maintenance']),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: RdwcLogType.measurement,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science,
                            color: Colors.purple,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(_t['measurement']),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _logType = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic fields based on log type
            if (_logType == RdwcLogType.measurement)
              ..._buildMeasurementFields()
            else if (_logType == RdwcLogType.fullChange)
              ..._buildFullChangeFields()
            else if (_logType == RdwcLogType.maintenance)
              ..._buildMaintenanceFields()
            else
              ..._buildAddbackFields(),

            const SizedBox(height: 16),

            // Note
            TextFormField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: _t['note'],
                hintText: 'Week 3 of bloom, drinking heavily',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // v8: Fertilizer section (Expert Mode, only for addback and fullChange)
            if (_settings.isExpertMode &&
                (_logType == RdwcLogType.addback ||
                    _logType == RdwcLogType.fullChange))
              ..._buildFertilizerSection(),

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
              label: Text(_isSaving ? 'Saving...' : _t['save']),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // v8: Recipe loading methods
  Future<void> _showRecipePickerDialog() async {
    try {
      final recipes = await _rdwcRepo.getAllRecipes();

      if (recipes.isEmpty) {
        if (mounted) {
          AppMessages.showInfo(context, _t['no_recipes_available']);
        }
        return;
      }

      if (!mounted) return;

      final selected = await showDialog<RdwcRecipe>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t['select_recipe']),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return ListTile(
                  leading: const Icon(Icons.science),
                  title: Text(recipe.name),
                  subtitle:
                      [
                        if (recipe.targetEc != null)
                          'EC: ${recipe.targetEc!.toStringAsFixed(1)}',
                        if (recipe.targetPh != null)
                          'pH: ${recipe.targetPh!.toStringAsFixed(1)}',
                      ].isNotEmpty
                      ? Text(
                          [
                            if (recipe.targetEc != null)
                              'EC: ${recipe.targetEc!.toStringAsFixed(1)}',
                            if (recipe.targetPh != null)
                              'pH: ${recipe.targetPh!.toStringAsFixed(1)}',
                          ].join(' | '),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, recipe),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t['cancel']),
            ),
          ],
        ),
      );

      if (selected != null) {
        await _loadRecipe(selected);
      }
    } catch (e) {
      AppLogger.error('RdwcAddbackFormScreen', 'Error loading recipes', e);
      if (mounted) {
        AppMessages.showError(context, _t['error_loading_recipes']);
      }
    }
  }

  Future<void> _loadRecipe(RdwcRecipe recipe) async {
    try {
      // Load recipe fertilizers
      if (recipe.id == null) return;

      final recipeFerts = await _rdwcRepo.getRecipeFertilizers(recipe.id!);

      // Clear current fertilizers
      for (final entry in _addedFertilizers) {
        entry.amountController.dispose();
      }
      _addedFertilizers.clear();

      // Add recipe fertilizers
      for (final rf in recipeFerts) {
        final fert = await _fertilizerRepo.findById(rf.fertilizerId);
        if (fert != null) {
          _addedFertilizers.add(
            _FertilizerEntry(
              fertilizer: fert,
              amountController: TextEditingController(
                text: rf.mlPerLiter.toString(),
              ),
              amountType: FertilizerAmountType.perLiter,
            ),
          );
        }
      }

      // Pre-fill target values if available
      if (recipe.targetEc != null && _ecAfterController.text.isEmpty) {
        _ecAfterController.text = recipe.targetEc.toString();
      }
      if (recipe.targetPh != null && _phAfterController.text.isEmpty) {
        _phAfterController.text = recipe.targetPh.toString();
      }

      setState(() {
        _loadedRecipe = recipe;
      });

      if (mounted) {
        AppMessages.showSuccess(
          context,
          '${_t['recipe_loaded']}: ${recipe.name}',
        );
      }
    } catch (e) {
      AppLogger.error('RdwcAddbackFormScreen', 'Error applying recipe', e);
      if (mounted) {
        AppMessages.showError(context, _t['error_loading_recipe']);
      }
    }
  }

  void _clearRecipe() {
    setState(() {
      _loadedRecipe = null;
    });
    AppMessages.showSuccess(context, _t['recipe_cleared']);
  }
}

// v8: Helper class to track fertilizers being added
class _FertilizerEntry {
  final Fertilizer fertilizer;
  final TextEditingController amountController;
  FertilizerAmountType amountType;

  _FertilizerEntry({
    required this.fertilizer,
    required this.amountController,
    required this.amountType,
  });
}
