// =============================================
// GROWLOG - Add Log Screen (OPTIMIZED mit LogService!)
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/services/interfaces/i_log_service.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/error_handling_mixin.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/storage_helper.dart';
import 'package:growlog_app/di/service_locator.dart';

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

  final ILogService _logService = getIt<ILogService>();
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
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

  ActionType _selectedAction = ActionType.water;
  PlantPhase? _selectedPhase;
  DateTime _selectedDate = DateTime.now();
  bool _runoff = false;
  bool _cleanse = false;
  bool _containerDrainage = false;
  bool _isLoading = false;
  int _nextDayNumber = 1;
  List<Fertilizer> _availableFertilizers = [];
  Map<int, double> _selectedFertilizers = {};
  final List<XFile> _selectedPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadNextDayNumber();
    _loadFertilizers();
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
      if (mounted) {
        setState(() => _availableFertilizers = fertilizers);
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
        _runoff = lastLog.runoff;
        _cleanse = lastLog.cleanse;
        _noteController.text = lastLog.note ?? '';
        _containerSizeController.text =
            lastLog.containerSize?.toStringAsFixed(0) ?? '';
        _containerMediumAmountController.text =
            lastLog.containerMediumAmount?.toStringAsFixed(1) ?? '';
        _containerDrainage = lastLog.containerDrainage;
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
      });

      if (mounted) AppMessages.logCopied(context);
    } catch (e) {
      AppLogger.error('AddLogScreen', 'Error copying last log: $e');
      if (mounted) {
        AppMessages.showError(context, 'Fehler beim Kopieren: $e');
      }
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

      if (photo != null) {
        // ✅ FIX: Validate file type to prevent malicious uploads
        final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
        // ✅ CRITICAL FIX: Check for -1 from lastIndexOf to prevent substring crash
        final dotIndex = photo.path.lastIndexOf('.');
        final extension = dotIndex != -1
            ? photo.path.toLowerCase().substring(dotIndex)
            : '';

        if (!allowedExtensions.contains(extension)) {
          if (mounted) {
            AppMessages.showError(
              context,
              'Ungültiger Dateityp. Nur Bilder (.jpg, .jpeg, .png, .webp) sind erlaubt.',
            );
          }
          return;
        }

        if (mounted) {
          setState(() {
            _selectedPhotos.add(photo);
          });
        }
      }
    } catch (e) {
      AppLogger.error('AddLogScreen', 'Error picking photo: $e');
      if (mounted) {
        AppMessages.showError(context, 'Fehler beim Foto auswählen: $e');
      }
    }
  }

  // ✅ BUG #3 FIX: State-Management Foto-Dialog
  Future<void> _showPhotoSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (dialogContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(dialogContext);
                // Foto-Auswahl im nächsten Frame nach Dialog-Schließung
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _pickPhoto(ImageSource.camera);
                  }
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(dialogContext);
                // Foto-Auswahl im nächsten Frame nach Dialog-Schließung
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _pickPhoto(ImageSource.gallery);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    if (mounted) {
      setState(() {
        _selectedPhotos.removeAt(index);
      });
    }
  }

  // ✅ BUG #6 FIX: Foto-Speicherung Error Handling + Storage Check
  Future<List<String>> _savePhotos() async {
    final List<String> savedPaths = [];
    final List<String> failedPhotos = [];

    try {
      // ✅ P0 FIX: Check storage BEFORE attempting to save
      final totalSizeNeeded = _selectedPhotos.fold<int>(
        0,
        (sum, photo) => sum + (File(photo.path).lengthSync()),
      );

      final hasSpace = await StorageHelper.hasEnoughStorage(
        bytesNeeded:
            totalSizeNeeded + (50 * 1024 * 1024), // Photos + 50MB buffer
      );

      if (!hasSpace) {
        AppLogger.error('AddLogScreen', '❌ Insufficient storage for photos');
        // ✅ CRITICAL FIX: Check both mounted AND context.mounted to prevent crash
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ${AppTranslations(Localizations.localeOf(context).languageCode)['error']}',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return savedPaths;
      }

      final directory = await getApplicationDocumentsDirectory();
      // ✅ FIX: Use path.join instead of string interpolation for cross-platform compatibility
      final photosDir = Directory(path.join(directory.path, 'photos'));

      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      // Einzelnes Error Handling pro Foto
      for (final photo in _selectedPhotos) {
        try {
          final file = File(photo.path);

          // ✅ SAFETY: Check file size (max 10MB)
          final size = await file.length();
          if (size > 10 * 1024 * 1024) {
            AppLogger.warning(
              'AddLogScreen',
              '⚠️ Photo too large: ${photo.name} (${(size / 1024 / 1024).toStringAsFixed(1)}MB)',
            );
            failedPhotos.add('${photo.name} (zu groß)');
            continue;
          }

          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photo.path)}';
          // ✅ CRITICAL FIX: Use path.join() for cross-platform compatibility
          final filePath = path.join(photosDir.path, fileName);

          await file.copy(filePath);
          savedPaths.add(filePath);
          AppLogger.info('AddLogScreen', '✅ Photo saved: $fileName');
        } catch (e) {
          AppLogger.error(
            'AddLogScreen',
            '❌ Failed to save photo ${photo.name}: $e',
          );
          failedPhotos.add(photo.name);
        }
      }

      // ✅ REFACTORED: Einheitliche Messages
      if (mounted) {
        if (failedPhotos.isEmpty && savedPaths.isNotEmpty) {
          AppMessages.photoSaved(context, savedPaths.length);
        } else if (failedPhotos.isNotEmpty) {
          AppMessages.photoSavingPartialError(
            context,
            savedPaths.length,
            failedPhotos.length,
          );
        }
      }
    } catch (e) {
      AppLogger.error('AddLogScreen', '❌ Critical error: $e');
      if (mounted) {
        AppMessages.photoSavingError(context, e.toString());
      }
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

  bool get _showPhEc =>
      _selectedAction == ActionType.water || _selectedAction == ActionType.feed;
  bool get _showPhEcOut =>
      _showPhEc && widget.plant.medium.needsRunoffMeasurement;
  bool get _showFlags =>
      widget.plant.medium.needsRunoffFlags &&
      (_selectedAction == ActionType.water ||
          _selectedAction == ActionType.feed);
  bool get _showEnvironment => true;
  bool get _showContainerFields => _selectedAction == ActionType.transplant;
  bool get _showFertilizers => _selectedAction == ActionType.feed;
  bool get _isHydroSystem =>
      widget.plant.medium == Medium.dwc ||
      widget.plant.medium == Medium.rdwc ||
      widget.plant.medium == Medium.hydro;

  Future<void> _saveLog() async {
    // ✅ FIX: Prevent double-tap by checking loading state first
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedAction == ActionType.phaseChange && _selectedPhase == null) {
      AppMessages.validationError(context, 'Phase');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final photoPaths = await _savePhotos();

      if (widget.bulkMode && widget.bulkPlantIds != null) {
        await _saveBulkLog(photoPaths);
        return;
      }

      final log = PlantLog(
        plantId: widget.plant.id!,
        dayNumber: _nextDayNumber,
        logDate: _selectedDate,
        actionType: _selectedAction,
        waterAmount: _waterAmountController.text.isNotEmpty
            ? double.tryParse(_waterAmountController.text)
            : null,
        phIn: _phInController.text.isNotEmpty
            ? double.tryParse(_phInController.text)
            : null,
        ecIn: _ecInController.text.isNotEmpty
            ? double.tryParse(_ecInController.text)
            : null,
        phOut: _phOutController.text.isNotEmpty
            ? double.tryParse(_phOutController.text)
            : null,
        ecOut: _ecOutController.text.isNotEmpty
            ? double.tryParse(_ecOutController.text)
            : null,
        temperature: _temperatureController.text.isNotEmpty
            ? double.tryParse(_temperatureController.text)
            : null,
        humidity: _humidityController.text.isNotEmpty
            ? double.tryParse(_humidityController.text)
            : null,
        runoff: _runoff,
        cleanse: _cleanse,
        containerSize: _containerSizeController.text.isNotEmpty
            ? double.tryParse(_containerSizeController.text)
            : null,
        containerMediumAmount: _containerMediumAmountController.text.isNotEmpty
            ? double.tryParse(_containerMediumAmountController.text)
            : null,
        containerDrainage: _containerDrainage,
        containerDrainageMaterial:
            _containerDrainageMaterialController.text.isNotEmpty
            ? _containerDrainageMaterialController.text
            : null,
        systemReservoirSize: _systemReservoirSizeController.text.isNotEmpty
            ? double.tryParse(_systemReservoirSizeController.text)
            : null,
        systemBucketCount: _systemBucketCountController.text.isNotEmpty
            ? int.tryParse(_systemBucketCountController.text)
            : null,
        systemBucketSize: _systemBucketSizeController.text.isNotEmpty
            ? double.tryParse(_systemBucketSizeController.text)
            : null,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
      );

      await _logService.saveSingleLog(
        plant: widget.plant,
        log: log,
        fertilizers: _selectedFertilizers,
        photoPaths: photoPaths,
        newPhase: _selectedPhase,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('AddLogScreen', 'Error saving: $e');
      if (mounted) {
        // ✅ Bessere Fehlermeldung bei Validierungs-Fehlern
        String errorMsg = e.toString();
        if (errorMsg.contains('ArgumentError:')) {
          errorMsg = errorMsg.replaceAll('ArgumentError:', '').trim();
        } else if (errorMsg.contains('Exception:')) {
          errorMsg = errorMsg.replaceAll('Exception:', '').trim();
        }
        AppMessages.savingError(context, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveBulkLog(List<String> photoPaths) async {
    try {
      await _logService.saveBulkLog(
        plantIds: widget.bulkPlantIds!,
        logDate: _selectedDate,
        actionType: _selectedAction,
        waterAmount: _waterAmountController.text.isNotEmpty
            ? double.tryParse(_waterAmountController.text)
            : null,
        phIn: _phInController.text.isNotEmpty
            ? double.tryParse(_phInController.text)
            : null,
        ecIn: _ecInController.text.isNotEmpty
            ? double.tryParse(_ecInController.text)
            : null,
        phOut: _phOutController.text.isNotEmpty
            ? double.tryParse(_phOutController.text)
            : null,
        ecOut: _ecOutController.text.isNotEmpty
            ? double.tryParse(_ecOutController.text)
            : null,
        temperature: _temperatureController.text.isNotEmpty
            ? double.tryParse(_temperatureController.text)
            : null,
        humidity: _humidityController.text.isNotEmpty
            ? double.tryParse(_humidityController.text)
            : null,
        runoff: _runoff,
        cleanse: _cleanse,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        fertilizers: _selectedFertilizers,
        photoPaths: photoPaths,
        newPhase: _selectedPhase,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('AddLogScreen', 'Error in bulk save: $e');
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<PlantPhase?> _showPhaseDialog() async {
    return await showDialog<PlantPhase>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppTranslations(
            Localizations.localeOf(context).languageCode,
          )['select_phase'],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PlantPhase.values.map((phase) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _getPhaseColor(phase),
                child: Text(
                  phase.prefix,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(phase.displayName),
              subtitle: Text(_getPhaseDescription(phase)),
              onTap: () => Navigator.of(context).pop(phase),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  String _getPhaseDescription(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return 'Keimling / Sämling';
      case PlantPhase.veg:
        return 'Vegetatives Wachstum';
      case PlantPhase.bloom:
        return 'Blüte';
      case PlantPhase.harvest:
        return 'Ernte';
      case PlantPhase.archived:
        return 'Archiviert';
    }
  }

  // ✅ FIX: Replace all force unwraps with null-aware operators
  Color _getPhaseColor(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return Colors.green[300] ?? Colors.green;
      case PlantPhase.veg:
        return Colors.green[600] ?? Colors.green;
      case PlantPhase.bloom:
        return Colors.purple[400] ?? Colors.purple;
      case PlantPhase.harvest:
        return Colors.orange[600] ?? Colors.orange;
      case PlantPhase.archived:
        return Colors.grey[600] ?? Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bulkMode
        ? 'Massen-Log (${widget.bulkPlantIds?.length ?? 0} Pflanzen)'
        : 'Log für ${widget.plant.name}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: widget.bulkMode ? Colors.blue[700] : Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          if (!widget.bulkMode)
            IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: _copyLastLog,
              tooltip: 'Letzten Log kopieren',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.bulkMode) _buildBulkModeWarning(),
                  _buildDayNumberCard(),
                  const SizedBox(height: 16),
                  _buildActionTypeSelector(),
                  const SizedBox(height: 16),
                  _buildDatePicker(),

                  const SizedBox(height: 24),
                  _buildPhotoSection(),

                  const SizedBox(height: 24),

                  if (_showContainerFields) ...[
                    if (_isHydroSystem)
                      _buildSystemFields()
                    else
                      _buildContainerFields(),
                    const SizedBox(height: 24),
                  ],

                  if (_selectedAction == ActionType.water ||
                      _selectedAction == ActionType.feed) ...[
                    _buildWaterSection(),
                    if (_showFertilizers) ...[
                      const SizedBox(height: 16),
                      _buildFertilizerSection(),
                    ],
                    if (_showPhEc) ...[
                      const SizedBox(height: 16),
                      _buildPhEcSection(),
                    ],
                    if (_showFlags) ...[
                      const SizedBox(height: 16),
                      _buildFlagsSection(),
                    ],
                  ],

                  if (_showEnvironment) ...[
                    const SizedBox(height: 16),
                    _buildEnvironmentSection(),
                  ],
                  const SizedBox(height: 16),
                  _buildNoteSection(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildBulkModeWarning() {
    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.blue[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Massen-Log Modus',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dieser Log wird für ${widget.bulkPlantIds?.length ?? 0} Pflanzen gleichzeitig gespeichert.',
                    style: TextStyle(fontSize: 12, color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayNumberCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.grey[850]
        : (widget.bulkMode ? Colors.blue[50] : Colors.green[50]);

    // Berechne Phase-Tag-Nummer basierend auf ausgewähltem Datum
    int phaseDayNumber = 1;
    if (widget.plant.phaseStartDate != null) {
      final phaseDay = DateTime(
        widget.plant.phaseStartDate!.year,
        widget.plant.phaseStartDate!.month,
        widget.plant.phaseStartDate!.day,
      );
      final selectedDay = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      phaseDayNumber = selectedDay.difference(phaseDay).inDays + 1;
      if (phaseDayNumber < 1) phaseDayNumber = 1;
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.green[700]),
                const SizedBox(width: 12),
                // ✅ PROMINENT: Phase-Tag
                Text(
                  '[${widget.plant.phase.prefix}$phaseDayNumber] ${widget.plant.phase.displayName}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ✅ KLEIN: Gesamt-Tag
                    Text(
                      'Gesamt: Tag $_nextDayNumber',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      widget.plant.medium.displayName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
            // ✅ Info-Box für nachträgliches Logging
            if (widget.plant.seedDate != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200] ?? Colors.blue),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Du kannst auch alte Logs nachträglich erstellen. Ändere einfach das Datum - der Tag wird automatisch berechnet!',
                        style: TextStyle(color: Colors.blue[900], fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            if (!widget.bulkMode) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyLastLog,
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text('Letzten Log kopieren'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[300] ?? Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktion',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ActionType.values.map((action) {
            final isSelected = _selectedAction == action;
            return ChoiceChip(
              label: Text(action.displayName),
              selected: isSelected,
              onSelected: (selected) async {
                if (action == ActionType.phaseChange) {
                  final newPhase = await _showPhaseDialog();
                  if (newPhase != null) {
                    setState(() {
                      _selectedAction = action;
                      _selectedPhase = newPhase;
                    });
                  }
                } else {
                  setState(() {
                    _selectedAction = action;
                    _selectedPhase = null;
                  });
                }
              },
              selectedColor: Colors.green[600],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            );
          }).toList(),
        ),
        if (_selectedAction == ActionType.phaseChange &&
            _selectedPhase != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPhaseColor(_selectedPhase!).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getPhaseColor(_selectedPhase!),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getPhaseColor(_selectedPhase!),
                  radius: 16,
                  child: Text(
                    _selectedPhase!.prefix,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Neue Phase',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        _selectedPhase!.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getPhaseColor(_selectedPhase!),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final newPhase = await _showPhaseDialog();
                    if (newPhase != null) {
                      setState(() => _selectedPhase = newPhase);
                    }
                  },
                  tooltip: 'Phase ändern',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ✅ BUG #7 FIX: Datum nur bis heute
  Widget _buildDatePicker() {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    // ✅ Validierung prüfen
    final dateWarning = widget.plant.seedDate != null
        ? Validators.validateLogDate(
            logDate: _selectedDate,
            seedDate: widget.plant.seedDate,
            phaseStartDate: widget.plant.phaseStartDate,
          )
        : null;

    return Column(
      children: [
        ListTile(
          leading: Icon(Icons.access_time, color: Colors.grey[700]),
          title: const Text('Datum & Uhrzeit'),
          subtitle: Text(dateFormat.format(_selectedDate)),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate:
                  widget.plant.seedDate ??
                  DateTime(2020), // ✅ Nicht vor seedDate!
              lastDate: DateTime.now(), // ✅ BUG #7 FIX: Nur bis heute
            );
            if (date != null && mounted) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDate),
              );
              if (time != null && mounted) {
                setState(() {
                  _selectedDate = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
                // Day Number neu berechnen für neues Datum!
                _loadNextDayNumber();
              }
            }
          },
        ),
        // ✅ Warnung anzeigen falls Datum problematisch
        if (dateWarning != null)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[300] ?? Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateWarning,
                    style: TextStyle(color: Colors.orange[900], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              'Fotos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showPhotoSourceDialog,
              icon: const Icon(Icons.add_a_photo),
              label: Text(
                AppTranslations(
                  Localizations.localeOf(context).languageCode,
                )['add_photo'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedPhotos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.grey[700] ?? Colors.grey
                    : Colors.grey[300] ?? Colors.grey,
                width: 2,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keine Fotos hinzugefügt',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppTranslations(
                      Localizations.localeOf(context).languageCode,
                    )['tap_to_add_photos'],
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedPhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(File(_selectedPhotos[index].path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildWaterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wasser',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _waterAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Menge (Liter)',
            prefixIcon: Icon(Icons.water_drop, color: Colors.blue[600]),
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 0.1, max: 1000.0),
        ),
      ],
    );
  }

  Widget _buildFertilizerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Dünger',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddFertilizerDialog,
              icon: const Icon(Icons.add),
              label: Text(
                AppTranslations(
                  Localizations.localeOf(context).languageCode,
                )['add_photo'],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFertilizers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300] ?? Colors.grey),
            ),
            child: Row(
              children: [
                Icon(Icons.science, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Text(
                  'Keine Dünger ausgewählt',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
        else
          ..._selectedFertilizers.entries.map((entry) {
            // ✅ SAFETY: orElse prevents crash if fertilizer was deleted
            final fertilizer = _availableFertilizers.firstWhere(
              (f) => f.id == entry.key,
              orElse: () => Fertilizer(
                id: entry.key,
                name: 'Gelöschter Dünger #${entry.key}',
              ),
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[600],
                  child: const Icon(
                    Icons.science,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(fertilizer.name),
                subtitle: Text('${entry.value.toStringAsFixed(1)} ml'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedFertilizers.remove(entry.key);
                    });
                  },
                ),
                onTap: () => _editFertilizerAmount(entry.key, entry.value),
              ),
            );
          }),
      ],
    );
  }

  void _showAddFertilizerDialog() {
    if (_availableFertilizers.isEmpty) {
      AppMessages.showInfo(
        context,
        'Keine Dünger verfügbar. Erstelle erst Dünger!',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppTranslations(
              Localizations.localeOf(context).languageCode,
            )['add_fertilizer'],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _availableFertilizers.length,
              itemBuilder: (context, index) {
                final fertilizer = _availableFertilizers[index];
                final isSelected = _selectedFertilizers.containsKey(
                  fertilizer.id,
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Colors.green[600]
                        : Colors.grey[400],
                    child: Icon(
                      isSelected ? Icons.check : Icons.science,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(fertilizer.name),
                  subtitle: fertilizer.npk != null
                      ? Text('NPK: ${fertilizer.npk}')
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _addFertilizer(fertilizer);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );
  }

  // ✅ FIX: Made async to properly await dialog and dispose controller
  Future<void> _addFertilizer(Fertilizer fertilizer) async {
    if (fertilizer.id == null) {
      AppMessages.showError(context, 'Fehler: Dünger hat keine gültige ID');
      return;
    }

    final amountController = TextEditingController(text: '10');

    // ✅ FIX: Wrap in try-finally to ensure controller disposal
    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(fertilizer.name),
            content: TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Menge (ml)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0) {
                    setState(() {
                      _selectedFertilizers[fertilizer.id!] = amount;
                    });
                    Navigator.of(context).pop();
                  }
                },
                child: Text(
                  AppTranslations(
                    Localizations.localeOf(context).languageCode,
                  )['add_photo'],
                ),
              ),
            ],
          );
        },
      );
    } finally {
      // ✅ FIX: Dispose controller to prevent memory leak
      amountController.dispose();
    }
  }

  // ✅ FIX: Made async to properly await dialog and dispose controller
  Future<void> _editFertilizerAmount(
    int fertilizerId,
    double currentAmount,
  ) async {
    final amountController = TextEditingController(
      text: currentAmount.toStringAsFixed(1),
    );

    // ✅ SAFETY: Handle deleted fertilizer gracefully
    final fertilizer = _availableFertilizers.firstWhere(
      (f) => f.id == fertilizerId,
      orElse: () => Fertilizer(
        id: fertilizerId,
        name: 'Gelöschter Dünger #$fertilizerId',
      ),
    );

    // ✅ FIX: Wrap in try-finally to ensure controller disposal
    try {
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(fertilizer.name),
            content: TextFormField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Menge (ml)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0) {
                    setState(() {
                      _selectedFertilizers[fertilizerId] = amount;
                    });
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      );
    } finally {
      // ✅ FIX: Dispose controller to prevent memory leak
      amountController.dispose();
    }
  }

  Widget _buildPhEcSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'pH & EC Werte',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phInController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'pH In',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Validators.validatePH(value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _ecInController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'EC In',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Validators.validateEC(value),
              ),
            ),
          ],
        ),
        if (_showPhEcOut) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phOutController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'pH Out',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => Validators.validatePH(value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _ecOutController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'EC Out',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => Validators.validateEC(value),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFlagsSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Runoff'),
          subtitle: const Text('Abfluss/Drainage gemessen'),
          value: _runoff,
          onChanged: (value) => setState(() => _runoff = value),
          activeThumbColor: Colors.green[600],
        ),
        SwitchListTile(
          title: const Text('Cleanse'),
          subtitle: Text(
            AppTranslations(
              Localizations.localeOf(context).languageCode,
            )['cleanse_subtitle'],
          ),
          value: _cleanse,
          onChanged: (value) => setState(() => _cleanse = value),
          activeThumbColor: Colors.blue[600],
        ),
      ],
    );
  }

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Umgebung (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _temperatureController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Temperatur (°C)',
                  prefixIcon: Icon(Icons.thermostat),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Validators.validateTemperature(value),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _humidityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Luftfeuchte (%)',
                  prefixIcon: Icon(Icons.water_damage),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Validators.validateHumidity(value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notizen',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _noteController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: AppTranslations(
              Localizations.localeOf(context).languageCode,
            )['notes_hint'],
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildContainerFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Container / Topf',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _containerSizeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Topfgröße (Liter) *',
            hintText: 'z.B. 11',
            prefixIcon: Icon(Icons.local_florist, color: Colors.brown[600]),
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 0.5, max: 500.0),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _containerMediumAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Medium-Menge (Liter)',
            hintText: 'z.B. 10',
            prefixIcon: Icon(Icons.grass, color: Colors.green[700]),
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 0.1, max: 500.0),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Drainage'),
          subtitle: const Text('Drainageschicht vorhanden?'),
          value: _containerDrainage,
          onChanged: (value) => setState(() => _containerDrainage = value),
          activeThumbColor: Colors.green[600],
        ),
        if (_containerDrainage) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _containerDrainageMaterialController,
            decoration: InputDecoration(
              labelText: 'Drainage-Material',
              hintText: 'z.B. Blähton, Perlite, Kies',
              prefixIcon: Icon(Icons.layers, color: Colors.grey[600]),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System (RDWC/DWC/Hydro)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _systemReservoirSizeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Reservoir Größe (Liter) *',
            hintText: 'z.B. 100',
            prefixIcon: Icon(Icons.water, color: Colors.blue[600]),
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 1.0, max: 10000.0),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _systemBucketCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Anzahl Buckets',
                  hintText: 'z.B. 4',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    Validators.validateInteger(value, min: 1, max: 100),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _systemBucketSizeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Bucket-Größe (L)',
                  hintText: 'z.B. 15',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => Validators.validatePositiveNumber(
                  value,
                  min: 1.0,
                  max: 200.0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveLog,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: const Text('Log speichern'),
    );
  }
}
