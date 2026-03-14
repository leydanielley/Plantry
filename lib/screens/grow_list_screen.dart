// =============================================
// GROWLOG - Grow List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/screens/add_grow_screen.dart';
import 'package:growlog_app/screens/edit_grow_screen.dart';
import 'package:growlog_app/screens/grow_detail_screen.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class GrowListScreen extends StatefulWidget {
  const GrowListScreen({super.key});

  @override
  State<GrowListScreen> createState() => _GrowListScreenState();
}

class _GrowListScreenState extends State<GrowListScreen> {
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final grows = await _growRepo.getAll(includeArchived: _showArchived);
      final growIds = grows
          .where((g) => g.id != null)
          .map((g) => g.id!)
          .toList();
      final counts = await _growRepo.getPlantCountsForGrows(growIds);

      if (mounted) {
        setState(() {
          _grows = grows;
          _plantCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('GrowListScreen', 'Error loading grows: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppMessages.loadingError(context, 'Grows', onRetry: _loadGrows);
      }
    }
  }

  Future<void> _editGrow(Grow grow) async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => EditGrowScreen(grow: grow)));
    if (result == true) _loadGrows();
  }

  Future<void> _deleteGrow(Grow grow) async {
    final plantCount = await _growRepo.getPlantCount(grow.id!);

    if (!mounted) return;

    if (plantCount > 0) {
      final confirmDetach = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DT.elevated,
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: DT.warning),
              const SizedBox(width: 12),
              Expanded(child: Text(_t['attention'], style: const TextStyle(color: DT.textPrimary))),
            ],
          ),
          content: Text(
            _t['delete_grow_with_plants'].replaceAll('{count}', plantCount.toString()),
            style: const TextStyle(color: DT.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_t['yes_delete'], style: const TextStyle(color: DT.warning)),
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
        backgroundColor: DT.elevated,
        title: Text(_t['delete_grow_title'], style: const TextStyle(color: DT.textPrimary)),
        content: Text(
          '${_t['delete_confirm'].replaceAll('?', '')} "${grow.name}"?',
          style: const TextStyle(color: DT.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_t['delete'], style: const TextStyle(color: DT.error)),
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
        if (mounted) AppMessages.restoredSuccessfully(context, 'Grow');
      } else {
        await _growRepo.archive(grow.id!);
        if (mounted) AppMessages.archivedSuccessfully(context, 'Grow');
      }
      _loadGrows();
    } catch (e) {
      AppLogger.error('GrowListScreen', 'Error archiving: $e');
      if (mounted) AppMessages.showError(context, '${_t['error']}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['grows'],
      actions: [
        IconButton(
          icon: Icon(
            _showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            color: DT.textPrimary,
          ),
          tooltip: _showArchived ? _t['hide_archived'] : _t['show_archived'],
          onPressed: () {
            setState(() => _showArchived = !_showArchived);
            _loadGrows();
          },
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : _grows.isEmpty
          ? _buildEmptyState()
          : _buildGrowList(),
      fab: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddGrowScreen()),
          );
          if (result == true) _loadGrows();
        },
        backgroundColor: DT.accent,
        foregroundColor: DT.onAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.eco_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(
            _showArchived ? _t['no_archived_grows'] : _t['no_grows'],
            style: const TextStyle(fontSize: 20, color: DT.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived ? _t['archive_grow_to_see'] : _t['create_first_grow'],
            style: const TextStyle(fontSize: 16, color: DT.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowList() {
    return RefreshIndicator(
      onRefresh: _loadGrows,
      color: DT.accent,
      backgroundColor: DT.surface,
      child: ListView.builder(
        itemCount: _grows.length,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) => _buildGrowCard(_grows[index]),
      ),
    );
  }

  Widget _buildGrowCard(Grow grow) {
    final plantCount = _plantCounts[grow.id] ?? 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlantryListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: grow.archived ? DT.elevated : DT.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.eco_rounded, 
            color: grow.archived ? DT.textTertiary : DT.accent,
            size: 28,
          ),
        ),
        title: grow.name,
        subtitle: '${_t['day_short']} ${grow.totalDays} • $plantCount ${_t['plants_short']}${grow.archived ? ' • ${_t['archived_badge']}' : ''}',
        trailing: PopupMenuButton<String>(
          color: DT.elevated,
          icon: const Icon(Icons.more_vert, color: DT.textTertiary),
          onSelected: (val) {
            if (val == 'edit') _editGrow(grow);
            if (val == 'archive') _toggleArchive(grow);
            if (val == 'delete') _deleteGrow(grow);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text(_t['edit'], style: const TextStyle(color: DT.textPrimary))),
            PopupMenuItem(value: 'archive', child: Text(grow.archived ? 'Dearchivieren' : 'Archivieren', style: const TextStyle(color: DT.textPrimary))),
            PopupMenuItem(value: 'delete', child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
          ],
        ),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => GrowDetailScreen(grow: grow)),
          );
          if (result == true) _loadGrows();
        },
      ),
    );
  }
}
