// =============================================
// GROWLOG - Add Log Screen
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';
import 'package:growlog_app/services/interfaces/i_log_service.dart';
import 'package:growlog_app/utils/error_handling_mixin.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/models/fertilizer_set.dart';
import 'package:growlog_app/repositories/fertilizer_set_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class AddLogScreen extends StatefulWidget {
  final Plant plant;
  final bool bulkMode;
  final List<int>? bulkPlantIds;

  const AddLogScreen({
    super.key,
    required this.plant,
    this.bulkMode = false,
    this.bulkPlantIds,
  });

  @override
  State<AddLogScreen> createState() => _AddLogScreenState();
}

class _AddLogScreenState extends State<AddLogScreen> with ErrorHandlingMixin {
  final _formKey = GlobalKey<FormState>();
  late AppTranslations _t;

  final ILogService _logService = getIt<ILogService>();
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ImagePicker _imagePicker = ImagePicker();

  final _waterAmountController = TextEditingController();
  final _phInController = TextEditingController();
  final _ecInController = TextEditingController();
  final _phOutController = TextEditingController();
  final _ecOutController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _humidityController = TextEditingController();
  final _noteController = TextEditingController();
  final _containerSizeController = TextEditingController();
  final _containerMediumAmountController = TextEditingController();
  final _containerDrainageMaterialController = TextEditingController();
  final _systemReservoirSizeController = TextEditingController();
  final _systemBucketCountController = TextEditingController();
  final _systemBucketSizeController = TextEditingController();

  late ActionType _selectedAction;
  PlantPhase? _selectedNewPhase;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  int _nextDayNumber = 1;
  List<Fertilizer> _availableFertilizers = [];
  Map<int, double> _selectedFertilizers = {};
  List<Map<String, dynamic>> _recentFertilizerUsage = [];
  final List<XFile> _selectedPhotos = [];

  bool _runoffEnabled = false;
  bool _cleanse = false;

  bool get _isHydroSystem {
    final m = widget.plant.medium;
    return m == Medium.rdwc ||
        m == Medium.dwc ||
        m == Medium.hydro ||
        m == Medium.aero;
  }

  List<ActionType> _allowedActions() {
    final phase = widget.plant.phase;
    final isArchived = phase == PlantPhase.archived;
    final isPostHarvest = phase == PlantPhase.harvest;

    return ActionType.values.where((a) {
      if (a == ActionType.harvest) return false;
      if (_isHydroSystem && a == ActionType.water) return false;
      if (_isHydroSystem && a == ActionType.feed) return false;
      if (widget.plant.medium == Medium.rdwc && a == ActionType.transplant)
        return false;
      // Archived: nur Note und Other
      if (isArchived && a != ActionType.note && a != ActionType.other)
        return false;
      // Harvest-Phase: kein Watering/Feeding/Transplanting/Training/Trimming
      if (isPostHarvest &&
          (a == ActionType.water ||
              a == ActionType.feed ||
              a == ActionType.transplant ||
              a == ActionType.trim)) {
        return false;
      }
      return true;
    }).toList();
  }

  String _actionLabel(ActionType a) => a.labelForMedium(
    widget.plant.medium,
    languageCode: Localizations.localeOf(context).languageCode,
  );

  @override
  void initState() {
    super.initState();
    final phase = widget.plant.phase;
    if (phase == PlantPhase.archived || phase == PlantPhase.harvest) {
      _selectedAction = ActionType.note;
    } else if (_isHydroSystem) {
      _selectedAction = ActionType.note;
    } else {
      _selectedAction = ActionType.water;
    }
    _loadNextDayNumber();
    _loadFertilizers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  Future<void> _loadNextDayNumber() async {
    final dayNumber = await _logRepo.getNextDayNumber(
      widget.plant.id!,
      forDate: _selectedDate,
    );
    if (mounted) {
      setState(() => _nextDayNumber = dayNumber);
    }
  }

  Future<void> _loadFertilizers() async {
    try {
      final fertilizers = await _fertilizerRepo.findAll();
      List<Map<String, dynamic>> recentUsage = [];
      if (!widget.bulkMode && widget.plant.id != null) {
        final db = await DatabaseHelper.instance.database;
        final rows = await db.rawQuery(
          '''
          SELECT lf.fertilizer_id, AVG(lf.amount) as avg_amount, COUNT(*) as use_count
          FROM log_fertilizers lf
          JOIN plant_logs pl ON lf.log_id = pl.id
          WHERE pl.plant_id = ?
          GROUP BY lf.fertilizer_id
          ORDER BY use_count DESC
          LIMIT 5
        ''',
          [widget.plant.id],
        );
        recentUsage = rows.toList();
      }
      if (mounted) {
        setState(() {
          _availableFertilizers = fertilizers;
          _recentFertilizerUsage = recentUsage;
        });
      }
    } catch (e) {
      AppLogger.error('AddLogScreen', 'Error loading fertilizers: $e');
    }
  }

  Future<void> _copyLastLog() async {
    try {
      final lastLog = await _logRepo.getLastLogForPlant(widget.plant.id!);
      if (lastLog == null) {
        if (mounted) AppMessages.noPreviousLog(context);
        return;
      }
      final logDetails = await _logService.getLogWithDetails(lastLog.id!);
      if (logDetails == null) return;
      final sourceFertilizers =
          logDetails['fertilizers'] as List<Map<String, dynamic>>;

      if (!mounted) return;
      setState(() {
        _selectedAction = lastLog.actionType;
        _waterAmountController.text =
            lastLog.waterAmount?.toStringAsFixed(1) ?? '';
        _phInController.text = lastLog.phIn?.toStringAsFixed(1) ?? '';
        _ecInController.text = lastLog.ecIn?.toStringAsFixed(1) ?? '';
        _phOutController.text = lastLog.phOut?.toStringAsFixed(1) ?? '';
        _ecOutController.text = lastLog.ecOut?.toStringAsFixed(1) ?? '';
        _temperatureController.text =
            lastLog.temperature?.toStringAsFixed(1) ?? '';
        _humidityController.text = lastLog.humidity?.toStringAsFixed(0) ?? '';
        _noteController.text = lastLog.note ?? '';
        _containerSizeController.text =
            lastLog.containerSize?.toStringAsFixed(0) ?? '';
        _containerMediumAmountController.text =
            lastLog.containerMediumAmount?.toStringAsFixed(1) ?? '';
        _containerDrainageMaterialController.text =
            lastLog.containerDrainageMaterial ?? '';
        _systemReservoirSizeController.text =
            lastLog.systemReservoirSize?.toStringAsFixed(0) ?? '';
        _systemBucketCountController.text =
            lastLog.systemBucketCount?.toString() ?? '';
        _systemBucketSizeController.text =
            lastLog.systemBucketSize?.toStringAsFixed(0) ?? '';
        _selectedFertilizers = {
          for (final fert in sourceFertilizers)
            fert['fertilizer_id'] as int: (fert['amount'] as num).toDouble(),
        };
        _runoffEnabled =
            lastLog.phOut != null || lastLog.ecOut != null || lastLog.runoff;
        _cleanse = lastLog.cleanse;
      });
      if (mounted) AppMessages.logCopied(context);
    } catch (e) {
      if (mounted) AppMessages.showError(context, 'Fehler: $e');
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null && mounted) {
        setState(() => _selectedPhotos.add(photo));
      }
    } catch (e) {
      if (mounted) AppMessages.showError(context, 'Fehler: $e');
    }
  }

  Future<List<String>> _savePhotos() async {
    final List<String> savedPaths = [];
    if (_selectedPhotos.isEmpty) return savedPaths;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory(path.join(directory.path, 'photos'));
      if (!await photosDir.exists()) await photosDir.create(recursive: true);
      for (final photo in _selectedPhotos) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photo.path)}';
        final filePath = path.join(photosDir.path, fileName);
        await File(photo.path).copy(filePath);
        savedPaths.add(filePath);
      }
    } catch (e) {
      AppLogger.error('AddLogScreen', 'Error saving photos', e);
    }
    return savedPaths;
  }

  @override
  void dispose() {
    _waterAmountController.dispose();
    _phInController.dispose();
    _ecInController.dispose();
    _phOutController.dispose();
    _ecOutController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    _noteController.dispose();
    _containerSizeController.dispose();
    _containerMediumAmountController.dispose();
    _containerDrainageMaterialController.dispose();
    _systemReservoirSizeController.dispose();
    _systemBucketCountController.dispose();
    _systemBucketSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bulkMode
        ? _t['bulk_log_title'].replaceAll(
            '{count}',
            '${widget.bulkPlantIds?.length ?? 0}',
          )
        : _t['log_create_title'];
    return PlantryScaffold(
      title: title,
      actions: [
        if (!widget.bulkMode)
          IconButton(
            icon: const Icon(Icons.content_copy, color: DT.textPrimary),
            onPressed: _copyLastLog,
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDayCard(),
                  const SizedBox(height: 24),
                  _buildActionSelector(),
                  const SizedBox(height: 24),
                  if (_selectedAction == ActionType.phaseChange) ...[
                    _buildPhaseSelector(),
                    const SizedBox(height: 24),
                  ],
                  _dateTile(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 24),
                  if (_selectedAction == ActionType.water ||
                      _selectedAction == ActionType.feed) ...[
                    _section(_t['section_water_values']),
                    PlantryFormField(
                      controller: _waterAmountController,
                      label: _t['label_water_amount'],
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(
                        Icons.water_drop,
                        color: DT.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: PlantryFormField(
                            controller: _phInController,
                            label: _t['label_ph_in'],
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PlantryFormField(
                            controller: _ecInController,
                            label: _t['label_ec_in'],
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    if (widget.plant.medium.needsRunoffFlags) ...[
                      const SizedBox(height: 12),
                      _buildRunoffSection(),
                      const SizedBox(height: 8),
                      _buildCleanseRow(),
                    ],
                    const SizedBox(height: 24),
                  ],
                  if (_selectedAction == ActionType.feed) ...[
                    _buildFertilizerSection(),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedAction == ActionType.transplant) ...[
                    _section(_t['section_container_system']),
                    Row(
                      children: [
                        Expanded(
                          child: PlantryFormField(
                            controller: _containerSizeController,
                            label: _t['label_pot_size'],
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PlantryFormField(
                            controller: _systemReservoirSizeController,
                            label: _t['label_reservoir_size'],
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  _section(_t['section_environment_note']),
                  Row(
                    children: [
                      Expanded(
                        child: PlantryFormField(
                          controller: _temperatureController,
                          label: _t['label_temperature'],
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PlantryFormField(
                          controller: _humidityController,
                          label: _t['label_humidity'],
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PlantryFormField(
                    controller: _noteController,
                    label: _t['notes'],
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  PlantryButton(
                    label: _t['save'],
                    onPressed: _save,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildDayCard() {
    return PlantryCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DT.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_today, color: DT.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_t['day']} $_nextDayNumber',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DT.textPrimary,
                ),
              ),
              Text(
                widget.plant.phase.displayName,
                style: const TextStyle(fontSize: 13, color: DT.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['action'],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: DT.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allowedActions().map((a) {
            final sel = _selectedAction == a;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedAction = a;
                if (a != ActionType.phaseChange) _selectedNewPhase = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? DT.accent : DT.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? DT.accent : DT.border),
                ),
                child: Text(
                  _actionLabel(a),
                  style: TextStyle(
                    color: sel ? DT.onAccent : DT.textSecondary,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dateTile() {
    return PlantryCard(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (d != null)
          setState(
            () => _selectedDate = DateTime(
              d.year,
              d.month,
              d.day,
              _selectedDate.hour,
              _selectedDate.minute,
            ),
          );
      },
      child: Row(
        children: [
          const Icon(Icons.access_time, color: DT.textTertiary, size: 20),
          const SizedBox(width: 12),
          Text(
            DateFormat('dd.MM.yyyy HH:mm').format(_selectedDate),
            style: const TextStyle(color: DT.textPrimary),
          ),
          const Spacer(),
          const Icon(Icons.chevron_right, color: DT.textTertiary, size: 18),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _t['photos'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: DT.textSecondary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_a_photo, color: DT.accent, size: 20),
              onPressed: () => _pickPhoto(ImageSource.camera),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedPhotos.isEmpty)
          GestureDetector(
            onTap: () => _pickPhoto(ImageSource.gallery),
            child: Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                color: DT.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DT.border),
              ),
              child: Center(
                child: Text(
                  _t['add_photo_placeholder'],
                  style: const TextStyle(color: DT.textTertiary, fontSize: 13),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedPhotos[i].path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPhotos.removeAt(i)),
                        child: Container(
                          color: DT.canvas.withValues(alpha: 0.54),
                          child: const Icon(
                            Icons.close,
                            color: DT.textPrimary,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFertilizerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              _t['fertilizers'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: DT.textSecondary,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: DT.accent,
                size: 20,
              ),
              onPressed: _addFert,
            ),
            if (!widget.bulkMode) ...[
              IconButton(
                icon: const Icon(
                  Icons.science_outlined,
                  color: DT.info,
                  size: 20,
                ),
                tooltip: _t['load_recipe'],
                onPressed: _loadRecipe,
              ),
              IconButton(
                icon: const Icon(
                  Icons.bookmark_outline,
                  color: DT.textSecondary,
                  size: 20,
                ),
                tooltip: _t['load_set'],
                onPressed: _loadSet,
              ),
              IconButton(
                icon: Icon(
                  Icons.bookmark_add_outlined,
                  color: _selectedFertilizers.isNotEmpty
                      ? DT.accent
                      : DT.textTertiary,
                  size: 20,
                ),
                tooltip: _t['save_set'],
                onPressed: _selectedFertilizers.isNotEmpty ? _saveAsSet : null,
              ),
            ],
          ],
        ),
        if (!widget.bulkMode && _recentFertilizerUsage.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _recentFertilizerUsage.length,
              separatorBuilder: (_, si) => const SizedBox(width: 6),
              itemBuilder: (ctx, i) {
                final usage = _recentFertilizerUsage[i];
                final fertId = usage['fertilizer_id'] as int;
                final avgAmount = (usage['avg_amount'] as num).toDouble();
                final roundedAmount = double.parse(
                  avgAmount.toStringAsFixed(1),
                );
                final fert = _availableFertilizers.firstWhere(
                  (f) => f.id == fertId,
                  orElse: () => Fertilizer(name: _t['fertilizer_unknown']),
                );
                final isSelected = _selectedFertilizers.containsKey(fertId);
                return GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      setState(
                        () => _selectedFertilizers[fertId] = roundedAmount,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: DT.elevated,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? DT.accent : DT.border,
                      ),
                    ),
                    child: Text(
                      '${fert.name} ${roundedAmount}ml',
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? DT.textTertiary : DT.textPrimary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        ..._selectedFertilizers.entries.map((e) {
          final f = _availableFertilizers.firstWhere(
            (f) => f.id == e.key,
            orElse: () => Fertilizer(name: _t['fertilizer_unknown']),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlantryCard(
              isFlat: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      f.name,
                      style: const TextStyle(
                        color: DT.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${e.value}ml',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DT.accent,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: DT.error,
                      size: 18,
                    ),
                    onPressed: () =>
                        setState(() => _selectedFertilizers.remove(e.key)),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _saveAsSet() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(
          _t['save_set'],
          style: const TextStyle(color: DT.textPrimary),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: DT.textPrimary),
          decoration: InputDecoration(
            labelText: _t['set_name_label'],
            labelStyle: const TextStyle(color: DT.textSecondary),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _t['cancel'],
              style: const TextStyle(color: DT.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: Text(_t['save'], style: const TextStyle(color: DT.accent)),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await FertilizerSetRepository().save(name, _selectedFertilizers);
      if (mounted)
        AppMessages.showSuccess(context, '${_t['set_saved']}: $name');
    } catch (e) {
      if (mounted) AppMessages.showError(context, _t['error_saving_set']);
    }
  }

  Future<void> _loadSet() async {
    try {
      final repo = FertilizerSetRepository();
      final sets = await repo.findAll();
      if (sets.isEmpty) {
        if (mounted) AppMessages.showError(context, _t['no_sets_available']);
        return;
      }

      if (!mounted) return;

      final selectedSetId = await showDialog<int>(
        context: context,
        builder: (ctx) {
          final setList = List<FertilizerSet>.from(sets);
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: DT.elevated,
              title: Text(
                _t['load_set'],
                style: const TextStyle(color: DT.textPrimary),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: setList.length,
                  itemBuilder: (ctx, i) {
                    final s = setList[i];
                    return Dismissible(
                      key: Key('set_${s.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(color: DT.elevated),
                      secondaryBackground: Container(
                        color: DT.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: DT.textPrimary),
                      ),
                      onDismissed: (_) async {
                        await repo.delete(s.id!);
                        setDialogState(() => setList.removeAt(i));
                      },
                      child: ListTile(
                        title: Text(
                          s.name,
                          style: const TextStyle(color: DT.textPrimary),
                        ),
                        subtitle: Text(
                          '${s.itemCount} ${_t['fertilizers']}',
                          style: const TextStyle(
                            color: DT.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => Navigator.pop(ctx, s.id),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    _t['cancel'],
                    style: const TextStyle(color: DT.textSecondary),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (selectedSetId == null) return;
      final items = await repo.findItems(selectedSetId);
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          _selectedFertilizers[item.fertilizerId] = item.amount;
        }
      });
    } catch (e) {
      if (mounted) AppMessages.showError(context, _t['error_loading_set']);
    }
  }

  Future<void> _loadRecipe() async {
    try {
      final recipes = await _rdwcRepo.getAllRecipes();
      if (recipes.isEmpty) {
        if (mounted) AppMessages.showError(context, _t['no_recipes_available']);
        return;
      }

      if (!mounted) return;

      final selected = await showDialog<RdwcRecipe>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DT.elevated,
          title: Text(
            _t['load_recipe'],
            style: const TextStyle(color: DT.textPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: recipes.length,
              itemBuilder: (ctx, i) {
                final recipe = recipes[i];
                final fertCount = recipe.fertilizers.length;
                return ListTile(
                  leading: const Icon(Icons.science_outlined, color: DT.info),
                  title: Text(
                    recipe.name,
                    style: const TextStyle(color: DT.textPrimary),
                  ),
                  subtitle: Text(
                    '$fertCount ${_t['fertilizers']}${recipe.targetEc != null ? ' · EC ${recipe.targetEc!.toStringAsFixed(1)}' : ''}',
                    style: const TextStyle(
                      color: DT.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, recipe),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                _t['cancel'],
                style: const TextStyle(color: DT.textSecondary),
              ),
            ),
          ],
        ),
      );

      if (selected == null || !mounted) return;

      // Calculate amounts: if water volume is set, scale ml/L → actual ml
      final waterLiters = double.tryParse(
        _waterAmountController.text.replaceAll(',', '.'),
      );
      final hasVolume = waterLiters != null && waterLiters > 0;

      setState(() {
        _selectedFertilizers.clear();
        for (final rf in selected.fertilizers) {
          final amount = hasVolume
              ? double.parse((rf.mlPerLiter * waterLiters).toStringAsFixed(1))
              : rf.mlPerLiter;
          _selectedFertilizers[rf.fertilizerId] = amount;
        }
      });

      if (mounted) {
        AppMessages.showSuccess(
          context,
          hasVolume
              ? '${_t['recipe_loaded']}: ${selected.name}'
              : '${_t['recipe_loaded']}: ${selected.name} (ml/L)',
        );
      }
    } catch (e) {
      if (mounted) AppMessages.showError(context, _t['error_loading_recipe']);
    }
  }

  Future<void> _addFert() async {
    final sel = await showDialog<Fertilizer>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(
          _t['choose_fertilizer'],
          style: const TextStyle(color: DT.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableFertilizers.length,
            itemBuilder: (ctx, i) => ListTile(
              title: Text(
                _availableFertilizers[i].name,
                style: const TextStyle(color: DT.textPrimary),
              ),
              onTap: () => Navigator.pop(ctx, _availableFertilizers[i]),
            ),
          ),
        ),
      ),
    );
    if (sel != null) {
      if (!mounted) return;
      final amt = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: DT.elevated,
          title: Text(sel.name, style: const TextStyle(color: DT.textPrimary)),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['fertilizer_amount_label'],
            ),
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v)),
          ),
        ),
      );
      if (amt != null && amt > 0)
        setState(() => _selectedFertilizers[sel.id!] = amt);
    }
  }

  Widget _buildPhaseSelector() {
    final phases = PlantPhase.values
        .where((p) => p != PlantPhase.archived)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['section_new_phase'],
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: DT.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: phases.map((p) {
            final sel = _selectedNewPhase == p;
            return GestureDetector(
              onTap: () => setState(() => _selectedNewPhase = p),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? DT.accent : DT.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? DT.accent : DT.border),
                ),
                child: Text(
                  p.displayName,
                  style: TextStyle(
                    color: sel ? DT.onAccent : DT.textSecondary,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRunoffSection() {
    return PlantryCard(
      isFlat: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t['runoff_measured_label'],
                style: const TextStyle(color: DT.textPrimary, fontSize: 13),
              ),
              Switch(
                value: _runoffEnabled,
                onChanged: (v) => setState(() {
                  _runoffEnabled = v;
                  if (!v) {
                    _phOutController.clear();
                    _ecOutController.clear();
                  }
                }),
                activeThumbColor: DT.accent,
              ),
            ],
          ),
          if (_runoffEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: PlantryFormField(
                    controller: _phOutController,
                    label: _t['label_ph_out'],
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PlantryFormField(
                    controller: _ecOutController,
                    label: _t['label_ec_out'],
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanseRow() {
    return PlantryCard(
      isFlat: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _t['cleanse_label'],
            style: const TextStyle(color: DT.textPrimary, fontSize: 13),
          ),
          Switch(
            value: _cleanse,
            onChanged: (v) => setState(() => _cleanse = v),
            activeThumbColor: DT.accent,
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: DT.textSecondary,
      ),
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAction == ActionType.phaseChange &&
        _selectedNewPhase == null) {
      AppMessages.showError(context, _t['error_phase_required']);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final photoPaths = await _savePhotos();
      if (widget.bulkMode) {
        await _logService.saveBulkLog(
          plantIds: widget.bulkPlantIds!,
          logDate: _selectedDate,
          actionType: _selectedAction,
          waterAmount: double.tryParse(_waterAmountController.text),
          phIn: double.tryParse(_phInController.text),
          ecIn: double.tryParse(_ecInController.text),
          phOut: _runoffEnabled ? double.tryParse(_phOutController.text) : null,
          ecOut: _runoffEnabled ? double.tryParse(_ecOutController.text) : null,
          runoff: _runoffEnabled,
          cleanse: _cleanse,
          temperature: double.tryParse(_temperatureController.text),
          humidity: double.tryParse(_humidityController.text),
          note: _noteController.text,
          fertilizers: _selectedFertilizers,
          photoPaths: photoPaths,
          newPhase: _selectedNewPhase,
        );
      } else {
        final log = PlantLog(
          plantId: widget.plant.id!,
          dayNumber: _nextDayNumber,
          logDate: _selectedDate,
          actionType: _selectedAction,
          waterAmount: double.tryParse(_waterAmountController.text),
          phIn: double.tryParse(_phInController.text),
          ecIn: double.tryParse(_ecInController.text),
          phOut: _runoffEnabled ? double.tryParse(_phOutController.text) : null,
          ecOut: _runoffEnabled ? double.tryParse(_ecOutController.text) : null,
          runoff: _runoffEnabled,
          cleanse: _cleanse,
          containerSize: _selectedAction == ActionType.transplant
              ? double.tryParse(_containerSizeController.text)
              : null,
          systemReservoirSize: _selectedAction == ActionType.transplant
              ? double.tryParse(_systemReservoirSizeController.text)
              : null,
          temperature: double.tryParse(_temperatureController.text),
          humidity: double.tryParse(_humidityController.text),
          note: _noteController.text,
        );
        await _logService.saveSingleLog(
          plant: widget.plant,
          log: log,
          fertilizers: _selectedFertilizers,
          photoPaths: photoPaths,
          newPhase: _selectedNewPhase,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessages.showError(context, _t['error_saving_log']);
      setState(() => _isLoading = false);
    }
  }
}
