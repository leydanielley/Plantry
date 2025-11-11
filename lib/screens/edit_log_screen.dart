// =============================================
// GROWLOG - Edit Log Screen (MIT FOTOS!)
// ✅ AUDIT FIX: i18n extraction
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/log_fertilizer.dart';
import 'package:growlog_app/models/photo.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_log_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/translations.dart'; // ✅ AUDIT FIX: i18n
import 'package:growlog_app/utils/storage_helper.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';

class EditLogScreen extends StatefulWidget {
  final Plant plant;
  final PlantLog log;

  const EditLogScreen({super.key, required this.plant, required this.log});

  @override
  State<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends State<EditLogScreen> {
  late AppTranslations _t; // ✅ AUDIT FIX: i18n
  bool _translationsInitialized = false;
  final _formKey = GlobalKey<FormState>();
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ILogFertilizerRepository _logFertilizerRepo =
      getIt<ILogFertilizerRepository>();
  final IPhotoRepository _photoRepo = getIt<IPhotoRepository>();
  final ImagePicker _imagePicker = ImagePicker();

  // Form Controllers
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

  // State variables
  late ActionType _selectedAction;
  late DateTime _selectedDate;
  late bool _runoff;
  late bool _cleanse;
  late bool _containerDrainage;
  bool _isLoading = false;
  late int _dayNumber;
  List<Fertilizer> _availableFertilizers = [];
  Map<int, double> _selectedFertilizers = {};

  // Photo handling
  List<Photo> _existingPhotos = [];
  final List<XFile> _newPhotos = [];
  final Set<int> _photosToDelete = {};

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _loadFertilizers();
    _loadExistingPhotos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_translationsInitialized) {
      _t = AppTranslations(
        Localizations.localeOf(context).languageCode,
      ); // ✅ AUDIT FIX: i18n - moved from initState
      _translationsInitialized = true;
    }
  }

  Future<void> _loadExistingData() async {
    setState(() {
      _selectedAction = widget.log.actionType;
      _selectedDate = widget.log.logDate;
      _dayNumber = widget.log.dayNumber;
      _runoff = widget.log.runoff;
      _cleanse = widget.log.cleanse;
      _containerDrainage = widget.log.containerDrainage;

      _waterAmountController.text =
          widget.log.waterAmount?.toStringAsFixed(1) ?? '';
      _phInController.text = widget.log.phIn?.toStringAsFixed(1) ?? '';
      _ecInController.text = widget.log.ecIn?.toStringAsFixed(1) ?? '';
      _phOutController.text = widget.log.phOut?.toStringAsFixed(1) ?? '';
      _ecOutController.text = widget.log.ecOut?.toStringAsFixed(1) ?? '';
      _temperatureController.text =
          widget.log.temperature?.toStringAsFixed(1) ?? '';
      _humidityController.text = widget.log.humidity?.toStringAsFixed(0) ?? '';
      _noteController.text = widget.log.note ?? '';
      _containerSizeController.text =
          widget.log.containerSize?.toStringAsFixed(0) ?? '';
      _containerMediumAmountController.text =
          widget.log.containerMediumAmount?.toStringAsFixed(1) ?? '';
      _containerDrainageMaterialController.text =
          widget.log.containerDrainageMaterial ?? '';
      _systemReservoirSizeController.text =
          widget.log.systemReservoirSize?.toStringAsFixed(0) ?? '';
      _systemBucketCountController.text =
          widget.log.systemBucketCount?.toString() ?? '';
      _systemBucketSizeController.text =
          widget.log.systemBucketSize?.toStringAsFixed(0) ?? '';
    });

    if (widget.log.id != null) {
      final logFerts = await _logFertilizerRepo.findByLog(widget.log.id!);
      // ✅ FIX 1: Mounted check vor setState!
      if (mounted) {
        setState(() {
          _selectedFertilizers = {
            for (final lf in logFerts) lf.fertilizerId: lf.amount,
          };
        });
      }
    }
  }

  Future<void> _loadExistingPhotos() async {
    if (widget.log.id != null) {
      final photos = await _photoRepo.getPhotosByLogId(widget.log.id!);
      // ✅ FIX 1: Mounted check vor setState!
      if (mounted) {
        setState(() {
          _existingPhotos = photos;
        });
      }
    }
  }

  Future<void> _loadFertilizers() async {
    try {
      final fertilizers = await _fertilizerRepo.findAll();
      // ✅ FIX 1: Mounted check vor setState!
      if (mounted) {
        setState(() => _availableFertilizers = fertilizers);
      }
    } catch (e) {
      // Error loading fertilizers
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
              _t['edit_log_invalid_file_type'], // ✅ i18n
            );
          }
          return;
        }

        if (mounted) {
          // ✅ FIX 1: Mounted check vor setState!
          setState(() {
            _newPhotos.add(photo);
          });
        }
      }
    } catch (e) {
      // Error picking photo
    }
  }

  Future<void> _showPhotoSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (dialogContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(_t['camera']), // ✅ i18n
              onTap: () {
                // ✅ Mounted check für höchste Sicherheit
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(_t['gallery']), // ✅ i18n
              onTap: () {
                // ✅ Mounted check für höchste Sicherheit
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeNewPhoto(int index) {
    // ✅ FIX 1: Mounted check vor setState!
    if (mounted) {
      setState(() {
        _newPhotos.removeAt(index);
      });
    }
  }

  void _markExistingPhotoForDeletion(int photoId) {
    // ✅ FIX 1: Mounted check vor setState!
    if (mounted) {
      setState(() {
        if (_photosToDelete.contains(photoId)) {
          _photosToDelete.remove(photoId);
        } else {
          _photosToDelete.add(photoId);
        }
      });
    }
  }

  Future<List<String>> _saveNewPhotos() async {
    final List<String> savedPaths = [];

    try {
      // ✅ CRITICAL FIX: Check storage before saving photos
      final totalSize = _newPhotos.fold<int>(0, (sum, photo) {
        try {
          return sum + File(photo.path).lengthSync();
        } catch (e) {
          return sum;
        }
      });

      // Check if we have enough storage (photos + 50MB buffer)
      final hasSpace = await StorageHelper.hasEnoughStorage(
        bytesNeeded: totalSize + 50 * 1024 * 1024,
      );
      if (!hasSpace) {
        AppLogger.error('EditLogScreen', '❌ Insufficient storage for photos');
        throw Exception('Insufficient storage');
      }

      final directory = await getApplicationDocumentsDirectory();
      // ✅ FIX: Use path.join for cross-platform compatibility
      final photosDir = Directory(path.join(directory.path, 'photos'));

      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      for (final photo in _newPhotos) {
        // ✅ FIX: Validate file size (max 10MB per photo)
        final fileSize = await File(photo.path).length();
        if (fileSize > 10 * 1024 * 1024) {
          AppLogger.warning(
            'EditLogScreen',
            'Photo too large, skipping: ${photo.path}',
          );
          continue;
        }

        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photo.path)}';
        // ✅ FIX: Use path.join for cross-platform compatibility
        final filePath = path.join(photosDir.path, fileName);

        await File(photo.path).copy(filePath);
        savedPaths.add(filePath);
      }
    } catch (e) {
      AppLogger.error('EditLogScreen', 'Error saving photos', e);
      // Re-throw to notify caller of failure
      rethrow;
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPhotoPaths = await _saveNewPhotos();

      final updatedLog = widget.log.copyWith(
        dayNumber: _dayNumber, // ✅ Nutze neu berechneten dayNumber!
        actionType: _selectedAction,
        logDate: _selectedDate,
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

      await _logRepo.save(updatedLog);

      await _logFertilizerRepo.deleteByLog(widget.log.id!);
      if (_selectedFertilizers.isNotEmpty) {
        final logFertilizers = _selectedFertilizers.entries.map((entry) {
          return LogFertilizer(
            logId: widget.log.id!,
            fertilizerId: entry.key,
            amount: entry.value,
            unit: 'ml',
          );
        }).toList();

        await _logFertilizerRepo.saveForLog(widget.log.id!, logFertilizers);
      }

      for (final photoId in _photosToDelete) {
        // ✅ FIX: Add orElse to prevent StateError crash
        final photo = _existingPhotos.firstWhere(
          (p) => p.id == photoId,
          orElse: () => throw Exception('Photo not found: $photoId'),
        );
        final file = File(photo.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        await _photoRepo.deletePhoto(photoId);
      }

      for (final photoPath in newPhotoPaths) {
        final photo = Photo(logId: widget.log.id!, filePath: photoPath);
        await _photoRepo.save(photo);
      }

      if (_selectedAction == ActionType.transplant) {
        final updatedPlant = widget.plant.copyWith(
          currentContainerSize: _containerSizeController.text.isNotEmpty
              ? double.tryParse(_containerSizeController.text)
              : null,
          currentSystemSize: _systemReservoirSizeController.text.isNotEmpty
              ? double.tryParse(_systemReservoirSizeController.text)
              : null,
        );
        await _plantRepo.save(updatedPlant);
      }

      if (_selectedAction == ActionType.phaseChange && mounted) {
        final newPhase = await showDialog<PlantPhase>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t['edit_log_select_new_phase']), // ✅ i18n
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
                  onTap: () => Navigator.of(context).pop(phase),
                );
              }).toList(),
            ),
          ),
        );

        if (newPhase != null) {
          final updatedPlant = widget.plant.copyWith(
            phase: newPhase,
            phaseStartDate: _selectedDate,
          );
          await _plantRepo.save(updatedPlant);
        }
      }

      if (mounted) {
        AppMessages.updatedSuccessfully(context, 'Log');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Error saving
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      // ✅ FIX 1: Mounted check vor setState!
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _t['edit_log_title'].replaceAll('{plant}', widget.plant.name),
        ), // ✅ i18n
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoCard(),
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

  Widget _buildInfoCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.edit, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t['edit_log_day_info'].replaceAll('{day}', '$_dayNumber'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ), // ✅ i18n
                  Text(
                    _t['edit_log_created_at'].replaceAll(
                      '{date}',
                      DateFormat(
                        'dd.MM.yyyy HH:mm',
                      ).format(widget.log.createdAt),
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ), // ✅ i18n
                ],
              ),
            ),
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
          _t['action'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ), // ✅ i18n
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ActionType.values.map((action) {
            final isSelected = _selectedAction == action;
            return ChoiceChip(
              label: Text(action.displayName),
              selected: isSelected,
              onSelected: (selected) =>
                  setState(() => _selectedAction = action),
              selectedColor: Colors.orange[600],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
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
          title: Text(_t['date_time']), // ✅ i18n
          subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(_selectedDate)),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate:
                  widget.plant.seedDate ??
                  DateTime(2020), // ✅ Nicht vor seedDate!
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (date != null && mounted) {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_selectedDate),
              );
              if (time != null && mounted) {
                final newDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
                // Day Number neu berechnen für neues Datum!
                final newDayNumber = await _logRepo.getNextDayNumber(
                  widget.plant.id!,
                  forDate: newDate,
                );
                if (mounted) {
                  setState(() {
                    _selectedDate = newDate;
                    _dayNumber = newDayNumber;
                  });
                }
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
    final totalPhotos =
        _existingPhotos.length - _photosToDelete.length + _newPhotos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text(
              _t['edit_log_photos_count'].replaceAll('{count}', '$totalPhotos'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ), // ✅ i18n
            const Spacer(),
            TextButton.icon(
              onPressed: _showPhotoSourceDialog,
              icon: const Icon(Icons.add_a_photo),
              label: Text(_t['add_photo']),
            ), // ✅ i18n
          ],
        ),
        const SizedBox(height: 12),
        if (_existingPhotos.isNotEmpty) ...[
          Text(
            _t['edit_log_existing_photos'],
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ), // ✅ i18n
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _existingPhotos.length,
              itemBuilder: (context, index) {
                final photo = _existingPhotos[index];
                final isMarkedForDeletion = _photosToDelete.contains(photo.id);

                return Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: isMarkedForDeletion
                            ? Border.all(color: Colors.red, width: 3)
                            : null,
                      ),
                      child: Opacity(
                        opacity: isMarkedForDeletion ? 0.3 : 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(photo.filePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _markExistingPhotoForDeletion(photo.id!),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isMarkedForDeletion
                                ? Colors.orange
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isMarkedForDeletion ? Icons.undo : Icons.delete,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    if (isMarkedForDeletion)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _t['edit_log_marked_for_deletion'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ), // ✅ i18n
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_newPhotos.isNotEmpty) ...[
          Text(
            _t['edit_log_new_photos'],
            style: TextStyle(fontSize: 12, color: Colors.green[700]),
          ), // ✅ i18n
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _newPhotos.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green, width: 2),
                        image: DecorationImage(
                          image: FileImage(File(_newPhotos[index].path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeNewPhoto(index),
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
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _t['edit_log_new_badge'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ), // ✅ i18n
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        if (_existingPhotos.isEmpty && _newPhotos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300] ?? Colors.grey),
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
                    _t['edit_log_no_photos'],
                    style: TextStyle(color: Colors.grey[600]),
                  ), // ✅ i18n
                ],
              ),
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
          _t['container_pot'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ), // ✅ i18n
        const SizedBox(height: 12),
        TextFormField(
          controller: _containerSizeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _t['pot_size_liter'],
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 0.5, max: 500.0),
        ), // ✅ i18n
        const SizedBox(height: 12),
        TextFormField(
          controller: _containerMediumAmountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _t['medium_amount_liter'],
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 0.1, max: 500.0),
        ), // ✅ i18n
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(_t['drainage']),
          value: _containerDrainage,
          onChanged: (value) => setState(() => _containerDrainage = value),
        ), // ✅ i18n
        if (_containerDrainage) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _containerDrainageMaterialController,
            decoration: InputDecoration(
              labelText: _t['drainage_material'],
              border: const OutlineInputBorder(),
            ),
          ),
        ], // ✅ i18n
      ],
    );
  }

  Widget _buildSystemFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['system_rdwc_dwc_hydro'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ), // ✅ i18n
        const SizedBox(height: 12),
        TextFormField(
          controller: _systemReservoirSizeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _t['reservoir_size_liter'],
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validatePositiveNumber(value, min: 1.0, max: 10000.0),
        ), // ✅ i18n
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _systemBucketCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _t['bucket_count'],
                  border: const OutlineInputBorder(),
                ),
                validator: (value) =>
                    Validators.validateInteger(value, min: 1, max: 100),
              ),
            ), // ✅ i18n
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _systemBucketSizeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['bucket_size_liter'],
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => Validators.validatePositiveNumber(
                  value,
                  min: 1.0,
                  max: 200.0,
                ),
              ),
            ), // ✅ i18n
          ],
        ),
      ],
    );
  }

  Widget _buildWaterSection() => TextFormField(
    controller: _waterAmountController,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: _t['amount_liter'],
      border: const OutlineInputBorder(),
    ),
    validator: (value) =>
        Validators.validatePositiveNumber(value, min: 0.1, max: 1000.0),
  ); // ✅ i18n

  Widget _buildFertilizerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _t['fertilizers'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ), // ✅ i18n
            const Spacer(),
            TextButton.icon(
              onPressed: _showAddFertilizerDialog,
              icon: const Icon(Icons.add),
              label: Text(_t['add_photo']),
            ), // ✅ i18n (reusing add_photo = "Hinzufügen")
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
            child: Text(
              _t['no_fertilizers_selected'],
              style: TextStyle(color: Colors.grey[600]),
            ),
          ) // ✅ i18n
        else
          ..._selectedFertilizers.entries.map((entry) {
            // ✅ FIX: Add orElse to prevent StateError crash
            final fertilizer = _availableFertilizers.firstWhere(
              (f) => f.id == entry.key,
              orElse: () => Fertilizer(
                id: entry.key,
                name: _t['edit_log_unknown_fertilizer'], // ✅ i18n
                createdAt: DateTime.now(),
              ),
            );
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(fertilizer.name),
                subtitle: Text('${entry.value.toStringAsFixed(1)} ml'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () =>
                      setState(() => _selectedFertilizers.remove(entry.key)),
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
        _t['edit_log_no_fertilizers_available'],
      ); // ✅ i18n
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['add_fertilizer']), // ✅ i18n
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableFertilizers.length,
            itemBuilder: (context, index) {
              final fertilizer = _availableFertilizers[index];
              return ListTile(
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
      ),
    );
  }

  // ✅ HIGH PRIORITY FIX: Made async to properly await dialog and dispose controller
  Future<void> _addFertilizer(Fertilizer fertilizer) async {
    // ✅ Extra Null-Check für Sicherheit
    if (fertilizer.id == null) {
      AppMessages.showError(
        context,
        _t['edit_log_fertilizer_no_id_error'],
      ); // ✅ i18n
      return;
    }

    final amountController = TextEditingController(text: '10');

    // ✅ HIGH PRIORITY FIX: Wrap in try-finally to ensure controller disposal
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(fertilizer.name),
          content: TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _t['amount_ml'],
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ), // ✅ i18n
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t['cancel']),
            ), // ✅ i18n
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  setState(() => _selectedFertilizers[fertilizer.id!] = amount);
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                _t['add_photo'],
              ), // ✅ i18n (reusing add_photo = "Hinzufügen")
            ),
          ],
        ),
      );
    } finally {
      // ✅ HIGH PRIORITY FIX: Dispose controller to prevent memory leak
      amountController.dispose();
    }
  }

  // ✅ HIGH PRIORITY FIX: Made async to properly await dialog
  Future<void> _editFertilizerAmount(
    int fertilizerId,
    double currentAmount,
  ) async {
    final amountController = TextEditingController(
      text: currentAmount.toStringAsFixed(1),
    );

    // ✅ HIGH PRIORITY FIX: Handle deleted fertilizer gracefully instead of throwing
    // ✅ BUG FIX: Replace hardcoded German string with i18n
    final fertilizer = _availableFertilizers.firstWhere(
      (f) => f.id == fertilizerId,
      orElse: () => Fertilizer(
        id: fertilizerId,
        name: _t['deleted_fertilizer_id'].replaceAll('{id}', '$fertilizerId'),
      ),
    );

    // ✅ HIGH PRIORITY FIX: Wrap in try-finally to ensure controller disposal
    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(fertilizer.name),
          content: TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _t['amount_ml'],
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ), // ✅ i18n
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_t['cancel']),
            ), // ✅ i18n
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  setState(() => _selectedFertilizers[fertilizerId] = amount);
                  Navigator.of(context).pop();
                }
              },
              child: Text(_t['save']), // ✅ i18n
            ),
          ],
        ),
      );
    } finally {
      // ✅ HIGH PRIORITY FIX: Dispose controller to prevent memory leak
      amountController.dispose();
    }
  }

  Widget _buildPhEcSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['ph_ec_values'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ), // ✅ i18n
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phInController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['ph_in'],
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => Validators.validatePH(value),
              ),
            ), // ✅ i18n
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _ecInController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['ec_in'],
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => Validators.validateEC(value),
              ),
            ), // ✅ i18n
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
                  decoration: InputDecoration(
                    labelText: _t['ph_out'],
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => Validators.validatePH(value),
                ),
              ), // ✅ i18n
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _ecOutController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _t['ec_out'],
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => Validators.validateEC(value),
                ),
              ), // ✅ i18n
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFlagsSection() => Column(
    children: [
      SwitchListTile(
        title: Text(_t['runoff']),
        value: _runoff,
        onChanged: (value) => setState(() => _runoff = value),
      ),
      SwitchListTile(
        title: Text(_t['cleanse']),
        value: _cleanse,
        onChanged: (value) => setState(() => _cleanse = value),
      ),
    ],
  ); // ✅ i18n

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['environment_optional'],
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ), // ✅ i18n
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _temperatureController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['temperature_celsius'],
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => Validators.validateTemperature(value),
              ),
            ), // ✅ i18n
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _humidityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['humidity_percent'],
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => Validators.validateHumidity(value),
              ),
            ), // ✅ i18n
          ],
        ),
      ],
    );
  }

  Widget _buildNoteSection() => TextFormField(
    controller: _noteController,
    maxLines: 4,
    decoration: InputDecoration(
      labelText: _t['notes'],
      hintText: _t['notes_hint'],
      border: const OutlineInputBorder(),
    ),
  ); // ✅ i18n

  Widget _buildSaveButton() => ElevatedButton(
    onPressed: _saveLog,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.orange[700],
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
    child: Text(
      _t['edit_log_save_changes'],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ), // ✅ i18n
  );
}
