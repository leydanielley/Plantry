// =============================================
// GROWLOG - Edit Room Screen (✅ BUG FIX: CM statt Meter!)
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/translations.dart'; // ✅ AUDIT FIX: i18n
import 'package:growlog_app/di/service_locator.dart';

class EditRoomScreen extends StatefulWidget {
  final Room room;

  const EditRoomScreen({super.key, required this.room});

  @override
  State<EditRoomScreen> createState() => _EditRoomScreenState();
}

class _EditRoomScreenState extends State<EditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _widthController;
  late TextEditingController _depthController;
  late TextEditingController _heightController;

  GrowType? _growType;
  WateringSystem? _wateringSystem;
  int? _selectedRdwcSystemId;
  List<RdwcSystem> _rdwcSystems = [];
  AppSettings? _settings;
  late AppTranslations _t; // ✅ AUDIT FIX: i18n
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _descriptionController = TextEditingController(
      text: widget.room.description ?? '',
    );

    // ✅ BUG FIX #3: Meter → CM umrechnen beim Laden (multiplizieren mit 100)
    _widthController = TextEditingController(
      text: widget.room.width > 0
          ? (widget.room.width * 100).toStringAsFixed(0)
          : '',
    );
    _depthController = TextEditingController(
      text: widget.room.depth > 0
          ? (widget.room.depth * 100).toStringAsFixed(0)
          : '',
    );
    _heightController = TextEditingController(
      text: widget.room.height > 0
          ? (widget.room.height * 100).toStringAsFixed(0)
          : '',
    );

    _growType = widget.room.growType;
    _wateringSystem = widget.room.wateringSystem;
    _selectedRdwcSystemId = widget.room.rdwcSystemId;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final systems = await _rdwcRepo.getAllSystems();

      if (mounted) {
        setState(() {
          _settings = settings;
          _t = AppTranslations(settings.language); // ✅ AUDIT FIX: i18n
          _rdwcSystems = systems;
        });
      }
    } catch (e) {
      AppLogger.error('EditRoomScreen', 'Error loading initial data', e);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // ✅ BUG FIX #3: CM → Meter umrechnen beim Speichern (dividieren durch 100)
      // ✅ FIX: Clear rdwcSystemId wenn wateringSystem nicht RDWC ist
      final updatedRoom = widget.room.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        growType: _growType,
        wateringSystem: _wateringSystem,
        rdwcSystemId: _wateringSystem == WateringSystem.rdwc
            ? _selectedRdwcSystemId
            : null,
        width: _widthController.text.trim().isNotEmpty
            ? (double.tryParse(_widthController.text.trim()) ?? 0.0) /
                  100.0 // ✅ CM → Meter
            : 0.0,
        depth: _depthController.text.trim().isNotEmpty
            ? (double.tryParse(_depthController.text.trim()) ?? 0.0) /
                  100.0 // ✅ CM → Meter
            : 0.0,
        height: _heightController.text.trim().isNotEmpty
            ? (double.tryParse(_heightController.text.trim()) ?? 0.0) /
                  100.0 // ✅ CM → Meter
            : 0.0,
      );

      await _roomRepo.save(updatedRoom);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.updatedSuccessfully(context, 'Raum');
      }
    } catch (e) {
      AppLogger.error('EditRoomScreen', 'Error saving: $e');
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ AUDIT FIX: Show loading until translations are initialized
    if (_settings == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t['edit_room_title']),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBasicInfo(),
                  const SizedBox(height: 24),
                  _buildGrowSettings(),
                  const SizedBox(height: 24),
                  _buildDimensions(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_room_basic_info'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: _t['add_room_name_label'],
            prefixIcon: const Icon(Icons.home),
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
              Validators.validateNotEmpty(value, fieldName: 'Name'),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: _t['add_room_description_label'],
            hintText: _t['add_room_description_hint'],
            prefixIcon: const Icon(Icons.description),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildGrowSettings() {
    final isExpertMode = _settings?.isExpertMode ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_room_grow_setup'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<GrowType?>(
          initialValue: _growType,
          decoration: InputDecoration(
            labelText: _t['add_room_grow_type'],
            prefixIcon: const Icon(Icons.category),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(_t['add_room_not_specified']),
            ),
            ...GrowType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }),
          ],
          onChanged: (value) => setState(() => _growType = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<WateringSystem?>(
          initialValue: _wateringSystem,
          decoration: InputDecoration(
            labelText: _t['add_room_watering_system'],
            prefixIcon: const Icon(Icons.water_drop),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(_t['add_room_not_specified']),
            ),
            ...WateringSystem.values.map((system) {
              return DropdownMenuItem(
                value: system,
                child: Text(system.displayName),
              );
            }),
          ],
          onChanged: (value) => setState(() => _wateringSystem = value),
        ),
        // ✅ Expert Mode: RDWC System Auswahl
        if (isExpertMode) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _selectedRdwcSystemId,
            decoration: InputDecoration(
              labelText: _t['add_room_rdwc_system'],
              helperText: _t['add_room_rdwc_helper'],
              prefixIcon: Icon(Icons.water, color: Colors.blue[700]),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(_t['add_room_no_rdwc']),
              ),
              ..._rdwcSystems.map((system) {
                return DropdownMenuItem(
                  value: system.id,
                  child: Text(system.name),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedRdwcSystemId = value),
          ),
        ],
      ],
    );
  }

  Widget _buildDimensions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_room_dimensions'],
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        // ✅ BUG FIX #2: Jetzt Zentimeter statt Meter
        Text(
          _t['add_room_dimensions_unit'],
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _widthController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['add_room_width_label'], // ✅ KORRIGIERT
                  hintText: _t['add_room_width_hint'], // ✅ KORRIGIERT
                  border: const OutlineInputBorder(),
                ),
                // ✅ BUG FIX #2: Validator für CM (10-1000 cm)
                validator: (value) => Validators.validatePositiveNumber(
                  value,
                  min: 10.0,
                  max: 1000.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _depthController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['add_room_depth_label'], // ✅ KORRIGIERT
                  hintText: _t['add_room_width_hint'], // ✅ KORRIGIERT
                  border: const OutlineInputBorder(),
                ),
                // ✅ BUG FIX #2: Validator für CM (10-1000 cm)
                validator: (value) => Validators.validatePositiveNumber(
                  value,
                  min: 10.0,
                  max: 1000.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _heightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: _t['add_room_height_label'], // ✅ KORRIGIERT
                  hintText: _t['add_room_height_hint'], // ✅ KORRIGIERT
                  border: const OutlineInputBorder(),
                ),
                // ✅ BUG FIX #2: Validator für CM (10-1000 cm)
                validator: (value) => Validators.validatePositiveNumber(
                  value,
                  min: 10.0,
                  max: 1000.0,
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
      onPressed: _saveRoom,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: Text(_t['edit_room_save_button']),
    );
  }
}
