// =============================================
// GROWLOG - Universal Nutrient Calculator Screen
// =============================================

import 'package:flutter/material.dart';
import '../models/rdwc_system.dart';
import '../models/rdwc_recipe.dart';
import '../models/rdwc_log.dart';
import '../models/rdwc_log_fertilizer.dart';
import '../models/fertilizer.dart';
import '../models/app_settings.dart';
import '../models/nutrient_calculation.dart';
import '../repositories/interfaces/i_rdwc_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../utils/translations.dart';
import '../utils/unit_converter.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../di/service_locator.dart';

class NutrientCalculatorScreen extends StatefulWidget {
  final RdwcSystem? system;  // Optional - null for standalone mode
  final CalculatorMode? initialMode;

  const NutrientCalculatorScreen({
    super.key,
    this.system,
    this.initialMode,
  });

  @override
  State<NutrientCalculatorScreen> createState() => _NutrientCalculatorScreenState();
}

class _NutrientCalculatorScreenState extends State<NutrientCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();

  late TextEditingController _currentVolumeController;
  late TextEditingController _currentPpmController;
  late TextEditingController _targetPpmController;
  late TextEditingController _targetVolumeController;  // NEW: for batch mix

  late AppTranslations _t;
  late AppSettings _settings;
  bool _isLoading = true;
  bool _isSaving = false;

  late CalculatorMode _calculatorMode;  // NEW: Calculator mode
  RecipeMode _recipeMode = RecipeMode.recipe;  // NEW: Recipe usage mode
  List<RdwcRecipe> _recipes = [];
  RdwcRecipe? _selectedRecipe;
  Map<int, List<Fertilizer>> _recipeFertilizers = {};

  // Direct fertilizer mode
  List<Fertilizer> _allFertilizers = [];  // All fertilizers from DB
  List<Fertilizer> _selectedFertilizers = [];  // Selected for direct mode

  NutrientCalculation? _result;

  @override
  void initState() {
    super.initState();

    // Initialize calculator mode
    _calculatorMode = widget.initialMode ??
      (widget.system != null ? CalculatorMode.topUp : CalculatorMode.batchMix);

    // Initialize controllers based on mode and system
    _currentVolumeController = TextEditingController(
      text: widget.system?.currentLevel.toStringAsFixed(1) ?? '0',
    );
    _currentPpmController = TextEditingController();
    _targetPpmController = TextEditingController();
    _targetVolumeController = TextEditingController(
      text: widget.system?.maxCapacity.toStringAsFixed(1) ?? '',
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final recipes = await _rdwcRepo.getAllRecipes();

      // Load fertilizers for each recipe
      final Map<int, List<Fertilizer>> fertilizers = {};
      for (final recipe in recipes) {
        if (recipe.id != null) {
          final recipeFerts = await _rdwcRepo.getRecipeFertilizers(recipe.id!);
          final List<Fertilizer> ferts = [];
          for (final rf in recipeFerts) {
            final fert = await _fertilizerRepo.findById(rf.fertilizerId);
            if (fert != null) ferts.add(fert);
          }
          fertilizers[recipe.id!] = ferts;
        }
      }

      // Load all fertilizers for direct mode
      final allFertilizers = await _fertilizerRepo.findAll();

      if (mounted) {
        setState(() {
          _settings = settings;
          _t = AppTranslations(settings.language);
          _recipes = recipes;
          _recipeFertilizers = fertilizers;
          _allFertilizers = allFertilizers;
          // Default to manual mode if no recipes available
          if (_recipes.isEmpty) {
            _recipeMode = RecipeMode.manual;
          } else {
            _selectedRecipe = _recipes.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('NutrientCalculatorScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _currentVolumeController.dispose();
    _currentPpmController.dispose();
    _targetPpmController.dispose();
    _targetVolumeController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final currentVolume = double.parse(_currentVolumeController.text);
    final currentPPM = double.parse(_currentPpmController.text);
    final targetPPM = double.parse(_targetPpmController.text);
    final targetVolume = _calculatorMode == CalculatorMode.batchMix
        ? double.parse(_targetVolumeController.text)
        : widget.system!.maxCapacity;

    NutrientCalculation calculation;

    // Batch mix mode
    if (_calculatorMode == CalculatorMode.batchMix) {
      calculation = NutrientCalculation.batchMix(
        volume: targetVolume,
        targetPPM: targetPPM,
        recipe: _recipeMode == RecipeMode.recipe ? _selectedRecipe : null,
        settings: _settings,
      );
    }
    // Top-up or other modes with recipe
    else if (_recipeMode == RecipeMode.recipe && _selectedRecipe != null) {
      calculation = NutrientCalculation.withRecipe(
        targetVolume: targetVolume,
        currentVolume: currentVolume,
        currentPPM: currentPPM,
        targetPPM: targetPPM,  // User-specified target for entire system
        recipe: _selectedRecipe!,
        settings: _settings,
        calculatorMode: _calculatorMode,
      );
    }
    // Direct fertilizer mode
    else if (_recipeMode == RecipeMode.direct) {
      // For now, show PPM calculations like manual mode
      // Future: Calculate optimal fertilizer amounts based on selected fertilizers
      calculation = NutrientCalculation(
        targetVolume: targetVolume,
        currentVolume: currentVolume,
        currentPPM: currentPPM,
        targetPPM: targetPPM,
        settings: _settings,
        calculatorMode: _calculatorMode,
        recipeMode: RecipeMode.direct,
      );
    }
    // Manual mode
    else {
      calculation = NutrientCalculation(
        targetVolume: targetVolume,
        currentVolume: currentVolume,
        currentPPM: currentPPM,
        targetPPM: targetPPM,
        settings: _settings,
        calculatorMode: _calculatorMode,
        recipeMode: RecipeMode.manual,
      );
    }

    setState(() {
      _result = calculation;
    });
  }

  void _reset() {
    if (widget.system != null) {
      _currentVolumeController.text = widget.system!.currentLevel.toStringAsFixed(1);
      _targetVolumeController.text = widget.system!.maxCapacity.toStringAsFixed(1);
    } else {
      _currentVolumeController.text = '0';
      _targetVolumeController.clear();
    }
    _currentPpmController.clear();
    _targetPpmController.clear();
    setState(() {
      _result = null;
    });
  }

  Future<void> _saveAsLog() async {
    if (_result == null || widget.system == null) return;

    setState(() => _isSaving = true);

    try {
      final log = RdwcLog(
        systemId: widget.system!.id!,
        logType: RdwcLogType.addback,
        logDate: DateTime.now(),
        levelBefore: double.parse(_currentVolumeController.text),
        waterAdded: _result!.volumeToAdd,
        levelAfter: _result!.targetVolume,
        ecBefore: UnitConverter.ppmToEc(
          double.parse(_currentPpmController.text),
          _settings.ppmScale,
        ),
        ecAfter: _result!.targetEC,
        note: _recipeMode == RecipeMode.recipe && _selectedRecipe != null
            ? '${_calculatorMode.name} calculation using recipe: ${_selectedRecipe!.name}'
            : '${_calculatorMode.name} calculation (manual)',
      );

      final logId = await _rdwcRepo.createLog(log);

      // Add SCALED fertilizers if recipe mode
      if (_recipeMode == RecipeMode.recipe && _selectedRecipe != null) {
        final scalingFactor = _result!.scalingFactor;
        for (final recipeFert in _selectedRecipe!.fertilizers) {
          final scaledMlPerLiter = recipeFert.mlPerLiter * scalingFactor;
          final logFert = RdwcLogFertilizer(
            rdwcLogId: logId,
            fertilizerId: recipeFert.fertilizerId,
            amount: scaledMlPerLiter,  // Scaled amount
            amountType: FertilizerAmountType.perLiter,
          );
          await _rdwcRepo.addFertilizerToLog(logFert);
        }
      }

      // Update system level
      await _rdwcRepo.updateSystemLevel(widget.system!.id!, _result!.targetVolume);

      if (mounted) {
        AppMessages.showSuccess(context, _t['log_created']);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('NutrientCalculatorScreen', 'Error saving log', e);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.calculate, color: Colors.orange),
            const SizedBox(width: 8),
            Text(_t['topup_calculator']),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: _t['reset'],
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoCard(isDark),
            const SizedBox(height: 24),
            // Show system info only if system is provided
            if (widget.system != null) ...[
              _buildSystemInfo(isDark),
              const SizedBox(height: 24),
            ],
            // Show calculator mode selector only in standalone mode
            if (widget.system == null) ...[
              _buildModeSelector(isDark),
              const SizedBox(height: 24),
            ],
            _buildCurrentStatusSection(isDark),
            const SizedBox(height: 24),
            _buildTargetSection(isDark),
            const SizedBox(height: 24),
            _buildCalculateButton(),
            if (_result != null) ...[
              const SizedBox(height: 32),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              _buildResultSection(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  _t['topup_calculator'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _t['topup_calculator_description'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector(bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['calculator_mode'] ?? 'Calculator Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CalculatorMode>(
              segments: [
                ButtonSegment(
                  value: CalculatorMode.batchMix,
                  label: Text(_t['batch_mix'] ?? 'Batch Mix'),
                  icon: const Icon(Icons.science_outlined),
                ),
                ButtonSegment(
                  value: CalculatorMode.quickMix,
                  label: Text(_t['quick_mix'] ?? 'Quick Mix'),
                  icon: const Icon(Icons.speed),
                ),
              ],
              selected: {_calculatorMode},
              onSelectionChanged: (Set<CalculatorMode> newSelection) {
                setState(() {
                  _calculatorMode = newSelection.first;
                  _result = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfo(bool isDark) {
    if (widget.system == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['system_info'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.water, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.system!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_t['system_capacity']}: ${UnitConverter.formatVolume(widget.system!.maxCapacity, _settings.volumeUnit)}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusSection(bool isDark) {
    final volumeUnit = UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit);
    final nutrientLabel = _settings.nutrientUnit == NutrientUnit.ec
        ? 'EC (mS/cm)'
        : 'PPM (${_settings.ppmScale.scaleLabel})';

    // Hide current status in batch mix mode (starting from 0)
    if (_calculatorMode == CalculatorMode.batchMix) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['current_status'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentVolumeController,
              decoration: InputDecoration(
                labelText: _t['current_volume'],
                hintText: '50',
                prefixIcon: const Icon(Icons.water_drop, color: Colors.blue),
                border: const OutlineInputBorder(),
                suffixText: volumeUnit,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _t['required_field'];
                }
                final number = double.tryParse(value);
                if (number == null || number < 0) {
                  return _t['invalid_number'];
                }
                if (widget.system != null && number > widget.system!.maxCapacity) {
                  return _t['error_volume_exceeds_capacity'];
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentPpmController,
              decoration: InputDecoration(
                labelText: _t['current_ppm'],
                hintText: _settings.nutrientUnit == NutrientUnit.ec ? '1.2' : '800',
                prefixIcon: Icon(Icons.science, color: Colors.orange[700]),
                border: const OutlineInputBorder(),
                suffixText: nutrientLabel,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _t['required_field'];
                }
                final number = double.tryParse(value);
                if (number == null || number < 0) {
                  return _t['invalid_number'];
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetSection(bool isDark) {
    final volumeUnit = UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['target_selection'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Target volume (for batch mix and quick mix)
            if (_calculatorMode == CalculatorMode.batchMix ||
                _calculatorMode == CalculatorMode.quickMix) ...[
              TextFormField(
                controller: _targetVolumeController,
                decoration: InputDecoration(
                  labelText: _t['target_volume'],
                  hintText: '60',
                  prefixIcon: const Icon(Icons.water, color: Colors.blue),
                  border: const OutlineInputBorder(),
                  suffixText: volumeUnit,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _t['required_field'];
                  }
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) {
                    return _t['invalid_number'];
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            // Mode toggle (Manual vs Recipe vs Direct)
            if (_recipes.isNotEmpty || _allFertilizers.isNotEmpty) ...[
              SegmentedButton<RecipeMode>(
                segments: [
                  ButtonSegment(
                    value: RecipeMode.manual,
                    label: Text(_t['manual_mode']),
                    icon: const Icon(Icons.edit),
                  ),
                  if (_recipes.isNotEmpty)
                    ButtonSegment(
                      value: RecipeMode.recipe,
                      label: Text(_t['recipe_mode']),
                      icon: const Icon(Icons.science),
                    ),
                  if (_allFertilizers.isNotEmpty)
                    ButtonSegment(
                      value: RecipeMode.direct,
                      label: const Text('Direct'),
                      icon: const Icon(Icons.local_florist),
                    ),
                ],
                selected: {_recipeMode},
                onSelectionChanged: (Set<RecipeMode> newSelection) {
                  setState(() {
                    _recipeMode = newSelection.first;
                    _result = null; // Clear previous result
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            // Target PPM input (always shown)
            _buildManualTargetInput(isDark),
            // Recipe selection (only in recipe mode)
            if (_recipeMode == RecipeMode.recipe) ...[
              const SizedBox(height: 16),
              _buildRecipeSelection(isDark),
            ],
            // Direct fertilizer selection (only in direct mode)
            if (_recipeMode == RecipeMode.direct) ...[
              const SizedBox(height: 16),
              _buildDirectFertilizerSelection(isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualTargetInput(bool isDark) {
    final nutrientLabel = _settings.nutrientUnit == NutrientUnit.ec
        ? 'EC (mS/cm)'
        : 'PPM (${_settings.ppmScale.scaleLabel})';

    return TextFormField(
      controller: _targetPpmController,
      decoration: InputDecoration(
        labelText: _t['target_ppm'],
        hintText: _settings.nutrientUnit == NutrientUnit.ec ? '1.8' : '1200',
        prefixIcon: Icon(Icons.flag, color: Colors.green[700]),
        border: const OutlineInputBorder(),
        suffixText: nutrientLabel,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return _t['required_field'];
        }
        final number = double.tryParse(value);
        if (number == null || number < 0) {
          return _t['invalid_number'];
        }
        return null;
      },
    );
  }

  Widget _buildRecipeSelection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<RdwcRecipe>(
          value: _selectedRecipe,
          decoration: InputDecoration(
            labelText: _t['select_recipe'],
            prefixIcon: Icon(Icons.science, color: Colors.green[700]),
            border: const OutlineInputBorder(),
          ),
          items: _recipes.map((recipe) {
            return DropdownMenuItem(
              value: recipe,
              child: Text(recipe.name),
            );
          }).toList(),
          onChanged: (recipe) {
            setState(() {
              _selectedRecipe = recipe;
              _result = null; // Clear previous result
            });
          },
          validator: (value) {
            if (value == null) {
              return _t['required_field'];
            }
            return null;
          },
        ),
        if (_selectedRecipe != null) ...[
          const SizedBox(height: 12),
          _buildRecipePreview(isDark),
        ],
      ],
    );
  }

  Widget _buildRecipePreview(bool isDark) {
    if (_selectedRecipe == null) return const SizedBox.shrink();

    final recipe = _selectedRecipe!;
    final fertilizers = _recipeFertilizers[recipe.id] ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: recipe.targetEc == null
              ? Colors.orange
              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                size: 16,
                color: recipe.targetEc == null ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(
                recipe.targetEc != null
                    ? '${_t['target']}: ${UnitConverter.formatNutrient(recipe.targetEc!, _settings.nutrientUnit, _settings.ppmScale)}'
                    : _t['warning_recipe_no_ec'],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: recipe.targetEc == null ? Colors.orange : null,
                ),
              ),
            ],
          ),
          if (recipe.targetPh != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${_t['target_ph']}: ${recipe.targetPh!.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.local_florist, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                '${fertilizers.length} ${_t['fertilizers']}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectFertilizerSelection(bool isDark) {
    // Filter: Only fertilizers with ppmValue (usable in calculator)
    final usableFertilizers = _allFertilizers.where((f) => f.ppmValue != null && f.ppmValue! > 0).toList();

    if (usableFertilizers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No fertilizers with nutrient data available. Import from HydroBuddy or add manually.',
                style: TextStyle(color: Colors.orange[900]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.local_florist, size: 18, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Select Fertilizers (${_selectedFertilizers.length}/${usableFertilizers.length})',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: usableFertilizers.length,
            itemBuilder: (context, index) {
              final fertilizer = usableFertilizers[index];
              final isSelected = _selectedFertilizers.contains(fertilizer);

              return CheckboxListTile(
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedFertilizers.add(fertilizer);
                    } else {
                      _selectedFertilizers.remove(fertilizer);
                    }
                    _result = null; // Clear previous result
                  });
                },
                title: Text(
                  fertilizer.name,
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  'NPK: ${fertilizer.npk ?? "N/A"} | ${fertilizer.ppmValue!.toStringAsFixed(1)} ppm/${fertilizer.isLiquid == true ? "ml" : "g"}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                secondary: Icon(
                  fertilizer.isLiquid == true ? Icons.water_drop : Icons.scatter_plot,
                  color: Colors.green[700],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalculateButton() {
    return ElevatedButton.icon(
      onPressed: _calculate,
      icon: const Icon(Icons.calculate),
      label: Text(_t['calculate']),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildResultSection(bool isDark) {
    if (_result == null) return const SizedBox.shrink();

    final warningMessage = _result!.getWarningMessage((key) => _t[key]);
    final warningColor = _getWarningColor(_result!.warningLevel);

    return Column(
      children: [
        // Warning message if any
        if (warningMessage != null) ...[
          Card(
            color: warningColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: warningColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      warningMessage,
                      style: TextStyle(
                        color: warningColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Main result card
        if (_result!.isValid) ...[
          Card(
            color: Colors.green[50],
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 48,
                    color: Colors.green[700],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t['result'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildMainResult(isDark),
                  if (_recipeMode == RecipeMode.recipe && _selectedRecipe != null) ...[
                    const SizedBox(height: 24),
                    _buildFertilizerBreakdown(isDark),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Save button (only if system is provided)
          if (widget.system != null)
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveAsLog,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? _t['saving'] : _t['save_as_log']),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildMainResult(bool isDark) {
    if (_result == null) return const SizedBox.shrink();

    final volumeUnit = UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300, width: 2),
      ),
      child: Column(
        children: [
          Text(
            _recipeMode == RecipeMode.recipe && _selectedRecipe != null
                ? '${_t['add_solution_with_recipe']} "${_selectedRecipe!.name}"'
                : _t['add_solution'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _result!.volumeToAdd.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                volumeUnit,
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_t['at']} ${UnitConverter.formatNutrient(_result!.requiredPPM, _settings.nutrientUnit, _settings.ppmScale)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildResultStat(
                _t['final_volume'],
                UnitConverter.formatVolume(_result!.targetVolume, _settings.volumeUnit),
                Icons.water,
                Colors.blue,
              ),
              _buildResultStat(
                _t['final_ppm'],
                UnitConverter.formatNutrient(_result!.targetPPM, _settings.nutrientUnit, _settings.ppmScale),
                Icons.analytics,
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildFertilizerBreakdown(bool isDark) {
    if (_result == null || _selectedRecipe == null) return const SizedBox.shrink();

    final fertilizers = _recipeFertilizers[_selectedRecipe!.id] ?? [];
    final scaledAmounts = _result!.getScaledFertilizerAmounts();

    if (scaledAmounts.isEmpty) return const SizedBox.shrink();

    final scalingFactor = _result!.scalingFactor;
    final recipeTargetPPM = _result!.recipeTargetPPM;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t['required_fertilizers'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (scalingFactor != 1.0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _result!.isHighScaling
                        ? Colors.red.withValues(alpha: 0.1)
                        : _result!.isModerateScaling
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _result!.isHighScaling
                          ? Colors.red
                          : _result!.isModerateScaling
                              ? Colors.orange
                              : Colors.blue,
                    ),
                  ),
                  child: Text(
                    '${_t['scaling_factor']}: ${scalingFactor.toStringAsFixed(2)}x',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _result!.isHighScaling
                          ? Colors.red
                          : _result!.isModerateScaling
                              ? Colors.orange
                              : Colors.blue,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (scalingFactor != 1.0 && recipeTargetPPM != null) ...[
            const SizedBox(height: 8),
            Text(
              '${_t['original_recipe_target']}: ${UnitConverter.formatNutrient(recipeTargetPPM, _settings.nutrientUnit, _settings.ppmScale)} → ${_t['scaled_to']}: ${UnitConverter.formatNutrient(_result!.requiredPPM, _settings.nutrientUnit, _settings.ppmScale)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...fertilizers.map((fert) {
            final recipeFert = _selectedRecipe!.fertilizers.firstWhere(
              (rf) => rf.fertilizerId == fert.id,
            );
            final scaledTotalMl = scaledAmounts[fert.id] ?? 0;
            final scaledMlPerLiter = recipeFert.mlPerLiter * scalingFactor;
            return _buildFertilizerRow(
              fert.name,
              scaledTotalMl,
              scaledMlPerLiter,
              recipeFert.mlPerLiter,  // Original ml/L for comparison
              scalingFactor,
              isDark,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFertilizerRow(
    String name,
    double totalMl,
    double scaledMlPerLiter,
    double originalMlPerLiter,
    double scalingFactor,
    bool isDark,
  ) {
    final isScaled = scalingFactor != 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: isScaled ? 60 : 40,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${totalMl.toStringAsFixed(0)}ml ${_t['total_amount']} (${scaledMlPerLiter.toStringAsFixed(2)}ml/L)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                if (isScaled) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Original: ${originalMlPerLiter.toStringAsFixed(1)}ml/L',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getWarningColor(WarningLevel level) {
    switch (level) {
      case WarningLevel.safe:
        return Colors.green;
      case WarningLevel.warning:
        return Colors.orange;
      case WarningLevel.error:
        return Colors.red;
    }
  }
}
