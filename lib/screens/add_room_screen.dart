// =============================================
// GROWLOG - Add Room Screen (✅ MIT CM STATT METER!)
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/translations.dart'; // ✅ AUDIT FIX: i18n
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/screens/add_hardware_screen.dart';
import 'package:growlog_app/di/service_locator.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  late final AppTranslations _t; // ✅ AUDIT FIX: i18n

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _heightController = TextEditingController();

  GrowType? _growType;
  WateringSystem? _wateringSystem;
  int? _selectedRdwcSystemId;
  List<RdwcSystem> _rdwcSystems = [];
  AppSettings? _settings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _t = AppTranslations(
      Localizations.localeOf(context).languageCode,
    ); // ✅ AUDIT FIX: i18n
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final settings = await _settingsRepo.getSettings();
      final systems = await _rdwcRepo.getAllSystems();

      if (mounted) {
        setState(() {
          _settings = settings;
          _rdwcSystems = systems;
        });
      }
    } catch (e) {
      AppLogger.error('AddRoomScreen', 'Error loading initial data', e);
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

    setState(() => _isLoading = true);

    try {
      // ✅ KORRIGIERT: CM in Meter umrechnen (dividieren durch 100)
      // ✅ FIX: Nur rdwcSystemId setzen wenn wateringSystem RDWC ist
      final room = Room(
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

      await _roomRepo.save(room);

      if (mounted) {
        // Erfolgreich gespeichert - jetzt Hardware-Dialog anzeigen
        final savedRoom = room.id != null
            ? room
            : await _roomRepo.findAll().then((rooms) => rooms.last);

        if (!mounted) return;
        AppMessages.savedSuccessfully(context, 'Raum');

        // Dialog: Hardware hinzufügen? (VOR dem Pop!)
        final addHardware = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.hardware, color: Colors.orange[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_t['add_room_hardware_dialog_title']),
                ), // ✅ i18n
              ],
            ),
            content: Text(
              _t['add_room_hardware_dialog_message'].replaceAll(
                '{name}',
                room.name,
              ), // ✅ i18n
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_t['add_room_hardware_later']), // ✅ i18n
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.add),
                label: Text(_t['add_room_hardware_now']), // ✅ i18n
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (addHardware == true && savedRoom.id != null) {
          // ✅ CRITICAL FIX: Fresh mounted check before using context
          if (!mounted) return;

          // Navigation zu Add Hardware Screen - bleibt offen für mehrere Einträge!
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddHardwareScreen(roomId: savedRoom.id!),
            ),
          );

          if (mounted) {
            AppMessages.showSuccess(
              context,
              _t['add_room_hardware_complete'],
            ); // ✅ i18n
          }
        }

        // Jetzt erst zurück zum vorherigen Screen
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      AppLogger.error('AddRoomScreen', 'Error saving: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['add_room_title']), // ✅ i18n
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
          _t['add_room_basic_info'], // ✅ i18n
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
            labelText: _t['add_room_name_label'], // ✅ i18n
            hintText: _t['add_room_name_hint'], // ✅ i18n
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
            labelText: _t['add_room_description_label'], // ✅ i18n
            hintText: _t['add_room_description_hint'], // ✅ i18n
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
          _t['add_room_grow_setup'], // ✅ i18n
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
            labelText: _t['add_room_grow_type'], // ✅ i18n
            prefixIcon: const Icon(Icons.category),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(_t['add_room_not_specified']),
            ), // ✅ i18n
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
            labelText: _t['add_room_watering_system'], // ✅ i18n
            prefixIcon: const Icon(Icons.water_drop),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(_t['add_room_not_specified']),
            ), // ✅ i18n
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
              labelText: _t['add_room_rdwc_system'], // ✅ i18n
              helperText: _t['add_room_rdwc_helper'], // ✅ i18n
              prefixIcon: Icon(Icons.water, color: Colors.blue[700]),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(_t['add_room_no_rdwc']),
              ), // ✅ i18n
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
          _t['add_room_dimensions'], // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        // ✅ KORRIGIERT: Jetzt Zentimeter statt Meter
        Text(
          _t['add_room_dimensions_unit'], // ✅ i18n
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
                  labelText: _t['add_room_width_label'], // ✅ i18n
                  hintText: _t['add_room_width_hint'], // ✅ i18n
                  border: const OutlineInputBorder(),
                ),
                // ✅ KORRIGIERT: Validator für CM (10-1000 cm)
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
                  labelText: _t['add_room_depth_label'], // ✅ i18n
                  hintText: _t['add_room_depth_hint'], // ✅ i18n
                  border: const OutlineInputBorder(),
                ),
                // ✅ KORRIGIERT: Validator für CM (10-1000 cm)
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
                  labelText: _t['add_room_height_label'], // ✅ i18n
                  hintText: _t['add_room_height_hint'], // ✅ i18n
                  border: const OutlineInputBorder(),
                ),
                // ✅ KORRIGIERT: Validator für CM (10-1000 cm)
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
      child: Text(_t['add_room_save_button']), // ✅ i18n
    );
  }
}
