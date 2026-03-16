// =============================================
// GROWLOG - Fertilizer List Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/screens/add_fertilizer_screen.dart';
import 'package:growlog_app/screens/edit_fertilizer_screen.dart';
import 'package:growlog_app/screens/fertilizer_dbf_import_screen.dart';
import 'package:growlog_app/screens/rdwc_recipes_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_list_tile.dart';
import 'package:growlog_app/theme/design_tokens.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final fertilizers = await _fertilizerRepo.findAll();
      if (mounted) {
        setState(() {
          _fertilizers = fertilizers;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('FertilizerListScreen', 'Error loading: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFertilizer(Fertilizer fertilizer) async {
    final isInUse = await _fertilizerRepo.isInUse(fertilizer.id!);

    if (isInUse) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: DT.elevated,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: DT.warning),
              const SizedBox(width: 12),
              Expanded(child: Text(_t['cannot_delete'], style: const TextStyle(color: DT.textPrimary))),
            ],
          ),
          content: Text(_t['fertilizer_in_use_message'], style: const TextStyle(color: DT.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_t['ok'], style: const TextStyle(color: DT.accent))),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(_t['delete_fertilizer_title'], style: const TextStyle(color: DT.textPrimary)),
        content: Text('${_t['delete_confirm'].replaceAll('?', '')} "${fertilizer.name}"?', style: const TextStyle(color: DT.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _fertilizerRepo.delete(fertilizer.id!);
        _loadFertilizers();
        if (mounted) AppMessages.deletedSuccessfully(context, _t['fertilizers']);
      } catch (e) {
        AppLogger.error('FertilizerListScreen', 'Error: $e');
      }
    }
  }

  Future<void> _pickAndImportDbf() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      final file = File(filePath);
      if (mounted) {
        final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => FertilizerDbfImportScreen(dbfFile: file)));
        if (res == true) _loadFertilizers();
      }
    } catch (e) {
      AppLogger.error('FertilizerListScreen', 'Error DBF', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['fertilizers'],
      actions: [
        IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RdwcRecipesScreen())),
          icon: const Icon(Icons.menu_book, color: DT.textPrimary),
          tooltip: _t['recipes'],
        ),
        IconButton(
          onPressed: _pickAndImportDbf,
          icon: const Icon(Icons.upload_file, color: DT.textPrimary),
          tooltip: _t['fertilizer_import_dbf'],
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : _fertilizers.isEmpty
          ? _buildEmptyState()
          : _buildFertilizerList(),
      fab: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddFertilizerScreen()),
          );
          if (result == true) _loadFertilizers();
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
          const Icon(Icons.science_outlined, size: 80, color: DT.textTertiary),
          const SizedBox(height: 24),
          Text(_t['no_fertilizers'], style: const TextStyle(fontSize: 20, color: DT.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_t['add_first_fertilizer'], style: const TextStyle(fontSize: 16, color: DT.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFertilizerList() {
    return RefreshIndicator(
      onRefresh: _loadFertilizers,
      color: DT.accent,
      backgroundColor: DT.surface,
      child: ListView.builder(
        itemCount: _fertilizers.length,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemBuilder: (context, index) => _buildFertilizerCard(_fertilizers[index]),
      ),
    );
  }

  Widget _buildFertilizerCard(Fertilizer f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlantryListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _getTypeColor(f.type).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.science_rounded, color: _getTypeColor(f.type), size: 28),
        ),
        title: f.name,
        subtitle: '${f.brand ?? "Keine Marke"} • NPK: ${f.npk ?? "n/a"}\n${f.type ?? "Allzweck"}',
        trailing: PopupMenuButton<String>(
          color: DT.elevated,
          icon: const Icon(Icons.more_vert, color: DT.textTertiary),
          onSelected: (val) async {
            if (val == 'edit') {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditFertilizerScreen(fertilizer: f)));
              if (res == true) _loadFertilizers();
            } else if (val == 'delete') {
              _deleteFertilizer(f);
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(value: 'edit', child: Text(_t['edit'], style: const TextStyle(color: DT.textPrimary))),
            PopupMenuItem(value: 'delete', child: Text(_t['delete'], style: const TextStyle(color: DT.error))),
          ],
        ),
        onTap: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditFertilizerScreen(fertilizer: f)));
          if (res == true) _loadFertilizers();
        },
      ),
    );
  }

  Color _getTypeColor(String? type) {
    if (type == null) return DT.textTertiary;
    final t = type.toUpperCase();
    if (t.contains('BLOOM') || t.contains('BLÜTE')) return Colors.purple;
    if (t.contains('VEG') || t.contains('WUCHS')) return DT.accent;
    if (t.contains('ROOT') || t.contains('WURZEL')) return Colors.brown;
    return DT.accent;
  }
}
