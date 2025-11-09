// =============================================
// GROWLOG - Fertilizer List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/fertilizer.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';
import 'add_fertilizer_screen.dart';
import 'edit_fertilizer_screen.dart';
import 'fertilizer_dbf_import_screen.dart';
import '../di/service_locator.dart';

class FertilizerListScreen extends StatefulWidget {
  const FertilizerListScreen({super.key});

  @override
  State<FertilizerListScreen> createState() => _FertilizerListScreenState();
}

class _FertilizerListScreenState extends State<FertilizerListScreen> {
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  
  List<Fertilizer> _fertilizers = [];
  bool _isLoading = true;
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadFertilizers();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadFertilizers() async {
    setState(() => _isLoading = true);

    try {
      final fertilizers = await _fertilizerRepo.findAll();
      setState(() {
        _fertilizers = fertilizers;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('FertilizerListScreen', 'Error loading: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFertilizer(Fertilizer fertilizer) async {
    // 1. Prüfe zuerst ob Dünger in Verwendung ist
    final isInUse = await _fertilizerRepo.isInUse(fertilizer.id!);

    if (isInUse) {
      // Zeige benutzerfreundliche Warnung
      final usage = await _fertilizerRepo.getUsageDetails(fertilizer.id!);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 12),
              Expanded(child: Text(_t['cannot_delete'])),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t['fertilizer_in_use_message'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (usage['recipes']! > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.restaurant, size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text('${usage['recipes']} ${_t['recipes']}'),
                    ],
                  ),
                ),
              if (usage['rdwc_logs']! > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.water_drop, size: 20, color: Colors.cyan[700]),
                      const SizedBox(width: 8),
                      Text('${usage['rdwc_logs']} RDWC Logs'),
                    ],
                  ),
                ),
              if (usage['plant_logs']! > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.eco, size: 20, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text('${usage['plant_logs']} ${_t['plant_logs']}'),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _t['fertilizer_remove_first'],
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t['ok']),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Dünger ist NICHT in Verwendung - zeige normale Lösch-Bestätigung
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['delete_fertilizer_title']),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${fertilizer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t['delete']),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _fertilizerRepo.delete(fertilizer.id!);
        _loadFertilizers();
        if (mounted) {
          AppMessages.deletedSuccessfully(context, _t['fertilizers']);
        }
      } catch (e) {
        // Sollte nicht passieren, da wir vorher geprüft haben
        AppLogger.error('FertilizerListScreen', 'Unexpected delete error: $e');
        if (mounted) {
          AppMessages.deletingError(context, _t['unexpected_error']);
        }
      }
    }
  }

  Future<void> _pickAndImportDbf() async {
    try {
      // Show instructions dialog first
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 12),
              const Text('HydroBuddy Import'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select the HydroBuddy database file:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('File name: substances_win.dbf'),
              SizedBox(height: 8),
              Text('Default location: HydroBuddy installation folder'),
              SizedBox(height: 12),
              Text(
                'Note: The file picker may show all files. Make sure to select the .dbf file!',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Select File'),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      // Pick file (Android can't filter .dbf, so we show all files)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Changed from custom to any, since Android doesn't support .dbf filtering
        dialogTitle: 'Select substances_win.dbf',
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (mounted) {
          AppMessages.showError(context, 'Could not access file');
        }
        return;
      }

      // Validate file extension
      if (!filePath.toLowerCase().endsWith('.dbf')) {
        if (mounted) {
          AppMessages.showError(
            context,
            'Invalid file: Please select a .dbf file (e.g., substances_win.dbf)',
          );
        }
        return;
      }

      final file = File(filePath);

      // Validate file exists and is readable
      if (!await file.exists()) {
        if (mounted) {
          AppMessages.showError(context, 'File does not exist');
        }
        return;
      }

      // Navigate to import screen
      if (mounted) {
        final importResult = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FertilizerDbfImportScreen(dbfFile: file),
          ),
        );

        if (importResult == true) {
          _loadFertilizers(); // Refresh list
        }
      }
    } catch (e) {
      AppLogger.error('FertilizerListScreen', 'Error picking DBF file', e);
      if (mounted) {
        AppMessages.showError(context, 'Error selecting file: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteAllFertilizers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
            const SizedBox(width: 12),
            const Text('Delete All Fertilizers?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will delete ALL ${_fertilizers.length} fertilizers!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('This action cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final count = await _fertilizerRepo.deleteAll();
        _loadFertilizers();
        if (mounted) {
          AppMessages.showSuccess(context, 'Deleted $count fertilizers');
        }
      } catch (e) {
        AppLogger.error('FertilizerListScreen', 'Error deleting all: $e');
        if (mounted) {
          AppMessages.showError(context, 'Error deleting fertilizers');
        }
      }
    }
  }

  Future<void> _deleteImportedFertilizers() async {
    // Count imported fertilizers
    final importedCount = _fertilizers.where((f) => f.brand == 'HydroBuddy').length;

    if (importedCount == 0) {
      if (mounted) {
        AppMessages.showInfo(context, 'No imported HydroBuddy fertilizers found');
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.undo, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Undo Import?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete all $importedCount imported HydroBuddy fertilizers?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('This will remove all fertilizers with brand "HydroBuddy".'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Undo Import'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final count = await _fertilizerRepo.deleteByBrand('HydroBuddy');
        _loadFertilizers();
        if (mounted) {
          AppMessages.showSuccess(context, 'Deleted $count imported fertilizers');
        }
      } catch (e) {
        AppLogger.error('FertilizerListScreen', 'Error deleting imported: $e');
        if (mounted) {
          AppMessages.showError(context, 'Error deleting fertilizers');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['fertilizers']),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _pickAndImportDbf,
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import from DBF',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all') {
                _deleteAllFertilizers();
              } else if (value == 'delete_imported') {
                _deleteImportedFertilizers();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete_imported',
                child: Row(
                  children: [
                    Icon(Icons.undo, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 12),
                    const Text('Undo Import (HydroBuddy)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    const Text('Delete All Fertilizers', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fertilizers.isEmpty
              ? _buildEmptyState()
              : _buildFertilizerList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddFertilizerScreen(),
            ),
          );
          if (result == true) _loadFertilizers();
        },
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add),
        label: Text(_t['fertilizers']),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.science,
            size: AppConstants.emptyStateIconSize,
            color: Colors.grey[400],
          ),
          const SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _t['no_fertilizers'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppConstants.emptyStateSpacingMiddle),
          Text(
            _t['add_first_fertilizer'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeMedium,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFertilizerList() {
    return ListView.builder(
      itemCount: _fertilizers.length,
      padding: AppConstants.listPadding,
      itemBuilder: (context, index) {
        final fertilizer = _fertilizers[index];
        return _buildFertilizerCard(fertilizer);
      },
    );
  }

  Widget _buildFertilizerCard(Fertilizer fertilizer) {
    // ✅ PERFORMANCE: RepaintBoundary isoliert jede Card für flüssigeres Scrolling
    return RepaintBoundary(
      child: Card(
        key: ValueKey(fertilizer.id), // ✅ PERFORMANCE: Key for efficient updates
        margin: AppConstants.cardMarginVertical,
        child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(fertilizer.type),
          child: const Icon(
            Icons.science,
            color: Colors.white,
            size: AppConstants.iconSizeLarge,
          ),
        ),
        title: Text(
          fertilizer.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConstants.fontSizeBody,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fertilizer.brand != null) ...[
              const SizedBox(height: AppConstants.spacingXs),
              Text(
                fertilizer.brand!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            if (fertilizer.npk != null) ...[
              const SizedBox(height: AppConstants.spacingXs),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.chipPaddingHorizontal,
                      vertical: AppConstants.chipPaddingVertical,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
                    ),
                    child: Text(
                      'NPK: ${fertilizer.npk}',
                      style: TextStyle(
                        fontSize: AppConstants.badgeFontSizeMedium,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (fertilizer.type != null) ...[
                    const SizedBox(width: AppConstants.spacingSmall),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.chipPaddingHorizontal,
                        vertical: AppConstants.chipPaddingVertical,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(fertilizer.type)?.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
                      ),
                      child: Text(
                        fertilizer.type!,
                        style: TextStyle(
                          fontSize: AppConstants.badgeFontSizeMedium,
                          color: _getTypeColor(fertilizer.type),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: AppConstants.popupMenuIconSize),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['edit']),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(
                    Icons.delete, 
                    color: Colors.red, 
                    size: AppConstants.popupMenuIconSize
                  ),
                  const SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['delete'], style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditFertilizerScreen(
                    fertilizer: fertilizer,
                  ),
                ),
              );
              if (result == true) _loadFertilizers();
            } else if (value == 'delete') {
              _deleteFertilizer(fertilizer);
            }
          },
        ),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditFertilizerScreen(
                fertilizer: fertilizer,
              ),
            ),
          );
          if (result == true) _loadFertilizers();
        },
      ),
      ),
    );
  }

  Color? _getTypeColor(String? type) {
    if (type == null) return Colors.grey[600];
    
    final typeUpper = type.toUpperCase();
    if (typeUpper.contains('BLOOM') || typeUpper.contains('BLÜTE')) {
      return Colors.purple[600];
    } else if (typeUpper.contains('VEG') || typeUpper.contains('WUCHS')) {
      return Colors.green[600];
    } else if (typeUpper.contains('ROOT') || typeUpper.contains('WURZEL')) {
      return Colors.brown[600];
    } else if (typeUpper.contains('ADDITIVE') || typeUpper.contains('ZUSATZ')) {
      return Colors.blue[600];
    }
    return Colors.grey[600];
  }
}
