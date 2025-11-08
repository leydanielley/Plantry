// =============================================
// GROWLOG - Fertilizer List Screen
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/fertilizer.dart';
import '../repositories/fertilizer_repository.dart';
import '../repositories/settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';
import 'add_fertilizer_screen.dart';
import 'edit_fertilizer_screen.dart';

class FertilizerListScreen extends StatefulWidget {
  const FertilizerListScreen({super.key});

  @override
  State<FertilizerListScreen> createState() => _FertilizerListScreenState();
}

class _FertilizerListScreenState extends State<FertilizerListScreen> {
  final FertilizerRepository _fertilizerRepo = FertilizerRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['fertilizers']),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
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
          SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _t['no_fertilizers'],
            style: TextStyle(
              fontSize: AppConstants.fontSizeLarge,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: AppConstants.emptyStateSpacingMiddle),
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
    return Card(
      key: ValueKey(fertilizer.id), // ✅ PERFORMANCE: Key for efficient updates
      margin: AppConstants.cardMarginVertical,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(fertilizer.type),
          child: Icon(
            Icons.science,
            color: Colors.white,
            size: AppConstants.iconSizeLarge,
          ),
        ),
        title: Text(
          fertilizer.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConstants.fontSizeBody,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (fertilizer.brand != null) ...[
              SizedBox(height: AppConstants.spacingXs),
              Text(
                fertilizer.brand!,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            if (fertilizer.npk != null) ...[
              SizedBox(height: AppConstants.spacingXs),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
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
                    SizedBox(width: AppConstants.spacingSmall),
                    Container(
                      padding: EdgeInsets.symmetric(
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
                  Icon(Icons.edit, size: AppConstants.popupMenuIconSize),
                  SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['edit']),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete, 
                    color: Colors.red, 
                    size: AppConstants.popupMenuIconSize
                  ),
                  SizedBox(width: AppConstants.spacingSmall),
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
