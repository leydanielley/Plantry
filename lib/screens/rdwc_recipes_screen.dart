// =============================================
// GROWLOG - RDWC Recipes Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/widgets/empty_state_widget.dart';
import 'package:growlog_app/screens/rdwc_recipe_form_screen.dart';
import 'package:growlog_app/di/service_locator.dart';

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

      if (mounted) {
        setState(() {
          _t = AppTranslations(settings.language);
          _recipes = recipes;
          _recipeFertilizers = fertilizers;
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(_t['recipes'])),
      floatingActionButton: FloatingActionButton(
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
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _recipes.length,
                itemBuilder: (context, index) {
                  final recipe = _recipes[index];
                  final fertilizers = _recipeFertilizers[recipe.id] ?? [];
                  return _buildRecipeCard(recipe, fertilizers, isDark);
                },
              ),
            ),
    );
  }

  /// ✅ PHASE 4: Replaced with shared EmptyStateWidget
  Widget _buildEmptyState(bool isDark) {
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

  Widget _buildRecipeCard(
    RdwcRecipe recipe,
    List<Fertilizer> fertilizers,
    bool isDark,
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
                  Icon(Icons.science, color: Colors.green[700]),
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
                    color: Colors.red,
                  ),
                ],
              ),
              if (recipe.description != null &&
                  recipe.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  recipe.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.science,
                    label: '${fertilizers.length} ${_t['fertilizers']}',
                    color: Colors.blue,
                  ),
                  if (recipe.targetEc != null) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.analytics,
                      label: 'EC: ${recipe.targetEc!.toStringAsFixed(1)}',
                      color: Colors.green,
                    ),
                  ],
                  if (recipe.targetPh != null) ...[
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      icon: Icons.water_drop,
                      label: 'pH: ${recipe.targetPh!.toStringAsFixed(1)}',
                      color: Colors.orange,
                    ),
                  ],
                ],
              ),
              if (fertilizers.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: fertilizers.map((fert) {
                    return Chip(
                      label: Text(
                        fert.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      avatar: const Icon(Icons.local_florist, size: 16),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
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
