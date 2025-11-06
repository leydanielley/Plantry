// =============================================
// GROWLOG - RDWC Recipe Form Screen
// =============================================

import 'package:flutter/material.dart';
import '../models/rdwc_recipe.dart';
import '../models/fertilizer.dart';
import '../repositories/rdwc_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/fertilizer_repository.dart';
import '../utils/translations.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';

class RdwcRecipeFormScreen extends StatefulWidget {
  final RdwcRecipe? recipe;

  const RdwcRecipeFormScreen({super.key, this.recipe});

  @override
  State<RdwcRecipeFormScreen> createState() => _RdwcRecipeFormScreenState();
}

class _RdwcRecipeFormScreenState extends State<RdwcRecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final RdwcRepository _rdwcRepo = RdwcRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final FertilizerRepository _fertilizerRepo = FertilizerRepository();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _targetEcController;
  late TextEditingController _targetPhController;

  late AppTranslations _t;
  List<Fertilizer> _availableFertilizers = [];
  final List<_RecipeFertilizerEntry> _addedFertilizers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.recipe?.name ?? '');
    _descriptionController = TextEditingController(text: widget.recipe?.description ?? '');
    _targetEcController = TextEditingController(
      text: widget.recipe?.targetEc != null ? widget.recipe!.targetEc.toString() : '',
    );
    _targetPhController = TextEditingController(
      text: widget.recipe?.targetPh != null ? widget.recipe!.targetPh.toString() : '',
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final fertilizers = await _fertilizerRepo.findAll();

      // Load existing recipe fertilizers if editing
      if (widget.recipe != null && widget.recipe!.id != null) {
        final recipeFerts = await _rdwcRepo.getRecipeFertilizers(widget.recipe!.id!);
        for (final rf in recipeFerts) {
          final fert = await _fertilizerRepo.findById(rf.fertilizerId);
          if (fert != null) {
            _addedFertilizers.add(_RecipeFertilizerEntry(
              fertilizer: fert,
              mlPerLiterController: TextEditingController(text: rf.mlPerLiter.toString()),
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _t = AppTranslations(settings.language);
          _availableFertilizers = fertilizers;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('RdwcRecipeFormScreen', 'Error loading data', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetEcController.dispose();
    _targetPhController.dispose();
    for (final entry in _addedFertilizers) {
      entry.mlPerLiterController.dispose();
    }
    super.dispose();
  }

  void _addFertilizer(Fertilizer fertilizer) {
    setState(() {
      _addedFertilizers.add(_RecipeFertilizerEntry(
        fertilizer: fertilizer,
        mlPerLiterController: TextEditingController(),
      ));
    });
  }

  void _removeFertilizer(int index) {
    setState(() {
      _addedFertilizers[index].mlPerLiterController.dispose();
      _addedFertilizers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_addedFertilizers.isEmpty) {
      AppMessages.showError(context, _t['recipe_needs_fertilizers']);
      return;
    }

    // Validate all fertilizer amounts
    for (final entry in _addedFertilizers) {
      final amount = double.tryParse(entry.mlPerLiterController.text);
      if (amount == null || amount <= 0) {
        AppMessages.showError(context, _t['invalid_fertilizer_amounts']);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final targetEc = _targetEcController.text.isNotEmpty
          ? double.tryParse(_targetEcController.text)
          : null;
      final targetPh = _targetPhController.text.isNotEmpty
          ? double.tryParse(_targetPhController.text)
          : null;

      // Create/update recipe
      final recipe = RdwcRecipe(
        id: widget.recipe?.id,
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        targetEc: targetEc,
        targetPh: targetPh,
      );

      final recipeId = widget.recipe == null
          ? await _rdwcRepo.createRecipe(recipe)
          : await _rdwcRepo.updateRecipe(recipe);

      // Save fertilizers
      // Delete existing if updating
      if (widget.recipe != null && widget.recipe!.id != null) {
        final existingFerts = await _rdwcRepo.getRecipeFertilizers(widget.recipe!.id!);
        for (final fert in existingFerts) {
          if (fert.id != null) {
            await _rdwcRepo.deleteRecipeFertilizer(fert.id!);
          }
        }
      }

      // Add new fertilizers
      for (final entry in _addedFertilizers) {
        final amount = double.parse(entry.mlPerLiterController.text);
        final recipeFert = RecipeFertilizer(
          recipeId: recipeId,
          fertilizerId: entry.fertilizer.id!,
          mlPerLiter: amount,
        );
        await _rdwcRepo.createRecipeFertilizer(recipeFert);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.showSuccess(
          context,
          widget.recipe == null ? _t['recipe_created'] : _t['recipe_updated'],
        );
      }
    } catch (e) {
      AppLogger.error('RdwcRecipeFormScreen', 'Error saving recipe', e);
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context, _t['error_saving_recipe']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe == null ? _t['create_recipe'] : _t['edit_recipe']),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _t['recipe_info_hint'],
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Basic Info
            Text(
              _t['basic_info'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _t['recipe_name'],
                hintText: 'e.g. Bloom Week 3',
                prefixIcon: const Icon(Icons.science),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _t['recipe_name_required'];
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: _t['description'],
                hintText: _t['recipe_description_hint'],
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            // Target Values
            Text(
              _t['target_values'],
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _targetEcController,
                    decoration: InputDecoration(
                      labelText: _t['target_ec'],
                      hintText: 'e.g. 1.8',
                      prefixIcon: const Icon(Icons.analytics),
                      suffixText: 'mS/cm',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _targetPhController,
                    decoration: InputDecoration(
                      labelText: _t['target_ph'],
                      hintText: 'e.g. 5.8',
                      prefixIcon: const Icon(Icons.water_drop),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Fertilizers Section
            Row(
              children: [
                Text(
                  _t['fertilizers'],
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                if (_addedFertilizers.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _t['required'],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Added Fertilizers List
            ..._addedFertilizers.asMap().entries.map((entry) {
              final index = entry.key;
              final fertEntry = entry.value;
              return _buildFertilizerCard(fertEntry, index, isDark);
            }),

            // Add Fertilizer Button
            if (_availableFertilizers.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _showAddFertilizerDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(_t['add_fertilizer']),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFertilizerCard(_RecipeFertilizerEntry entry, int index, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_florist, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.fertilizer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () => _removeFertilizer(index),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.mlPerLiterController,
              decoration: InputDecoration(
                labelText: _t['amount_per_liter'],
                hintText: 'e.g. 2.0',
                suffixText: 'ml/L',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return _t['amount_required'];
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return _t['invalid_amount'];
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

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
                leading: const Icon(Icons.local_florist),
                title: Text(fertilizer.name),
                subtitle: fertilizer.npk != null ? Text('NPK: ${fertilizer.npk}') : null,
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
}

// Helper class to track fertilizers being added to recipe
class _RecipeFertilizerEntry {
  final Fertilizer fertilizer;
  final TextEditingController mlPerLiterController;

  _RecipeFertilizerEntry({
    required this.fertilizer,
    required this.mlPerLiterController,
  });
}
