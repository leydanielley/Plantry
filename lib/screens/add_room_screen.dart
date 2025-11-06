// =============================================
// GROWLOG - Add Room Screen (✅ MIT CM STATT METER!)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/room.dart';
import '../models/enums.dart';
import '../models/rdwc_system.dart';
import '../models/app_settings.dart';
import '../repositories/room_repository.dart';
import '../repositories/rdwc_repository.dart';
import '../repositories/settings_repository.dart';
import '../utils/validators.dart';
import '../utils/app_messages.dart';
import 'add_hardware_screen.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({super.key});

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final RoomRepository _roomRepo = RoomRepository();
  final RdwcRepository _rdwcRepo = RdwcRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

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
      final room = Room(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        growType: _growType,
        wateringSystem: _wateringSystem,
        rdwcSystemId: _selectedRdwcSystemId,
        width: _widthController.text.trim().isNotEmpty
            ? (double.tryParse(_widthController.text.trim()) ?? 0.0) / 100.0  // ✅ CM → Meter
            : 0.0,
        depth: _depthController.text.trim().isNotEmpty
            ? (double.tryParse(_depthController.text.trim()) ?? 0.0) / 100.0  // ✅ CM → Meter
            : 0.0,
        height: _heightController.text.trim().isNotEmpty
            ? (double.tryParse(_heightController.text.trim()) ?? 0.0) / 100.0  // ✅ CM → Meter
            : 0.0,
      );

      await _roomRepo.save(room);

      if (mounted) {
        // Erfolgreich gespeichert - jetzt Hardware-Dialog anzeigen
        final savedRoom = room.id != null ? room : await _roomRepo.findAll().then((rooms) => rooms.last);

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
                const Expanded(child: Text('Hardware hinzufügen?')),
              ],
            ),
            content: Text(
              'Möchtest du jetzt Hardware für "${room.name}" hinzufügen?\n\n'
                  'Du kannst z.B. Lampen, Lüfter oder andere Geräte erfassen.',
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Später'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.add),
                label: const Text('Jetzt hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );

        if (addHardware == true && savedRoom.id != null && mounted) {
          // Navigation zu Add Hardware Screen - bleibt offen für mehrere Einträge!
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddHardwareScreen(roomId: savedRoom.id!),
            ),
          );

          if (mounted) {
            AppMessages.showSuccess(context, 'Hardware-Eingabe abgeschlossen! 🔧');
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
        title: const Text('Neuer Raum'),
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
          'Grundinformationen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name *',
            hintText: 'z.B. Grow Tent 120x120',
            prefixIcon: Icon(Icons.home),
            border: OutlineInputBorder(),
          ),
          validator: (value) => Validators.validateNotEmpty(value, fieldName: 'Name'),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Beschreibung',
            hintText: 'Optional',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
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
          'Grow Setup',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<GrowType?>(
          initialValue: _growType,
          decoration: const InputDecoration(
            labelText: 'Grow Type',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nicht angegeben')),
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
          decoration: const InputDecoration(
            labelText: 'Bewässerungssystem',
            prefixIcon: Icon(Icons.water_drop),
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Nicht angegeben')),
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
              labelText: 'RDWC System (optional)',
              helperText: 'Verknüpfe diesen Raum mit einem RDWC System',
              prefixIcon: Icon(Icons.water, color: Colors.blue[700]),
              border: const OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Kein RDWC System')),
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
          'Abmessungen (optional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        // ✅ KORRIGIERT: Jetzt Zentimeter statt Meter
        Text(
          'Alle Maße in Zentimetern (cm)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _widthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Breite (cm)',  // ✅ KORRIGIERT
                  hintText: 'z.B. 120',      // ✅ KORRIGIERT
                  border: OutlineInputBorder(),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tiefe (cm)',   // ✅ KORRIGIERT
                  hintText: 'z.B. 120',      // ✅ KORRIGIERT
                  border: OutlineInputBorder(),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Höhe (cm)',    // ✅ KORRIGIERT
                  hintText: 'z.B. 200',      // ✅ KORRIGIERT
                  border: OutlineInputBorder(),
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
      child: const Text('Raum speichern'),
    );
  }
}