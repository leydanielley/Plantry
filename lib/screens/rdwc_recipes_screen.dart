// =============================================
// GROWLOG - RDWC Recipes Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/widgets/empty_state_widget.dart';
import 'package:growlog_app/screens/rdwc_recipe_form_screen.dart';
import 'package:growlog_app/screens/rdwc_dosing_plan_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class RdwcRecipesScreen extends StatefulWidget {
  const RdwcRecipesScreen({super.key});

  @override
  State<RdwcRecipesScreen> createState() => _RdwcRecipesScreenState();
}

class _RdwcRecipesScreenState extends State<RdwcRecipesScreen> {
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();

  late AppTranslations _t;
  List<RdwcRecipe> _recipes = [];
  Map<int, List<Fertilizer>> _recipeFertilizers = {};
  Map<int, List<RecipeFertilizer>> _recipeFertilizerData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final recipes = await _rdwcRepo.getAllRecipes();

      // Load fertilizers for each recipe
      final Map<int, List<Fertilizer>> fertilizers = {};
      final Map<int, List<RecipeFertilizer>> fertilizerData = {};
      for (final recipe in recipes) {
        if (recipe.id != null) {
          final recipeFerts = await _rdwcRepo.getRecipeFertilizers(recipe.id!);
          fertilizerData[recipe.id!] = recipeFerts;
          final List<Fertilizer> ferts = [];
          for (final rf in recipeFerts) {
            final fert = await _fertilizerRepo.findById(rf.fertilizerId);
            if (fert != null) ferts.add(fert);
          }
          fertilizers[recipe.id!] = ferts;
        }
      }

      if (mounted) {
        setState(() {
          _t = AppTranslations(settings.language);
          _recipes = recipes;
          _recipeFertilizers = fertilizers;
          _recipeFertilizerData = fertilizerData;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcRecipesScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteRecipe(RdwcRecipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['delete_recipe']),
        content: Text('${_t['delete_recipe_confirm']}: ${recipe.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: DT.error),
            child: Text(_t['delete']),
          ),
        ],
      ),
    );

    if (confirmed == true && recipe.id != null) {
      try {
        await _rdwcRepo.deleteRecipe(recipe.id!);
        if (mounted) {
          AppMessages.showSuccess(context, _t['recipe_deleted']);
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          AppMessages.showError(context, _t['error_deleting_recipe']);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['recipes'],
      actions: [
        IconButton(
          icon: const Icon(Icons.table_chart, color: DT.accent),
          tooltip: _t['dosing_plan_title'],
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RdwcDosingPlanScreen(),
              ),
            );
          },
        ),
      ],
      fab: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RdwcRecipeFormScreen(),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recipes.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _recipes.length,
                itemBuilder: (context, index) {
                  final recipe = _recipes[index];
                  final fertilizers = _recipeFertilizers[recipe.id] ?? [];
                  final recipeFertilizerData = _recipeFertilizerData[recipe.id] ?? [];
                  return _buildRecipeCard(recipe, fertilizers, recipeFertilizerData);
                },
              ),
            ),
    );
  }

  /// ✅ PHASE 4: Replaced with shared EmptyStateWidget
  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.science_outlined,
      title: _t['no_recipes_yet'],
      subtitle: _t['create_first_recipe'],
      action: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RdwcRecipeFormScreen(),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_t['create_recipe']),
      ),
    );
  }

  String _getPhaseName(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return _t['seedling'];
      case PlantPhase.veg:
        return _t['veg'];
      case PlantPhase.bloom:
        return _t['bloom'];
      case PlantPhase.harvest:
        return _t['harvest'];
      case PlantPhase.archived:
        return _t['phase_archived'];
    }
  }

  Color _getPhaseColor(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return DT.success;
      case PlantPhase.veg:
        return DT.info;
      case PlantPhase.bloom:
        return DT.accent;
      case PlantPhase.harvest:
        return DT.warning;
      case PlantPhase.archived:
        return DT.textSecondary;
    }
  }

  Widget _buildRecipeCard(
    RdwcRecipe recipe,
    List<Fertilizer> fertilizers,
    List<RecipeFertilizer> recipeFertilizerData,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RdwcRecipeFormScreen(recipe: recipe),
            ),
          );
          if (result == true) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.science, color: DT.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteRecipe(recipe),
                    color: DT.error,
                  ),
                ],
              ),
              if (recipe.description != null &&
                  recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  recipe.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DT.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildInfoChip(
                    icon: Icons.science,
                    label: '${fertilizers.length} ${_t['fertilizers']}',
                    color: DT.secondary,
                  ),
                  if (recipe.phase != null)
                    _buildInfoChip(
                      icon: Icons.eco,
                      label: '${_t['recipe_phase']}: ${_getPhaseName(recipe.phase!)}',
                      color: _getPhaseColor(recipe.phase!),
                    ),
                  if (recipe.targetEc != null)
                    _buildInfoChip(
                      icon: Icons.analytics,
                      label: 'EC: ${recipe.targetEc!.toStringAsFixed(1)}',
                      color: DT.success,
                    ),
                  if (recipe.targetPh != null)
                    _buildInfoChip(
                      icon: Icons.water_drop,
                      label: 'pH: ${recipe.targetPh!.toStringAsFixed(1)}',
                      color: DT.warning,
                    ),
                ],
              ),
              if (fertilizers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                ...fertilizers.map((fert) {
                  final rf = recipeFertilizerData
                      .cast<RecipeFertilizer?>()
                      .firstWhere(
                        (r) => r?.fertilizerId == fert.id,
                        orElse: () => null,
                      );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_florist,
                          size: 16,
                          color: DT.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fert.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (rf != null)
                          Text(
                            '${rf.mlPerLiter.toStringAsFixed(1)} ${_t['recipe_ml_per_liter']}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: DT.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
