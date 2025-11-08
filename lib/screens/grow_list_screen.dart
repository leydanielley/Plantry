// =============================================
// GROWLOG - Grow List Screen (✅ FIX: N+1 Query Problem gelöst!)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/grow.dart';
import '../repositories/grow_repository.dart';
import '../repositories/settings_repository.dart';
import '../utils/translations.dart';
import '../utils/app_constants.dart';
import 'add_grow_screen.dart';
import 'edit_grow_screen.dart';
import 'grow_detail_screen.dart';
import '../utils/app_messages.dart';

class GrowListScreen extends StatefulWidget {
  const GrowListScreen({super.key});

  @override
  State<GrowListScreen> createState() => _GrowListScreenState();
}

class _GrowListScreenState extends State<GrowListScreen> {
  final GrowRepository _growRepo = GrowRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  List<Grow> _grows = [];
  Map<int, int> _plantCounts = {};
  bool _isLoading = true;
  bool _showArchived = false;
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadGrows();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadGrows() async {
    setState(() => _isLoading = true);

    try {
      final grows = await _growRepo.getAll(includeArchived: _showArchived);
      final growIds = grows.where((g) => g.id != null).map((g) => g.id!).toList();
      final counts = await _growRepo.getPlantCountsForGrows(growIds);

      setState(() {
        _grows = grows;
        _plantCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('GrowListScreen', 'Error loading grows: $e');
      setState(() => _isLoading = false);

      if (mounted) {
        AppMessages.loadingError(context, 'Grows', onRetry: _loadGrows);
      }
    }
  }

  Future<void> _editGrow(Grow grow) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditGrowScreen(grow: grow),
      ),
    );
    if (result == true) _loadGrows();
  }

  Future<void> _deleteGrow(Grow grow) async {
    final plantCount = await _growRepo.getPlantCount(grow.id!);

    if (!mounted) return;

    if (plantCount > 0) {
      final confirmDetach = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_t['attention']),
          content: Text(
            _t['delete_grow_with_plants'].replaceAll('{count}', plantCount.toString()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_t['cancel']),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: Text(_t['yes_delete']),
            ),
          ],
        ),
      );

      if (confirmDetach != true) return;
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['delete_grow_title']),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${grow.name}"?'),
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
        await _growRepo.delete(grow.id!);
        _loadGrows();
        if (mounted) {
          AppMessages.deletedSuccessfully(context, 'Grow');
        }
      } catch (e) {
        AppLogger.error('GrowListScreen', 'Error deleting: $e');
        if (mounted) {
          AppMessages.deletingError(context, e.toString());
        }
      }
    }
  }

  Future<void> _toggleArchive(Grow grow) async {
    try {
      if (grow.archived) {
        await _growRepo.unarchive(grow.id!);
        if (mounted) {
          AppMessages.restoredSuccessfully(context, 'Grow');
        }
      } else {
        await _growRepo.archive(grow.id!);
        if (mounted) {
          AppMessages.archivedSuccessfully(context, 'Grow');
        }
      }
      _loadGrows();
    } catch (e) {
      AppLogger.error('GrowListScreen', 'Error archiving: $e');
      if (mounted) {
        AppMessages.showError(context, '${_t['error']}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['grows']),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
            tooltip: _showArchived ? _t['hide_archived'] : _t['show_archived'],
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
              _loadGrows();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _grows.isEmpty
          ? _buildEmptyState()
          : _buildGrowList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddGrowScreen()),
          );
          if (result == true) _loadGrows();
        },
        backgroundColor: Colors.green[700],
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.eco,
            size: AppConstants.emptyStateIconSize,
            color: Colors.grey[400],
          ),
          SizedBox(height: AppConstants.emptyStateSpacingTop),
          Text(
            _showArchived ? _t['no_archived_grows'] : _t['no_grows'],
            style: TextStyle(
              fontSize: AppConstants.emptyStateTitleFontSize,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: AppConstants.emptyStateSpacingMiddle),
          Text(
            _showArchived ? _t['archive_grow_to_see'] : _t['create_first_grow'],
            style: TextStyle(
              fontSize: AppConstants.emptyStateSubtitleFontSize,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowList() {
    return RefreshIndicator(
      onRefresh: _loadGrows,
      child: ListView.builder(
        itemCount: _grows.length,
        padding: AppConstants.listPadding,
        itemBuilder: (context, index) {
          final grow = _grows[index];
          return _buildGrowCard(grow);
        },
      ),
    );
  }

  Widget _buildGrowCard(Grow grow) {
    final plantCount = _plantCounts[grow.id] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      key: ValueKey(grow.id), // ✅ PERFORMANCE: Key for efficient updates
      margin: AppConstants.cardMarginVertical,
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: grow.archived 
              ? (isDark ? Colors.grey[700] : Colors.grey[400])
              : Colors.green[700],
          child: Icon(
            Icons.eco,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                grow.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: grow.archived ? Colors.grey[600] : null,
                ),
              ),
            ),
            if (grow.archived)
              Container(
                padding: AppConstants.badgePadding,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(AppConstants.badgeBorderRadius),
                ),
                child: Text(
                  _t['archived_badge'],
                  style: TextStyle(
                    fontSize: AppConstants.badgeFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (grow.description != null && grow.description!.isNotEmpty)
              Text(
                grow.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: grow.archived ? Colors.grey[500] : null),
              ),
            SizedBox(height: AppConstants.spacingXs),
            Row(
              children: [
                Icon(Icons.calendar_today,
                    size: AppConstants.listItemIconSize,
                    color: Colors.grey[600]
                ),
                SizedBox(width: AppConstants.listItemIconSpacing),
                Text(
                  '${_t['day_short']} ${grow.totalDays} • ${grow.status}',
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: AppConstants.fontSizeSmall
                  ),
                ),
                const Spacer(),
                Icon(Icons.spa,
                    size: AppConstants.listItemIconSize,
                    color: Colors.grey[600]
                ),
                SizedBox(width: AppConstants.listItemIconSpacing),
                Text(
                  '$plantCount ${_t['plants_short']}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: AppConstants.fontSizeSmall,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue[700]),
                  SizedBox(width: AppConstants.spacingSmall),
                  Text(
                    _t['edit'],
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(
                    grow.archived ? Icons.unarchive : Icons.archive,
                    color: Colors.orange,
                  ),
                  SizedBox(width: AppConstants.spacingSmall),
                  Text(
                    grow.archived ? _t['unarchive'] : _t['archive'],
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: AppConstants.spacingSmall),
                  Text(_t['delete'], style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _editGrow(grow);
            } else if (value == 'delete') {
              _deleteGrow(grow);
            } else if (value == 'archive') {
              _toggleArchive(grow);
            }
          },
        ),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GrowDetailScreen(grow: grow),
            ),
          );
          if (result == true) _loadGrows();
        },
      ),
    );
  }
}