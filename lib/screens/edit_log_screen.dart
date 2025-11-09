// =============================================
// GROWLOG - Edit Log Screen (MIT FOTOS!)
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/plant.dart';
import '../models/plant_log.dart';
import '../models/fertilizer.dart';
import '../models/log_fertilizer.dart';
import '../models/photo.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_plant_log_repository.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../repositories/interfaces/i_log_fertilizer_repository.dart';
import '../repositories/interfaces/i_photo_repository.dart';
import '../utils/validators.dart';
import '../di/service_locator.dart';

class EditLogScreen extends StatefulWidget {
  final Plant plant;
  final PlantLog log;

  const EditLogScreen({
    super.key,
    required this.plant,
    required this.log,
  });

  @override
  State<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends State<EditLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ILogFertilizerRepository _logFertilizerRepo = getIt<ILogFertilizerRepository>();
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

  Future<void> _loadExistingData() async {
    setState(() {
      _selectedAction = widget.log.actionType;
      _selectedDate = widget.log.logDate;
      _dayNumber = widget.log.dayNumber;
      _runoff = widget.log.runoff;
      _cleanse = widget.log.cleanse;
      _containerDrainage = widget.log.containerDrainage;

      _waterAmountController.text = widget.log.waterAmount?.toStringAsFixed(1) ?? '';
      _phInController.text = widget.log.phIn?.toStringAsFixed(1) ?? '';
      _ecInController.text = widget.log.ecIn?.toStringAsFixed(1) ?? '';
      _phOutController.text = widget.log.phOut?.toStringAsFixed(1) ?? '';
      _ecOutController.text = widget.log.ecOut?.toStringAsFixed(1) ?? '';
      _temperatureController.text = widget.log.temperature?.toStringAsFixed(1) ?? '';
      _humidityController.text = widget.log.humidity?.toStringAsFixed(0) ?? '';
      _noteController.text = widget.log.note ?? '';
      _containerSizeController.text = widget.log.containerSize?.toStringAsFixed(0) ?? '';
      _containerMediumAmountController.text = widget.log.containerMediumAmount?.toStringAsFixed(1) ?? '';
      _containerDrainageMaterialController.text = widget.log.containerDrainageMaterial ?? '';
      _systemReservoirSizeController.text = widget.log.systemReservoirSize?.toStringAsFixed(0) ?? '';
      _systemBucketCountController.text = widget.log.systemBucketCount?.toString() ?? '';
      _systemBucketSizeController.text = widget.log.systemBucketSize?.toStringAsFixed(0) ?? '';
    });

    if (widget.log.id != null) {
      final logFerts = await _logFertilizerRepo.findByLog(widget.log.id!);
      // ✅ FIX 1: Mounted check vor setState!
      if (mounted) {
        setState(() {
          _selectedFertilizers = {
            for (var lf in logFerts) lf.fertilizerId: lf.amount
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

      if (photo != null && mounted) {
        // ✅ FIX 1: Mounted check vor setState!
        setState(() {
          _newPhotos.add(photo);
        });
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
              title: const Text('Kamera'),
              onTap: () {
                // ✅ Mounted check für höchste Sicherheit
                if (!mounted) return;
                Navigator.pop(dialogContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
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
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');
      
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }

      for (var photo in _newPhotos) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photo.path)}';
        final filePath = '${photosDir.path}/$fileName';
        
        await File(photo.path).copy(filePath);
        savedPaths.add(filePath);
      }
    } catch (e) {
      // Error saving photos
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

  bool get _showPhEc => _selectedAction == ActionType.water || _selectedAction == ActionType.feed;
  bool get _showPhEcOut => _showPhEc && widget.plant.medium.needsRunoffMeasurement;
  bool get _showFlags => widget.plant.medium.needsRunoffFlags && 
           (_selectedAction == ActionType.water || _selectedAction == ActionType.feed);
  bool get _showEnvironment => true;
  bool get _showContainerFields => _selectedAction == ActionType.transplant;
  bool get _showFertilizers => _selectedAction == ActionType.feed;
  bool get _isHydroSystem => widget.plant.medium == Medium.dwc || 
           widget.plant.medium == Medium.rdwc || 
           widget.plant.medium == Medium.hydro;

  Future<void> _saveLog() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newPhotoPaths = await _saveNewPhotos();

      final updatedLog = widget.log.copyWith(
        dayNumber: _dayNumber,  // ✅ Nutze neu berechneten dayNumber!
        actionType: _selectedAction,
        logDate: _selectedDate,
        waterAmount: _waterAmountController.text.isNotEmpty ? double.tryParse(_waterAmountController.text) : null,
        phIn: _phInController.text.isNotEmpty ? double.tryParse(_phInController.text) : null,
        ecIn: _ecInController.text.isNotEmpty ? double.tryParse(_ecInController.text) : null,
        phOut: _phOutController.text.isNotEmpty ? double.tryParse(_phOutController.text) : null,
        ecOut: _ecOutController.text.isNotEmpty ? double.tryParse(_ecOutController.text) : null,
        temperature: _temperatureController.text.isNotEmpty ? double.tryParse(_temperatureController.text) : null,
        humidity: _humidityController.text.isNotEmpty ? double.tryParse(_humidityController.text) : null,
        runoff: _runoff,
        cleanse: _cleanse,
        containerSize: _containerSizeController.text.isNotEmpty ? double.tryParse(_containerSizeController.text) : null,
        containerMediumAmount: _containerMediumAmountController.text.isNotEmpty ? double.tryParse(_containerMediumAmountController.text) : null,
        containerDrainage: _containerDrainage,
        containerDrainageMaterial: _containerDrainageMaterialController.text.isNotEmpty ? _containerDrainageMaterialController.text : null,
        systemReservoirSize: _systemReservoirSizeController.text.isNotEmpty ? double.tryParse(_systemReservoirSizeController.text) : null,
        systemBucketCount: _systemBucketCountController.text.isNotEmpty ? int.tryParse(_systemBucketCountController.text) : null,
        systemBucketSize: _systemBucketSizeController.text.isNotEmpty ? double.tryParse(_systemBucketSizeController.text) : null,
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

      for (var photoId in _photosToDelete) {
        final photo = _existingPhotos.firstWhere((p) => p.id == photoId);
        final file = File(photo.filePath);
        if (await file.exists()) {
          await file.delete();
        }
        await _photoRepo.deletePhoto(photoId);
      }

      for (var photoPath in newPhotoPaths) {
        final photo = Photo(
          logId: widget.log.id!,
          filePath: photoPath,
        );
        await _photoRepo.save(photo);
      }

      if (_selectedAction == ActionType.transplant) {
        final updatedPlant = widget.plant.copyWith(
          currentContainerSize: _containerSizeController.text.isNotEmpty ? double.tryParse(_containerSizeController.text) : null,
          currentSystemSize: _systemReservoirSizeController.text.isNotEmpty ? double.tryParse(_systemReservoirSizeController.text) : null,
        );
        await _plantRepo.save(updatedPlant);
      }

      if (_selectedAction == ActionType.phaseChange && mounted) {
        final newPhase = await showDialog<PlantPhase>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Neue Phase wählen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: PlantPhase.values.map((phase) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getPhaseColor(phase),
                    child: Text(phase.prefix, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(phase.displayName),
                  onTap: () => Navigator.of(context).pop(phase),
                );
              }).toList(),
            ),
          ),
        );

        if (newPhase != null) {
          final updatedPlant = widget.plant.copyWith(phase: newPhase, phaseStartDate: _selectedDate);
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
      case PlantPhase.seedling: return Colors.green[300]!;
      case PlantPhase.veg: return Colors.green[600]!;
      case PlantPhase.bloom: return Colors.purple[400]!;
      case PlantPhase.harvest: return Colors.orange[600]!;
      case PlantPhase.archived: return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log bearbeiten - ${widget.plant.name}'),
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
                    if (_isHydroSystem) _buildSystemFields() else _buildContainerFields(),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedAction == ActionType.water || _selectedAction == ActionType.feed) ...[
                    _buildWaterSection(),
                    if (_showFertilizers) ...[const SizedBox(height: 16), _buildFertilizerSection()],
                    if (_showPhEc) ...[const SizedBox(height: 16), _buildPhEcSection()],
                    if (_showFlags) ...[const SizedBox(height: 16), _buildFlagsSection()],
                  ],
                  if (_showEnvironment) ...[const SizedBox(height: 16), _buildEnvironmentSection()],
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
                  Text('Tag $_dayNumber bearbeiten', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                  Text('Erstellt: ${DateFormat('dd.MM.yyyy HH:mm').format(widget.log.createdAt)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
        Text('Aktion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ActionType.values.map((action) {
            final isSelected = _selectedAction == action;
            return ChoiceChip(
              label: Text(action.displayName),
              selected: isSelected,
              onSelected: (selected) => setState(() => _selectedAction = action),
              selectedColor: Colors.orange[600],
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey[700]),
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
          title: const Text('Datum & Uhrzeit'),
          subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(_selectedDate)),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: widget.plant.seedDate ?? DateTime(2020),  // ✅ Nicht vor seedDate!
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (date != null && mounted) {
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
              if (time != null && mounted) {
                final newDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                // Day Number neu berechnen für neues Datum!
                final newDayNumber = await _logRepo.getNextDayNumber(widget.plant.id!, forDate: newDate);
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
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateWarning,
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final totalPhotos = _existingPhotos.length - _photosToDelete.length + _newPhotos.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Text('Fotos ($totalPhotos)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const Spacer(),
            TextButton.icon(onPressed: _showPhotoSourceDialog, icon: const Icon(Icons.add_a_photo), label: const Text('Hinzufügen')),
          ],
        ),
        const SizedBox(height: 12),
        if (_existingPhotos.isNotEmpty) ...[
          Text('Vorhandene Fotos:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                        border: isMarkedForDeletion ? Border.all(color: Colors.red, width: 3) : null,
                      ),
                      child: Opacity(
                        opacity: isMarkedForDeletion ? 0.3 : 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(photo.filePath), fit: BoxFit.cover),
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
                            color: isMarkedForDeletion ? Colors.orange : Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(isMarkedForDeletion ? Icons.undo : Icons.delete, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    if (isMarkedForDeletion)
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
                            child: const Text('Wird gelöscht', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
          Text('Neue Fotos:', style: TextStyle(fontSize: 12, color: Colors.green[700])),
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
                        image: DecorationImage(image: FileImage(File(_newPhotos[index].path)), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _removeNewPhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                        child: const Text('NEU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('Keine Fotos vorhanden', style: TextStyle(color: Colors.grey[600])),
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
        Text('Container / Topf', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 12),
        TextFormField(controller: _containerSizeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Topfgröße (Liter)', border: OutlineInputBorder()), validator: (value) => Validators.validatePositiveNumber(value, min: 0.5, max: 500.0)),
        const SizedBox(height: 12),
        TextFormField(controller: _containerMediumAmountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Medium-Menge (Liter)', border: OutlineInputBorder()), validator: (value) => Validators.validatePositiveNumber(value, min: 0.1, max: 500.0)),
        const SizedBox(height: 12),
        SwitchListTile(title: const Text('Drainage'), value: _containerDrainage, onChanged: (value) => setState(() => _containerDrainage = value)),
        if (_containerDrainage) ...[const SizedBox(height: 12), TextFormField(controller: _containerDrainageMaterialController, decoration: const InputDecoration(labelText: 'Drainage-Material', border: OutlineInputBorder()))],
      ],
    );
  }

  Widget _buildSystemFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('System (RDWC/DWC/Hydro)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 12),
        TextFormField(controller: _systemReservoirSizeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Reservoir Größe (Liter)', border: OutlineInputBorder()), validator: (value) => Validators.validatePositiveNumber(value, min: 1.0, max: 10000.0)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _systemBucketCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Anzahl Buckets', border: OutlineInputBorder()), validator: (value) => Validators.validateInteger(value, min: 1, max: 100))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _systemBucketSizeController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bucket-Größe (L)', border: OutlineInputBorder()), validator: (value) => Validators.validatePositiveNumber(value, min: 1.0, max: 200.0))),
          ],
        ),
      ],
    );
  }

  Widget _buildWaterSection() => TextFormField(controller: _waterAmountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Wasser-Menge (Liter)', border: OutlineInputBorder()), validator: (value) => Validators.validatePositiveNumber(value, min: 0.1, max: 1000.0));

  Widget _buildFertilizerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Dünger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const Spacer(),
            TextButton.icon(onPressed: _showAddFertilizerDialog, icon: const Icon(Icons.add), label: const Text('Hinzufügen')),
          ],
        ),
        const SizedBox(height: 8),
        if (_selectedFertilizers.isEmpty)
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[300]!)), child: Text('Keine Dünger ausgewählt', style: TextStyle(color: Colors.grey[600])))
        else
          ..._selectedFertilizers.entries.map((entry) {
            final fertilizer = _availableFertilizers.firstWhere((f) => f.id == entry.key);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(fertilizer.name),
                subtitle: Text('${entry.value.toStringAsFixed(1)} ml'),
                trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _selectedFertilizers.remove(entry.key))),
                onTap: () => _editFertilizerAmount(entry.key, entry.value),
              ),
            );
          }),
      ],
    );
  }

  void _showAddFertilizerDialog() {
    if (_availableFertilizers.isEmpty) {
      AppMessages.showInfo(context, 'Keine Dünger verfügbar');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dünger hinzufügen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableFertilizers.length,
            itemBuilder: (context, index) {
              final fertilizer = _availableFertilizers[index];
              return ListTile(
                title: Text(fertilizer.name),
                subtitle: fertilizer.npk != null ? Text('NPK: ${fertilizer.npk}') : null,
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

  void _addFertilizer(Fertilizer fertilizer) {
    // ✅ Extra Null-Check für Sicherheit
    if (fertilizer.id == null) {
      AppMessages.showError(context, 'Fehler: Dünger hat keine gültige ID');
      return;
    }

    final amountController = TextEditingController(text: '10');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fertilizer.name),
        content: TextFormField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Menge (ml)', border: OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                setState(() => _selectedFertilizers[fertilizer.id!] = amount);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
  }

  void _editFertilizerAmount(int fertilizerId, double currentAmount) {
    final amountController = TextEditingController(text: currentAmount.toStringAsFixed(1));
    // ✅ Extra Null-Check für Sicherheit
    final fertilizer = _availableFertilizers.firstWhere(
      (f) => f.id == fertilizerId,
      orElse: () => throw Exception('Dünger mit ID $fertilizerId nicht gefunden'),
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fertilizer.name),
        content: TextFormField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Menge (ml)', border: OutlineInputBorder()), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                setState(() => _selectedFertilizers[fertilizerId] = amount);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Widget _buildPhEcSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('pH & EC Werte', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _phInController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'pH In', border: OutlineInputBorder()), validator: (value) => Validators.validatePH(value))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _ecInController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'EC In', border: OutlineInputBorder()), validator: (value) => Validators.validateEC(value))),
          ],
        ),
        if (_showPhEcOut) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextFormField(controller: _phOutController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'pH Out', border: OutlineInputBorder()), validator: (value) => Validators.validatePH(value))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _ecOutController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'EC Out', border: OutlineInputBorder()), validator: (value) => Validators.validateEC(value))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFlagsSection() => Column(children: [SwitchListTile(title: const Text('Runoff'), value: _runoff, onChanged: (value) => setState(() => _runoff = value)), SwitchListTile(title: const Text('Cleanse'), value: _cleanse, onChanged: (value) => setState(() => _cleanse = value))]);

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Umgebung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _temperatureController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Temperatur (°C)', border: OutlineInputBorder()), validator: (value) => Validators.validateTemperature(value))),
            const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _humidityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Luftfeuchte (%)', border: OutlineInputBorder()), validator: (value) => Validators.validateHumidity(value))),
          ],
        ),
      ],
    );
  }

  Widget _buildNoteSection() => TextFormField(controller: _noteController, maxLines: 4, decoration: const InputDecoration(labelText: 'Notizen', hintText: 'Beobachtungen, Änderungen, etc...', border: OutlineInputBorder()));

  Widget _buildSaveButton() => ElevatedButton(
    onPressed: _saveLog,
    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
    child: const Text('Änderungen speichern', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  );
}
