// =============================================
// GROWLOG - RDWC Düngerplan-Generator Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';

class RdwcDosingPlanScreen extends StatefulWidget {
  const RdwcDosingPlanScreen({super.key});

  @override
  State<RdwcDosingPlanScreen> createState() => _RdwcDosingPlanScreenState();
}

class _RdwcDosingPlanScreenState extends State<RdwcDosingPlanScreen> {
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late AppTranslations _t;
  bool _isLoading = true;

  // Data
  List<RdwcRecipe> _recipes = [];
  List<RdwcSystem> _systems = [];
  Map<int, Fertilizer> _fertilizerMap = {};

  // Selections
  RdwcRecipe? _selectedRecipe;
  RdwcSystem? _selectedSystem;
  List<RecipeFertilizer> _recipeFertilizers = [];

  // Form
  final _volumeController = TextEditingController(text: '100');
  int _weeks = 4;
  final _formKey = GlobalKey<FormState>();

  // Result
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final recipes = await _rdwcRepo.getAllRecipes();
      final systems = await _rdwcRepo.getAllSystems();
      final fertilizers = await _fertilizerRepo.findAll();

      final fertMap = <int, Fertilizer>{};
      for (final f in fertilizers) {
        if (f.id != null) fertMap[f.id!] = f;
      }

      if (mounted) {
        setState(() {
          _t = AppTranslations(settings.language);
          _recipes = recipes;
          _systems = systems;
          _fertilizerMap = fertMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcDosingPlanScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRecipeSelected(RdwcRecipe? recipe) async {
    if (recipe == null) {
      setState(() {
        _selectedRecipe = null;
        _recipeFertilizers = [];
        _showResult = false;
      });
      return;
    }
    try {
      final ferts = recipe.id != null
          ? await _rdwcRepo.getRecipeFertilizers(recipe.id!)
          : <RecipeFertilizer>[];
      if (mounted) {
        setState(() {
          _selectedRecipe = recipe;
          _recipeFertilizers = ferts;
          _showResult = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcDosingPlanScreen', 'Error loading recipe fertilizers', e);
    }
  }

  void _onSystemSelected(RdwcSystem? system) {
    setState(() {
      _selectedSystem = system;
      if (system != null) {
        _volumeController.text = system.maxCapacity.toStringAsFixed(0);
      }
      _showResult = false;
    });
  }

  void _generate() {
    if (_formKey.currentState!.validate()) {
      setState(() => _showResult = true);
    }
  }

  double get _volumeLiters =>
      double.tryParse(_volumeController.text.replaceAll(',', '.')) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _isLoading ? '' : _t['dosing_plan_title'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildConfigCard(),
                  const SizedBox(height: 16),
                  if (_showResult && _selectedRecipe != null) ...[
                    _buildResultTable(),
                    const SizedBox(height: 16),
                    _buildEcPhInfo(),
                  ] else if (!_showResult && _selectedRecipe == null) ...[
                    _buildEmptyState(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildConfigCard() {
    return Container(
      decoration: DT.cardDecoFlat(),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recipe Dropdown
            Text(
              _t['dosing_plan_select_recipe'],
              style: const TextStyle(
                color: DT.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<RdwcRecipe>(
              key: ValueKey(_selectedRecipe?.id),
              initialValue: _selectedRecipe,
              decoration: _inputDeco(_t['dosing_plan_recipe_hint']),
              dropdownColor: DT.elevated,
              style: const TextStyle(color: DT.textPrimary),
              items: _recipes.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r.name),
                );
              }).toList(),
              onChanged: _onRecipeSelected,
            ),
            const SizedBox(height: 16),

            // System Dropdown (optional)
            Text(
              _t['dosing_plan_select_system'],
              style: const TextStyle(
                color: DT.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<RdwcSystem?>(
              key: ValueKey(_selectedSystem?.id),
              initialValue: _selectedSystem,
              decoration: _inputDeco(_t['dosing_plan_system_hint']),
              dropdownColor: DT.elevated,
              style: const TextStyle(color: DT.textPrimary),
              items: [
                DropdownMenuItem<RdwcSystem?>(
                  value: null,
                  child: Text(
                    _t['dosing_plan_no_system'],
                    style: const TextStyle(color: DT.textSecondary),
                  ),
                ),
                ..._systems.map((s) {
                  return DropdownMenuItem<RdwcSystem?>(
                    value: s,
                    child: Text('${s.name} (${s.maxCapacity.toStringAsFixed(0)} ${_t['unit_liters']})'),
                  );
                }),
              ],
              onChanged: _onSystemSelected,
            ),
            const SizedBox(height: 16),

            // Volume Field
            Text(
              _t['dosing_plan_volume_label'],
              style: const TextStyle(
                color: DT.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _volumeController,
              decoration: _inputDeco(_t['dosing_plan_volume_hint']),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: DT.textPrimary),
              onChanged: (_) => setState(() => _showResult = false),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _t['dosing_plan_volume_required'];
                }
                final v = double.tryParse(value.replaceAll(',', '.'));
                if (v == null || v <= 0) {
                  return _t['dosing_plan_volume_invalid'];
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Weeks slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _t['dosing_plan_weeks_label'],
                  style: const TextStyle(
                    color: DT.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: DT.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(DT.radiusChip),
                    border: Border.all(color: DT.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$_weeks ${_t['dosing_plan_weeks_unit']}',
                    style: const TextStyle(
                      color: DT.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _weeks.toDouble(),
              min: 1,
              max: 16,
              divisions: 15,
              activeColor: DT.accent,
              inactiveColor: DT.border,
              onChanged: (v) => setState(() {
                _weeks = v.round();
                _showResult = false;
              }),
            ),

            const SizedBox(height: 8),

            // Generate button
            ElevatedButton.icon(
              onPressed: _selectedRecipe != null ? _generate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.accent,
                foregroundColor: DT.onAccent,
                disabledBackgroundColor: DT.border,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DT.radiusButton),
                ),
              ),
              icon: const Icon(Icons.table_chart),
              label: Text(
                _t['dosing_plan_generate'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: DT.cardDecoFlat(),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.science_outlined, size: 48, color: DT.textTertiary),
          const SizedBox(height: 12),
          Text(
            _t['dosing_plan_no_recipe_selected'],
            style: const TextStyle(
              color: DT.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResultTable() {
    final volume = _volumeLiters;
    if (volume <= 0 || _recipeFertilizers.isEmpty) {
      return Container(
        decoration: DT.cardDecoFlat(),
        padding: const EdgeInsets.all(24),
        child: Text(
          _t['dosing_plan_no_fertilizers'],
          style: const TextStyle(color: DT.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Build ordered fertilizer list for columns
    final cols = _recipeFertilizers
        .map((rf) => _fertilizerMap[rf.fertilizerId])
        .toList();

    return Container(
      decoration: DT.cardDecoFlat(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.table_chart, color: DT.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  _t['dosing_plan_table_title'],
                  style: const TextStyle(
                    color: DT.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: DT.border, height: 1),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(DT.elevated),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                // alternating rows handled per-row below
                return null;
              }),
              border: TableBorder.all(color: DT.border, width: 0.5),
              columnSpacing: 20,
              headingRowHeight: 44,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 40,
              columns: [
                DataColumn(
                  label: Text(
                    _t['dosing_plan_col_week'],
                    style: const TextStyle(
                      color: DT.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...cols.map((fert) => DataColumn(
                  label: Text(
                    fert?.name ?? '?',
                    style: const TextStyle(
                      color: DT.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )),
                DataColumn(
                  label: Text(
                    _t['dosing_plan_col_total'],
                    style: const TextStyle(
                      color: DT.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              rows: List.generate(_weeks, (weekIdx) {
                final isEven = weekIdx % 2 == 0;
                final rowColor = isEven ? DT.surface : DT.canvas;

                final totalMl = _recipeFertilizers.fold<double>(
                  0.0,
                  (sum, rf) => sum + rf.mlPerLiter * volume,
                );

                return DataRow(
                  color: WidgetStateProperty.all(rowColor),
                  cells: [
                    DataCell(Text(
                      '${_t['dosing_plan_week_prefix']} ${weekIdx + 1}',
                      style: const TextStyle(
                        color: DT.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    ..._recipeFertilizers.map((rf) {
                      final ml = rf.mlPerLiter * volume;
                      return DataCell(Text(
                        '${ml.toStringAsFixed(1)} ml',
                        style: DT.mono(size: 12, color: DT.textPrimary),
                      ));
                    }),
                    DataCell(Text(
                      '${totalMl.toStringAsFixed(1)} ml',
                      style: DT.mono(
                        size: 12,
                        color: DT.accent,
                        weight: FontWeight.bold,
                      ),
                    )),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEcPhInfo() {
    final recipe = _selectedRecipe;
    if (recipe == null) return const SizedBox.shrink();
    if (recipe.targetEc == null && recipe.targetPh == null) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: DT.cardDecoFlat(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (recipe.targetEc != null) ...[
            _buildTargetChip(
              icon: Icons.analytics,
              label: '${_t['dosing_plan_target_ec']}: ${recipe.targetEc!.toStringAsFixed(2)}',
              color: DT.success,
            ),
          ],
          if (recipe.targetEc != null && recipe.targetPh != null)
            const SizedBox(width: 12),
          if (recipe.targetPh != null) ...[
            _buildTargetChip(
              icon: Icons.water_drop,
              label: '${_t['dosing_plan_target_ph']}: ${recipe.targetPh!.toStringAsFixed(2)}',
              color: DT.warning,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTargetChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DT.radiusChip),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: DT.textTertiary),
      filled: true,
      fillColor: DT.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.radiusInput),
        borderSide: const BorderSide(color: DT.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.radiusInput),
        borderSide: const BorderSide(color: DT.accent),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.radiusInput),
        borderSide: const BorderSide(color: DT.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.radiusInput),
        borderSide: const BorderSide(color: DT.error),
      ),
    );
  }
}
