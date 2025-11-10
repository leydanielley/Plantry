// =============================================
// GROWLOG - Fertilizer DBF Import Screen
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../models/fertilizer.dart';
import '../services/dbf_import_service.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../di/service_locator.dart';

class FertilizerDbfImportScreen extends StatefulWidget {
  final File dbfFile;

  const FertilizerDbfImportScreen({
    super.key,
    required this.dbfFile,
  });

  @override
  State<FertilizerDbfImportScreen> createState() => _FertilizerDbfImportScreenState();
}

class _FertilizerDbfImportScreenState extends State<FertilizerDbfImportScreen> {
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late AppTranslations _t;
  bool _isLoading = true;
  bool _isImporting = false;
  List<Fertilizer> _parsedFertilizers = [];
  List<String> _duplicateNames = [];
  Set<String> _selectedItems = {}; // Track selected items by name (unique key)
  String _filterMode = 'all'; // 'all', 'substances', 'recipes'
  bool _showAllInvalid = false; // Show all invalid entries or just first 2
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      setState(() {
        _t = AppTranslations(settings.language);
      });

      await _parseDbfFile();
    } catch (e) {
      AppLogger.error('FertilizerDbfImportScreen', 'Error loading data', e);
      setState(() {
        _errorMessage = 'Error loading file';
        _isLoading = false;
      });
    }
  }

  Future<void> _parseDbfFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      AppLogger.info('FertilizerDbfImportScreen', 'Parsing DBF file: ${widget.dbfFile.path}');

      // Parse DBF file
      final fertilizers = await DbfImportService.importFromDbf(widget.dbfFile);

      // Check for duplicates
      final existingFertilizers = await _fertilizerRepo.findAll();
      final existingNames = existingFertilizers.map((f) => f.name.toLowerCase()).toSet();
      final duplicates = fertilizers
          .where((f) => existingNames.contains(f.name.toLowerCase()))
          .map((f) => f.name)
          .toList();

      // Initialize all items as selected (except duplicates, invalid, and incomplete entries)
      final selectedItems = <String>{};
      for (final fertilizer in fertilizers) {
        if (!duplicates.contains(fertilizer.name) &&
            !_isInvalidEntry(fertilizer) &&
            !_isIncompleteData(fertilizer)) {
          selectedItems.add(fertilizer.name);
        }
      }

      setState(() {
        _parsedFertilizers = fertilizers;
        _duplicateNames = duplicates;
        _selectedItems = selectedItems;
        _isLoading = false;
      });

      AppLogger.info(
        'FertilizerDbfImportScreen',
        'Parsed ${fertilizers.length} fertilizers, ${duplicates.length} duplicates',
      );
    } catch (e) {
      AppLogger.error('FertilizerDbfImportScreen', 'Error parsing DBF', e);
      setState(() {
        _errorMessage = 'Error parsing DBF file: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Check if fertilizer has incomplete nutrient data
  ///
  /// Incomplete = only NPK without detailed micro/macro nutrients
  /// These won't work well in the Top-up Calculator
  bool _isIncompleteData(Fertilizer fertilizer) {
    // Count how many nutrient values are available
    int nutrientCount = 0;
    if (fertilizer.nNO3 != null && fertilizer.nNO3! > 0) nutrientCount++;
    if (fertilizer.nNH4 != null && fertilizer.nNH4! > 0) nutrientCount++;
    if (fertilizer.p != null && fertilizer.p! > 0) nutrientCount++;
    if (fertilizer.k != null && fertilizer.k! > 0) nutrientCount++;
    if (fertilizer.mg != null && fertilizer.mg! > 0) nutrientCount++;
    if (fertilizer.ca != null && fertilizer.ca! > 0) nutrientCount++;
    if (fertilizer.s != null && fertilizer.s! > 0) nutrientCount++;
    if (fertilizer.fe != null && fertilizer.fe! > 0) nutrientCount++;
    if (fertilizer.mn != null && fertilizer.mn! > 0) nutrientCount++;
    if (fertilizer.zn != null && fertilizer.zn! > 0) nutrientCount++;
    if (fertilizer.cu != null && fertilizer.cu! > 0) nutrientCount++;
    if (fertilizer.b != null && fertilizer.b! > 0) nutrientCount++;

    // If less than 3 nutrients, it's too incomplete
    // (commercial products often only have NPK = 3 values)
    return nutrientCount < 3;
  }

  /// Check if name contains URLs or links (invalid entries)
  bool _isInvalidEntry(Fertilizer fertilizer) {
    final name = fertilizer.name.trim();
    final nameLower = name.toLowerCase();

    // 1. Too short (likely corrupted)
    if (name.length < 3) {
      return true;
    }

    // 2. URLs and links
    if (nameLower.contains('http://') || nameLower.contains('https://')) {
      return true;
    }
    if (nameLower.contains('www.')) {
      return true;
    }
    if (nameLower.contains('amazon.') || nameLower.contains('amzn.to')) {
      return true;
    }
    if (nameLower.contains('.com') || nameLower.contains('.de') || nameLower.contains('.co.uk') || nameLower.contains('.to/')) {
      return true;
    }
    if (nameLower.startsWith('http') || nameLower.startsWith('www')) {
      return true;
    }

    // 3. Only numbers, dots, and zeros (e.g. "0.00000000", "1.00000000", "000")
    final cleanName = name.replaceAll(RegExp(r'[0-9\.\s]'), '');
    if (cleanName.isEmpty) {
      return true;
    }

    // 4. Starts with number or special char (likely corrupted, e.g. "7.93223900A", ".to/365sSi6")
    if (!RegExp(r'^[A-Za-z]').hasMatch(name)) {
      return true;
    }

    // 5. Looks like truncated/corrupted text (ends with incomplete word)
    // Examples: "ate)", "c Acid", "alcium Nitrate"
    if (name.length < 10 && (name.endsWith(')') || name.startsWith('c ') || !name.contains(' '))) {
      // Very short names that look incomplete
      final hasVowel = RegExp(r'[aeiouAEIOU]').hasMatch(name);
      if (!hasVowel) {
        return true; // No vowels = likely abbreviation or corrupted
      }
    }

    // 6. Mostly numbers with few letters (e.g. "44.08146528B", "55.09356426B")
    final digitCount = name.replaceAll(RegExp(r'[^0-9]'), '').length;
    final letterCount = name.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
    if (digitCount > letterCount * 3) {
      return true; // More than 3x digits vs letters = likely code/corrupted
    }

    return false;
  }

  bool _isLikelyRecipe(Fertilizer fertilizer) {
    final name = fertilizer.name.toLowerCase();

    // Recipe indicators
    final recipeKeywords = [
      'recipe', 'series', 'program', 'schedule', 'kit', 'system',
      'complete', 'starter', 'finisher', 'expert', 'professional',
      'flora', 'micro', 'bloom', 'grow', 'trio', 'duo',
    ];

    // Brand names that typically indicate pre-made formulas
    final brandKeywords = [
      'gh ', 'general hydro', 'advanced nutrients', 'canna',
      'plagron', 'biobizz', 'house & garden', 'dutch pro',
      'petery', 'flora series', 'lucas formula',
    ];

    // Check for recipe keywords
    if (recipeKeywords.any((keyword) => name.contains(keyword))) {
      return true;
    }

    // Check for brand keywords
    if (brandKeywords.any((keyword) => name.contains(keyword))) {
      return true;
    }

    // Very long names are usually recipes (but not URLs)
    if (name.length > 40 && !_isInvalidEntry(fertilizer)) {
      return true;
    }

    // Names with 4+ words are usually recipes
    if (name.split(' ').length >= 4) {
      return true;
    }

    return false;
  }

  List<Fertilizer> _getFilteredFertilizers() {
    var filtered = _parsedFertilizers.where((fertilizer) {
      if (_filterMode == 'substances') {
        return !_isLikelyRecipe(fertilizer);
      } else if (_filterMode == 'recipes') {
        return _isLikelyRecipe(fertilizer);
      }
      return true; // 'all'
    }).toList();

    // Sort: valid entries first (green), then invalid (red)
    filtered.sort((a, b) {
      final aInvalid = _isInvalidEntry(a);
      final bInvalid = _isInvalidEntry(b);
      if (aInvalid && !bInvalid) return 1; // a is invalid, b is valid -> b comes first
      if (!aInvalid && bInvalid) return -1; // a is valid, b is invalid -> a comes first
      return 0; // both same validity -> keep original order
    });

    return filtered;
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
        AppMessages.showSuccess(
          context,
          'Imported $imported fertilizers${skipped > 0 ? ' ($skipped skipped)' : ''}',
        );
        Navigator.of(context).pop(true); // Return true to refresh fertilizer list
      }
    } catch (e) {
      AppLogger.error('FertilizerDbfImportScreen', 'Error importing fertilizers', e);
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        AppMessages.showError(context, 'Error importing: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Import Fertilizers'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Import Fertilizers'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
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
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.upload_file, color: Colors.blue[300]),
            const SizedBox(width: 8),
            const Text('Import Fertilizers'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Card
          _buildSummaryCard(isDark),

          // Fertilizer Preview List
          Expanded(
            child: _buildFertilizerList(isDark),
          ),

          // Import Buttons
          _buildImportButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    final invalidCount = _parsedFertilizers.where((f) => _isInvalidEntry(f)).length;
    final incompleteCount = _parsedFertilizers.where((f) => !_isInvalidEntry(f) && _isIncompleteData(f)).length;
    final validFertilizers = _parsedFertilizers.where((f) => !_isInvalidEntry(f) && !_isIncompleteData(f));
    final substanceCount = validFertilizers.where((f) => !_isLikelyRecipe(f)).length;
    final recipeCount = validFertilizers.where((f) => _isLikelyRecipe(f)).length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300] ?? Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Import Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            'File',
            widget.dbfFile.path.split('/').last,
            Colors.blue[700] ?? Colors.blue,
          ),
          _buildSummaryRow(
            'Total Items',
            '${_parsedFertilizers.length}',
            Colors.green[700] ?? Colors.green,
          ),
          _buildSummaryRow(
            '  • Substances',
            '$substanceCount',
            Colors.green[600] ?? Colors.green,
          ),
          _buildSummaryRow(
            '  • Recipes/Formulas',
            '$recipeCount',
            Colors.purple[600] ?? Colors.purple,
          ),
          if (_duplicateNames.isNotEmpty)
            _buildSummaryRow(
              'Duplicates',
              '${_duplicateNames.length}',
              Colors.orange[700] ?? Colors.orange,
            ),
          if (invalidCount > 0)
            _buildSummaryRow(
              'Invalid (URLs/Links)',
              '$invalidCount',
              Colors.red[700] ?? Colors.red,
            ),
          if (incompleteCount > 0)
            _buildSummaryRow(
              'Incomplete Data',
              '$incompleteCount',
              Colors.orange[600] ?? Colors.orange,
            ),
          const Divider(height: 24),
          _buildSummaryRow(
            'Selected to Import',
            '${_getSelectedCount()}',
            Colors.blue[700] ?? Colors.blue,
          ),
          const SizedBox(height: 12),
          // Filter Buttons
          Row(
            children: [
              Expanded(
                child: _buildFilterButton('All', 'all', Icons.list),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton('Substances', 'substances', Icons.science),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFilterButton('Recipes', 'recipes', Icons.auto_awesome),
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
                            !_isInvalidEntry(fertilizer) &&
                            !_isIncompleteData(fertilizer)) {
                          _selectedItems.add(fertilizer.name);
                        }
                      }
                    });
                  },
                  icon: const Icon(Icons.check_box, size: 16),
                  label: Text(
                    _filterMode == 'all' ? 'Select All' : 'Select Filtered',
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
                    _filterMode == 'all' ? 'Deselect All' : 'Deselect Filtered',
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
        });
      },
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue[700] : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
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

  Widget _buildFertilizerList(bool isDark) {
    if (_parsedFertilizers.isEmpty) {
      return const Center(
        child: Text('No fertilizers found in file'),
      );
    }

    final filteredFertilizers = _getFilteredFertilizers();

    if (filteredFertilizers.isEmpty) {
      return Center(
        child: Text('No items in this filter'),
      );
    }

    // Separate valid and invalid entries
    final validEntries = filteredFertilizers.where((f) => !_isInvalidEntry(f)).toList();
    final invalidEntries = filteredFertilizers.where((f) => _isInvalidEntry(f)).toList();

    // Build display list: valid entries + limited invalid entries
    final displayList = <Fertilizer>[];
    displayList.addAll(validEntries);

    final invalidToShow = _showAllInvalid ? invalidEntries : invalidEntries.take(2).toList();
    displayList.addAll(invalidToShow);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: displayList.length + (invalidEntries.length > 2 && !_showAllInvalid ? 1 : 0), // +1 for expand button
      itemBuilder: (context, displayIndex) {
        // Check if this is the expand button position
        if (displayIndex == displayList.length && invalidEntries.length > 2 && !_showAllInvalid) {
          return _buildExpandInvalidButton(invalidEntries.length - 2, isDark);
        }

        final fertilizer = displayList[displayIndex];
        final isDuplicate = _duplicateNames.contains(fertilizer.name);
        final isInvalid = _isInvalidEntry(fertilizer);
        final isIncomplete = !isInvalid && _isIncompleteData(fertilizer);
        final isRecipe = _isLikelyRecipe(fertilizer);
        final isSelected = _selectedItems.contains(fertilizer.name);

        AppLogger.debug(
          'FertilizerDbfImport',
          'Item: ${fertilizer.name.length > 20 ? fertilizer.name.substring(0, 20) + '...' : fertilizer.name} displayIdx=$displayIndex selected=$isSelected invalid=$isInvalid incomplete=$isIncomplete',
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isInvalid
              ? (isDark ? Colors.red[900] : Colors.red[50])
              : (isIncomplete
                  ? (isDark ? Colors.orange[900] : Colors.orange[50])
                  : (isDuplicate
                      ? (isDark ? Colors.yellow[900] : Colors.yellow[50])
                      : (isDark ? Colors.green[900]?.withValues(alpha: 0.2) : Colors.green[50]))),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isInvalid
                  ? Colors.red[300] ?? Colors.red
                  : (isIncomplete
                      ? Colors.orange[300] ?? Colors.orange
                      : (isDuplicate ? Colors.yellow[700] ?? Colors.yellow : Colors.green[300] ?? Colors.green)),
              width: 1.5,
            ),
          ),
          child: ListTile(
            leading: Checkbox(
              value: isSelected,
              onChanged: (isDuplicate || isInvalid) ? null : (value) {
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
                          ? Colors.red[900]
                          : (isDuplicate ? Colors.orange[900] : null),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isInvalid)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'INVALID',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ),
                if (!isInvalid && isIncomplete)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'INCOMPLETE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                if (!isInvalid && !isIncomplete && isRecipe)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RECIPE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
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
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                if (fertilizer.npk != null)
                  Text(
                    'NPK: ${fertilizer.npk}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[700],
                    ),
                  ),
                if (isInvalid)
                  Text(
                    'Invalid entry (URL/Link)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                if (!isInvalid && isIncomplete)
                  Text(
                    'Missing nutrient data - not usable in calculator',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                if (!isInvalid && !isIncomplete && isDuplicate)
                  Text(
                    'Already exists',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
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
                          : (isRecipe ? Icons.auto_awesome : Icons.science))),
              color: isInvalid
                  ? Colors.red[700]
                  : (isIncomplete
                      ? Colors.orange[700]
                      : (isDuplicate
                          ? Colors.orange[700]
                          : (isRecipe ? Colors.purple[700] : Colors.green[700]))),
            ),
            onTap: (isDuplicate || isInvalid) ? null : () {
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

  Widget _buildExpandInvalidButton(int hiddenCount, bool isDark) {
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
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red[300] ?? Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showAllInvalid ? Icons.expand_less : Icons.expand_more,
                  color: Colors.red[700],
                ),
                const SizedBox(width: 8),
                Text(
                  _showAllInvalid
                      ? 'Hide invalid entries'
                      : 'Show $hiddenCount more invalid entries',
                  style: TextStyle(
                    color: Colors.red[700],
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

  Widget _buildImportButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[50],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_duplicateNames.length} duplicate(s) will be skipped',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
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
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_isImporting ? 'Importing...' : 'Import (${_getSelectedCount()})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
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
