// =============================================
// GROWLOG - Fertilizer DBF Import Screen
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/services/dbf_import_service.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/fertilizer_validator.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class FertilizerDbfImportScreen extends StatefulWidget {
  final File dbfFile;

  const FertilizerDbfImportScreen({super.key, required this.dbfFile});

  @override
  State<FertilizerDbfImportScreen> createState() =>
      _FertilizerDbfImportScreenState();
}

class _FertilizerDbfImportScreenState extends State<FertilizerDbfImportScreen> {
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late AppTranslations _t = AppTranslations('de');
  bool _isLoading = true;
  bool _isImporting = false;
  List<Fertilizer> _parsedFertilizers = [];
  List<String> _duplicateNames = [];
  Set<String> _selectedItems = {}; // Track selected items by name (unique key)
  String _filterMode = 'all'; // 'all', 'substances', 'recipes'
  bool _showAllInvalid = false; // Show all invalid entries or just first 2
  String? _errorMessage;

  // ✅ PERFORMANCE FIX: Cached filtered lists to avoid recomputation in build()
  List<Fertilizer> _cachedFilteredFertilizers = [];
  int _cachedInvalidCount = 0;
  int _cachedIncompleteCount = 0;
  int _cachedSubstanceCount = 0;
  int _cachedRecipeCount = 0;

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadData();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  /// Load and parse DBF file data
  ///
  /// ✅ ARCHITECTURE FIX: Centralized error handling for UI state.
  /// This is the single source of truth for setting _errorMessage and _isLoading.
  Future<void> _loadData() async {
    try {
      await _parseDbfFile();
    } catch (e) {
      // ✅ ARCHITECTURE FIX: Central error handling - now reachable!
      AppLogger.error('FertilizerDbfImportScreen', 'Error loading data', e);
      if (mounted) {
        setState(() {
          _errorMessage = '${_t['dbf_import_error_loading']}: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  /// Parse DBF file and populate fertilizer list
  ///
  /// ✅ ARCHITECTURE FIX: This method now focuses solely on parsing logic.
  /// Error handling and UI state management is delegated to _loadData().
  /// Any exceptions are rethrown to be handled by the caller.
  Future<void> _parseDbfFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      AppLogger.info(
        'FertilizerDbfImportScreen',
        'Parsing DBF file: ${widget.dbfFile.path}',
      );

      // Parse DBF file
      final fertilizers = await DbfImportService.importFromDbf(widget.dbfFile);

      // Check for duplicates
      final existingFertilizers = await _fertilizerRepo.findAll();
      final existingNames = existingFertilizers
          .map((f) => f.name.toLowerCase())
          .toSet();
      final duplicates = fertilizers
          .where((f) => existingNames.contains(f.name.toLowerCase()))
          .map((f) => f.name)
          .toList();

      // Initialize all items as selected (except duplicates, invalid, and incomplete entries)
      final selectedItems = <String>{};
      for (final fertilizer in fertilizers) {
        if (!duplicates.contains(fertilizer.name) &&
            !FertilizerValidator.isInvalid(fertilizer) &&
            !FertilizerValidator.isIncomplete(fertilizer)) {
          selectedItems.add(fertilizer.name);
        }
      }

      setState(() {
        _parsedFertilizers = fertilizers;
        _duplicateNames = duplicates;
        _selectedItems = selectedItems;
        _isLoading = false;
        // ✅ PERFORMANCE FIX: Recalculate cache after data load
        _recalculateCache();
      });

      AppLogger.info(
        'FertilizerDbfImportScreen',
        'Parsed ${fertilizers.length} fertilizers, ${duplicates.length} duplicates',
      );
    } catch (e) {
      // ✅ ARCHITECTURE FIX: Log the error but rethrow it
      // This allows _loadData() to handle UI error state centrally
      AppLogger.error('FertilizerDbfImportScreen', 'Error parsing DBF', e);
      rethrow; // Critical: Let caller handle UI state
    }
  }

  /// ✅ PERFORMANCE FIX: Recalculate cached values when data or filter changes
  /// This should be called whenever _parsedFertilizers or _filterMode changes
  void _recalculateCache() {
    // Calculate filtered list
    final filtered = _parsedFertilizers.where((fertilizer) {
      if (_filterMode == 'substances') {
        return !FertilizerValidator.isLikelyRecipe(fertilizer);
      } else if (_filterMode == 'recipes') {
        return FertilizerValidator.isLikelyRecipe(fertilizer);
      }
      return true; // 'all'
    }).toList();

    // Sort: valid entries first (green), then invalid (red)
    filtered.sort((a, b) {
      final aInvalid = FertilizerValidator.isInvalid(a);
      final bInvalid = FertilizerValidator.isInvalid(b);
      if (aInvalid && !bInvalid) {
        return 1; // a is invalid, b is valid -> b comes first
      }
      if (!aInvalid && bInvalid) {
        return -1; // a is valid, b is invalid -> a comes first
      }
      return 0; // both same validity -> keep original order
    });

    // Calculate statistics
    final invalidCount = _parsedFertilizers
        .where((f) => FertilizerValidator.isInvalid(f))
        .length;
    final incompleteCount = _parsedFertilizers
        .where(
          (f) =>
              !FertilizerValidator.isInvalid(f) &&
              FertilizerValidator.isIncomplete(f),
        )
        .length;
    final validFertilizers = _parsedFertilizers.where(
      (f) =>
          !FertilizerValidator.isInvalid(f) &&
          !FertilizerValidator.isIncomplete(f),
    );
    final substanceCount = validFertilizers
        .where((f) => !FertilizerValidator.isLikelyRecipe(f))
        .length;
    final recipeCount = validFertilizers
        .where((f) => FertilizerValidator.isLikelyRecipe(f))
        .length;

    // Update cached values
    _cachedFilteredFertilizers = filtered;
    _cachedInvalidCount = invalidCount;
    _cachedIncompleteCount = incompleteCount;
    _cachedSubstanceCount = substanceCount;
    _cachedRecipeCount = recipeCount;
  }

  /// Returns cached filtered fertilizers (no computation in build)
  List<Fertilizer> _getFilteredFertilizers() {
    return _cachedFilteredFertilizers;
  }

  int _getSelectedCount() {
    return _selectedItems.length;
  }

  Future<void> _performImport({required bool skipDuplicates}) async {
    setState(() {
      _isImporting = true;
    });

    try {
      int imported = 0;
      int skipped = 0;

      for (final fertilizer in _parsedFertilizers) {
        // Skip if not selected
        if (!_selectedItems.contains(fertilizer.name)) {
          skipped++;
          continue;
        }

        // Check if duplicate
        if (skipDuplicates && _duplicateNames.contains(fertilizer.name)) {
          skipped++;
          continue;
        }

        // Save fertilizer
        await _fertilizerRepo.save(fertilizer);
        imported++;
      }

      if (mounted) {
        final skippedText = skipped > 0
            ? ' ($skipped ${_t['dbf_import_skipped']})'
            : '';
        AppMessages.showSuccess(
          context,
          '$imported ${_t['dbf_import_success']}$skippedText',
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to refresh fertilizer list
      }
    } catch (e) {
      AppLogger.error(
        'FertilizerDbfImportScreen',
        'Error importing fertilizers',
        e,
      );
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        AppMessages.showError(
          context,
          '${_t['dbf_import_error_importing']}: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_t['dbf_import_title'])),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(_t['dbf_import_title'])),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: DT.error),
                const SizedBox(height: 24),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(_t['dbf_import_go_back']),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PlantryScaffold(
      titleWidget: Row(
        children: [
          const Icon(Icons.upload_file, color: DT.secondary),
          const SizedBox(width: 8),
          Text(_t['dbf_import_title']),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          _buildSummaryCard(),

          // Fertilizer Preview List
          Expanded(child: _buildFertilizerList()),

          // Import Buttons
          _buildImportButtons(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    // ✅ PERFORMANCE FIX: Use cached statistics instead of recalculating
    final invalidCount = _cachedInvalidCount;
    final incompleteCount = _cachedIncompleteCount;
    final substanceCount = _cachedSubstanceCount;
    final recipeCount = _cachedRecipeCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DT.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: DT.secondary),
              const SizedBox(width: 8),
              Text(
                _t['dbf_import_summary'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DT.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            _t['dbf_import_file'],
            widget.dbfFile.path.split('/').last,
            DT.secondary,
          ),
          _buildSummaryRow(
            _t['dbf_import_total_items'],
            '${_parsedFertilizers.length}',
            DT.success,
          ),
          _buildSummaryRow(
            _t['dbf_import_substances_label'],
            '$substanceCount',
            DT.success,
          ),
          _buildSummaryRow(
            _t['dbf_import_recipes_label'],
            '$recipeCount',
            DT.info,
          ),
          if (_duplicateNames.isNotEmpty)
            _buildSummaryRow(
              _t['dbf_import_duplicates_label'],
              '${_duplicateNames.length}',
              DT.warning,
            ),
          if (invalidCount > 0)
            _buildSummaryRow(
              _t['dbf_import_invalid_label'],
              '$invalidCount',
              DT.error,
            ),
          if (incompleteCount > 0)
            _buildSummaryRow(
              _t['dbf_import_incomplete_label'],
              '$incompleteCount',
              DT.warning,
            ),
          const Divider(height: 24),
          _buildSummaryRow(
            _t['dbf_import_selected_label'],
            '${_getSelectedCount()}',
            DT.secondary,
          ),
          const SizedBox(height: 12),
          // Filter Buttons
          Row(
            children: [
              Expanded(
                child: _buildFilterButton(
                  _t['dbf_import_filter_all'],
                  'all',
                  Icons.list,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  _t['dbf_import_filter_substances'],
                  'substances',
                  Icons.science,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton(
                  _t['dbf_import_filter_recipes'],
                  'recipes',
                  Icons.auto_awesome,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Select/Deselect Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      // Only select visible/filtered items (skip duplicates, invalid, and incomplete entries)
                      final filteredItems = _getFilteredFertilizers();
                      for (final fertilizer in filteredItems) {
                        if (!_duplicateNames.contains(fertilizer.name) &&
                            !FertilizerValidator.isInvalid(fertilizer) &&
                            !FertilizerValidator.isIncomplete(fertilizer)) {
                          _selectedItems.add(fertilizer.name);
                        }
                      }
                    });
                  },
                  icon: const Icon(Icons.check_box, size: 16),
                  label: Text(
                    _filterMode == 'all'
                        ? _t['dbf_import_select_all']
                        : _t['dbf_import_select_filtered'],
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      // Only deselect visible/filtered items
                      final filteredItems = _getFilteredFertilizers();
                      for (final fertilizer in filteredItems) {
                        _selectedItems.remove(fertilizer.name);
                      }
                    });
                  },
                  icon: const Icon(Icons.check_box_outline_blank, size: 16),
                  label: Text(
                    _filterMode == 'all'
                        ? _t['dbf_import_deselect_all']
                        : _t['dbf_import_deselect_filtered'],
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String mode, IconData icon) {
    final isSelected = _filterMode == mode;
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _filterMode = mode;
          // ✅ PERFORMANCE FIX: Recalculate cache when filter changes
          _recalculateCache();
        });
      },
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12),
      ), // label comes from _t[...]
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? DT.secondary : DT.elevated,
        foregroundColor: isSelected ? DT.textPrimary : DT.textSecondary,
        padding: const EdgeInsets.symmetric(vertical: 8),
        elevation: isSelected ? 4 : 0,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFertilizerList() {
    if (_parsedFertilizers.isEmpty) {
      return Center(child: Text(_t['dbf_import_no_fertilizers']));
    }

    final filteredFertilizers = _getFilteredFertilizers();

    if (filteredFertilizers.isEmpty) {
      return Center(child: Text(_t['dbf_import_no_items_filter']));
    }

    // Separate valid and invalid entries
    final validEntries = filteredFertilizers
        .where((f) => !FertilizerValidator.isInvalid(f))
        .toList();
    final invalidEntries = filteredFertilizers
        .where((f) => FertilizerValidator.isInvalid(f))
        .toList();

    // Build display list: valid entries + limited invalid entries
    final displayList = <Fertilizer>[];
    displayList.addAll(validEntries);

    final invalidToShow = _showAllInvalid
        ? invalidEntries
        : invalidEntries.take(2).toList();
    displayList.addAll(invalidToShow);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount:
          displayList.length +
          (invalidEntries.length > 2 && !_showAllInvalid
              ? 1
              : 0), // +1 for expand button
      itemBuilder: (context, displayIndex) {
        // Check if this is the expand button position
        if (displayIndex == displayList.length &&
            invalidEntries.length > 2 &&
            !_showAllInvalid) {
          return _buildExpandInvalidButton(invalidEntries.length - 2);
        }

        final fertilizer = displayList[displayIndex];
        final isDuplicate = _duplicateNames.contains(fertilizer.name);
        final isInvalid = FertilizerValidator.isInvalid(fertilizer);
        final isIncomplete =
            !isInvalid && FertilizerValidator.isIncomplete(fertilizer);
        final isRecipe = FertilizerValidator.isLikelyRecipe(fertilizer);
        final isSelected = _selectedItems.contains(fertilizer.name);

        AppLogger.debug(
          'FertilizerDbfImport',
          'Item: ${fertilizer.name.length > 20 ? '${fertilizer.name.substring(0, 20)}...' : fertilizer.name} displayIdx=$displayIndex selected=$isSelected invalid=$isInvalid incomplete=$isIncomplete',
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isInvalid
              ? DT.error.withValues(alpha: 0.12)
              : (isIncomplete
                    ? DT.warning.withValues(alpha: 0.12)
                    : (isDuplicate
                          ? DT.warning.withValues(alpha: 0.08)
                          : DT.success.withValues(alpha: 0.08))),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isInvalid
                  ? DT.error.withValues(alpha: 0.5)
                  : (isIncomplete
                        ? DT.warning.withValues(alpha: 0.5)
                        : (isDuplicate
                              ? DT.warning.withValues(alpha: 0.4)
                              : DT.success.withValues(alpha: 0.3))),
              width: 1.5,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (isDuplicate || isInvalid)
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          _selectedItems.add(fertilizer.name);
                        } else {
                          _selectedItems.remove(fertilizer.name);
                        }
                      });
                    },
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    fertilizer.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isInvalid
                          ? DT.error
                          : (isDuplicate ? DT.warning : DT.textPrimary),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isInvalid)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DT.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _t['dbf_badge_invalid'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: DT.error,
                      ),
                    ),
                  ),
                if (!isInvalid && isIncomplete)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DT.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _t['dbf_badge_incomplete'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: DT.warning,
                      ),
                    ),
                  ),
                if (!isInvalid && !isIncomplete && isRecipe)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: DT.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _t['dbf_badge_recipe'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: DT.info,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fertilizer.formula != null)
                  Text(
                    fertilizer.formula!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DT.textSecondary,
                    ),
                  ),
                if (fertilizer.npk != null)
                  Text(
                    'NPK: ${fertilizer.npk}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: DT.success,
                    ),
                  ),
                if (isInvalid)
                  Text(
                    _t['dbf_import_invalid_entry'],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DT.error,
                    ),
                  ),
                if (!isInvalid && isIncomplete)
                  Text(
                    _t['dbf_import_missing_nutrients'],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DT.warning,
                    ),
                  ),
                if (!isInvalid && !isIncomplete && isDuplicate)
                  Text(
                    _t['dbf_import_already_exists'],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DT.warning,
                    ),
                  ),
              ],
            ),
            trailing: Icon(
              isInvalid
                  ? Icons.error
                  : (isIncomplete
                        ? Icons.warning
                        : (isDuplicate
                              ? Icons.warning_amber
                              : (isRecipe
                                    ? Icons.auto_awesome
                                    : Icons.science))),
              color: isInvalid
                  ? DT.error
                  : (isIncomplete
                        ? DT.warning
                        : (isDuplicate
                              ? DT.warning
                              : (isRecipe ? DT.info : DT.success))),
            ),
            onTap: (isDuplicate || isInvalid)
                ? null
                : () {
                    AppLogger.debug(
                      'FertilizerDbfImport',
                      'Tapped: ${fertilizer.name} (was=$isSelected, now=${!isSelected})',
                    );
                    setState(() {
                      if (isSelected) {
                        _selectedItems.remove(fertilizer.name);
                      } else {
                        _selectedItems.add(fertilizer.name);
                      }
                    });
                  },
          ),
        );
      },
    );
  }

  Widget _buildExpandInvalidButton(int hiddenCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _showAllInvalid = !_showAllInvalid;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DT.elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: DT.error.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showAllInvalid ? Icons.expand_less : Icons.expand_more,
                  color: DT.error,
                ),
                const SizedBox(width: 8),
                Text(
                  _showAllInvalid
                      ? _t['dbf_import_hide_invalid']
                      : '$hiddenCount ${_t['dbf_import_show_more_invalid']}',
                  style: const TextStyle(
                    color: DT.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImportButtons() {
    return Container(
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
      child: Column(
        children: [
          if (_duplicateNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: DT.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_duplicateNames.length} ${_t['dbf_import_duplicates_will_skip']}',
                      style: const TextStyle(fontSize: 12, color: DT.warning),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isImporting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.cancel),
                  label: Text(_t['cancel']),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isImporting
                      ? null
                      : () => _performImport(skipDuplicates: true),
                  icon: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: DT.textPrimary,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                    _isImporting
                        ? _t['dbf_importing']
                        : '${_t['dbf_import_title']} (${_getSelectedCount()})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.secondary,
                    foregroundColor: DT.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
