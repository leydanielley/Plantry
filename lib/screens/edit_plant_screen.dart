// =============================================
// GROWLOG - Edit Plant Screen (✅ BUG FIX #6 & #7: GenderType + mounted-checks)
// ✅ AUDIT FIX: i18n extraction - all strings extracted to translations.dart
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../utils/translations.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/grow.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../repositories/interfaces/i_room_repository.dart';
import '../repositories/interfaces/i_grow_repository.dart';
import '../di/service_locator.dart';

class EditPlantScreen extends StatefulWidget {
  final Plant plant;

  const EditPlantScreen({super.key, required this.plant});

  @override
  State<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends State<EditPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();

  late TextEditingController _nameController;
  late TextEditingController _strainController;
  late TextEditingController _breederController;
  late TextEditingController _containerSizeController;
  late TextEditingController _systemSizeController;

  late SeedType _seedType;
  late GenderType _genderType;  // ✅ BUG FIX #6: GenderType statt bool
  late Medium _medium;
  late PlantPhase _phase;
  int? _selectedRoomId;
  int? _selectedGrowId;
  DateTime? _seedDate;

  // ✅ v10: Phase History Dates
  DateTime? _vegDate;
  DateTime? _bloomDate;
  DateTime? _harvestDate;

  List<Room> _rooms = [];
  List<Grow> _grows = [];
  bool _isLoading = false;
  bool _loadingRooms = true;
  bool _loadingGrows = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _strainController = TextEditingController(text: widget.plant.strain ?? '');
    _breederController = TextEditingController(text: widget.plant.breeder ?? '');
    _containerSizeController = TextEditingController(
      text: widget.plant.currentContainerSize != null
          ? widget.plant.currentContainerSize.toString()
          : '',
    );
    _systemSizeController = TextEditingController(
      text: widget.plant.currentSystemSize != null
          ? widget.plant.currentSystemSize.toString()
          : '',
    );

    _seedType = widget.plant.seedType;
    // ✅ BUG FIX #6: bool → GenderType konvertieren
    _genderType = widget.plant.feminized ? GenderType.feminized : GenderType.regular;
    _medium = widget.plant.medium;
    _phase = widget.plant.phase;
    _selectedRoomId = widget.plant.roomId;
    _selectedGrowId = widget.plant.growId;
    _seedDate = widget.plant.seedDate;

    // ✅ v10: Load phase history dates
    _vegDate = widget.plant.vegDate;
    _bloomDate = widget.plant.bloomDate;
    _harvestDate = widget.plant.harvestDate;

    _loadRooms();
    _loadGrows();
  }

  // ✅ BUG FIX #7: mounted-checks hinzugefügt
  Future<void> _loadRooms() async {
    try {
      final rooms = await _roomRepo.findAll();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loadingRooms = false;
        });
      }
    } catch (e) {
      AppLogger.error('EditPlantScreen', 'Error loading rooms: $e');
      if (mounted) {
        setState(() => _loadingRooms = false);
      }
    }
  }

  // ✅ BUG FIX #7: mounted-checks hinzugefügt
  Future<void> _loadGrows() async {
    try {
      final grows = await _growRepo.getAll();
      if (mounted) {
        setState(() {
          _grows = grows;
          _loadingGrows = false;
        });
      }
    } catch (e) {
      AppLogger.error('EditPlantScreen', 'Error loading grows: $e');
      if (mounted) {
        setState(() => _loadingGrows = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _strainController.dispose();
    _breederController.dispose();
    _containerSizeController.dispose();
    _systemSizeController.dispose();
    super.dispose();
  }

  bool get _isHydroSystem {
    return _medium == Medium.dwc || _medium == Medium.rdwc || _medium == Medium.hydro;
  }

  Future<void> _savePlant() async {
    if (!_formKey.currentState!.validate()) return;

    // ✅ AUDIT FIX: i18n - Get translations for validation
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    // =============================================
    // ✅ FIX v11: UI-Level Cross-Validation for chronological date consistency
    // Prevents saving logically impossible plant phase dates
    // ✅ AUDIT FIX: i18n extraction - validation messages
    // =============================================
    final seedDate = _seedDate;
    final vegDate = _vegDate;
    final bloomDate = _bloomDate;
    final harvestDate = _harvestDate;

    // Validate: vegDate must not be before seedDate
    if (vegDate != null && seedDate != null) {
      final vegDay = DateTime(vegDate.year, vegDate.month, vegDate.day);
      final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);
      if (vegDay.isBefore(seedDay)) {
        AppMessages.showError(context, _t['edit_plant_error_veg_before_seed']!); // ✅ i18n
        return; // Abort save
      }
    }

    // Validate: bloomDate must not be before vegDate
    if (bloomDate != null && vegDate != null) {
      final bloomDay = DateTime(bloomDate.year, bloomDate.month, bloomDate.day);
      final vegDay = DateTime(vegDate.year, vegDate.month, vegDate.day);
      if (bloomDay.isBefore(vegDay)) {
        AppMessages.showError(context, _t['edit_plant_error_bloom_before_veg']!); // ✅ i18n
        return; // Abort save
      }
    }

    // Validate: harvestDate must not be before bloomDate
    if (harvestDate != null && bloomDate != null) {
      final harvestDay = DateTime(harvestDate.year, harvestDate.month, harvestDate.day);
      final bloomDay = DateTime(bloomDate.year, bloomDate.month, bloomDate.day);
      if (harvestDay.isBefore(bloomDay)) {
        AppMessages.showError(context, _t['edit_plant_error_harvest_before_bloom']!); // ✅ i18n
        return; // Abort save
      }
    }

    // Additional validation: bloomDate without vegDate
    if (bloomDate != null && vegDate == null && seedDate != null) {
      final bloomDay = DateTime(bloomDate.year, bloomDate.month, bloomDate.day);
      final seedDay = DateTime(seedDate.year, seedDate.month, seedDate.day);
      if (bloomDay.isBefore(seedDay)) {
        AppMessages.showError(context, _t['edit_plant_error_bloom_before_seed']!); // ✅ i18n
        return; // Abort save
      }
    }

    // Additional validation: harvestDate without bloomDate but with vegDate
    if (harvestDate != null && bloomDate == null && vegDate != null) {
      final harvestDay = DateTime(harvestDate.year, harvestDate.month, harvestDate.day);
      final vegDay = DateTime(vegDate.year, vegDate.month, vegDate.day);
      if (harvestDay.isBefore(vegDay)) {
        AppMessages.showError(context, _t['edit_plant_error_harvest_before_veg']!); // ✅ i18n
        return; // Abort save
      }
    }
    // =============================================
    // End of chronological validation
    // =============================================

    // ✅ FIX: Check if seed date changed and warn about log deletion
    if (_seedDate != widget.plant.seedDate && widget.plant.id != null && _seedDate != null) {
      final logsToDelete = await _plantRepo.countLogsToBeDeleted(widget.plant.id!, _seedDate!);

      if (logsToDelete > 0) {
        final totalLogs = await _plantRepo.getLogCount(widget.plant.id!);
        final confirmed = await _showSeedDateChangeWarning(totalLogs, logsToDelete);
        if (!confirmed) return; // User cancelled
      }
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // ✅ v10: Phase-Wechsel prüfen und Phase-Dates setzen
      DateTime? newPhaseStartDate = widget.plant.phaseStartDate;
      DateTime? newVegDate = _vegDate;
      DateTime? newBloomDate = _bloomDate;
      DateTime? newHarvestDate = _harvestDate;

      if (_phase != widget.plant.phase) {
        bool proceedWithChange = true;

        // Von Harvest zurück
        if (widget.plant.phase == PlantPhase.harvest &&
            _phase != PlantPhase.archived) {
          // ✅ AUDIT FIX: i18n - phase change warning
          final message = _t['edit_plant_warning_from_harvest']!.replaceAll('{phase}', _phase.displayName);
          proceedWithChange = await _showPhaseChangeWarning(message);
        }
        // Von Archived zurück
        else if (widget.plant.phase == PlantPhase.archived &&
            _phase != PlantPhase.archived) {
          // ✅ AUDIT FIX: i18n - reactivate warning
          final message = _t['edit_plant_warning_reactivate']!.replaceAll('{phase}', _phase.displayName);
          proceedWithChange = await _showPhaseChangeWarning(message);
        }

        if (!proceedWithChange) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }

        // ✅ v10: Set phase-specific date wenn nicht schon manuell gesetzt
        newPhaseStartDate = DateTime.now();

        switch (_phase) {
          case PlantPhase.veg:
            newVegDate ??= DateTime.now();
            break;
          case PlantPhase.bloom:
            newBloomDate ??= DateTime.now();
            break;
          case PlantPhase.harvest:
            newHarvestDate ??= DateTime.now();
            break;
          default:
            break;
        }
      }

      // ✅ BUG FIX #7: Seed-Datum ohne Uhrzeit
      DateTime effectiveSeedDate;
      if (_seedDate != null) {
        effectiveSeedDate = DateTime(_seedDate!.year, _seedDate!.month, _seedDate!.day);
      } else if (widget.plant.seedDate != null) {
        effectiveSeedDate = DateTime(widget.plant.seedDate!.year, widget.plant.seedDate!.month, widget.plant.seedDate!.day);
      } else {
        final now = DateTime.now();
        effectiveSeedDate = DateTime(now.year, now.month, now.day);
      }

      // ✅ FIX: Clear RDWC fields wenn Medium geändert wird
      final updatedPlant = widget.plant.copyWith(
        name: _nameController.text,
        strain: _strainController.text.isNotEmpty ? _strainController.text : null,
        breeder: _breederController.text.isNotEmpty ? _breederController.text : null,
        feminized: _genderType == GenderType.feminized,  // ✅ BUG FIX #6: GenderType → bool
        seedType: _seedType,
        medium: _medium,
        phase: _phase,
        phaseStartDate: newPhaseStartDate,
        vegDate: newVegDate,
        bloomDate: newBloomDate,
        harvestDate: newHarvestDate,
        roomId: _selectedRoomId,
        growId: _selectedGrowId,
        // ✅ FIX: Wenn Medium nicht RDWC ist, RDWC Felder auf null setzen
        rdwcSystemId: _medium == Medium.rdwc ? widget.plant.rdwcSystemId : null,
        bucketNumber: _medium == Medium.rdwc ? widget.plant.bucketNumber : null,
        seedDate: effectiveSeedDate,
        currentContainerSize: _containerSizeController.text.isNotEmpty
            ? double.tryParse(_containerSizeController.text)
            : null,
        currentSystemSize: _systemSizeController.text.isNotEmpty
            ? double.tryParse(_systemSizeController.text)
            : null,
      );

      await _plantRepo.save(updatedPlant);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.updatedSuccessfully(context, _t['plant']!); // ✅ i18n
      }
    } catch (e) {
      AppLogger.error('EditPlantScreen', 'Error saving: $e');
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showPhaseChangeWarning(String message) async {
    // ✅ AUDIT FIX: i18n - Get translations for dialog
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['edit_plant_warning_title']!), // ✅ i18n
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t['cancel']!), // ✅ i18n
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: Text(_t['edit_plant_proceed_button']!), // ✅ i18n
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// ✅ FIX: Warning when changing seed date with existing logs
  /// ✅ AUDIT FIX: i18n extraction - seed date change warning dialog
  Future<bool> _showSeedDateChangeWarning(int totalLogs, int logsToDelete) async {
    // ✅ AUDIT FIX: i18n - Get translations for dialog
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            Text(_t['edit_plant_seed_warning_title']!), // ✅ i18n
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t['edit_plant_seed_warning_total']!.replaceAll('{count}', totalLogs.toString()), // ✅ i18n
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300] ?? Colors.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _t['edit_plant_seed_warning_deleted']!.replaceAll('{count}', logsToDelete.toString()), // ✅ i18n
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _t['edit_plant_seed_warning_before_date']!, // ✅ i18n
                    style: TextStyle(color: Colors.red[900], fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t['edit_plant_seed_warning_what_happens']!, // ✅ i18n
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(_t['edit_plant_seed_warning_recalculate']!), // ✅ i18n
            const SizedBox(height: 4),
            Text(_t['edit_plant_seed_warning_delete_logs']!.replaceAll('{count}', logsToDelete.toString())), // ✅ i18n
            const SizedBox(height: 12),
            Text(
              _t['edit_plant_seed_warning_irreversible']!, // ✅ i18n
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t['cancel']!), // ✅ i18n
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: Text(_t['edit_plant_seed_change_confirm']!), // ✅ i18n
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deletePlant() async {
    // ✅ AUDIT FIX: i18n - Get translations for delete dialog
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['edit_plant_delete_title']!), // ✅ i18n
        content: Text(
          _t['edit_plant_delete_message']!.replaceAll('{name}', widget.plant.name), // ✅ i18n
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']!), // ✅ i18n
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t['delete']!), // ✅ i18n
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      await _plantRepo.delete(widget.plant.id!);

      if (mounted) {
        // ✅ FIX: Only pop once to close edit screen
        // The confirmation dialog was already popped when user clicked delete button
        Navigator.of(context).pop(true);
        AppMessages.deletedSuccessfully(context, _t['plant']!); // ✅ i18n
      }
    } catch (e) {
      AppLogger.error('EditPlantScreen', 'Error deleting: $e');
      if (mounted) {
        AppMessages.deletingError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ AUDIT FIX: i18n - Initialize translations
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(_t['edit_plant_title']!), // ✅ i18n
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
            _buildGeneticsInfo(),
            const SizedBox(height: 24),
            _buildGrowInfo(),
            const SizedBox(height: 24),
            _buildContainerInfo(),
            const SizedBox(height: 24),
            _buildDatePicker(),
            const SizedBox(height: 24),
            _buildPhaseDatePickers(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 16),
            _buildDeleteButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    // ✅ AUDIT FIX: i18n - Get translations for basic info section
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['edit_plant_basic_info']!, // ✅ i18n
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
            labelText: _t['edit_plant_name_label']!, // ✅ i18n
            prefixIcon: const Icon(Icons.label),
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return _t['edit_plant_name_required']!; // ✅ i18n
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _strainController,
          decoration: InputDecoration(
            labelText: _t['edit_plant_strain_label']!, // ✅ i18n
            prefixIcon: const Icon(Icons.local_florist),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _breederController,
          decoration: InputDecoration(
            labelText: _t['edit_plant_breeder_label']!, // ✅ i18n
            prefixIcon: const Icon(Icons.business),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // ✅ BUG FIX #6: Switch durch Dropdown ersetzt
  // ✅ AUDIT FIX: i18n extraction - genetics section
  Widget _buildGeneticsInfo() {
    // ✅ AUDIT FIX: i18n - Get translations for genetics section
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['edit_plant_genetics_section']!, // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        _buildDropdown<SeedType>(
          label: _t['edit_plant_seed_type_label']!, // ✅ i18n
          value: _seedType,
          items: SeedType.values,
          onChanged: (value) => setState(() => _seedType = value!),
        ),
        const SizedBox(height: 12),
        // ✅ BUG FIX #6: Dropdown statt Switch
        _buildDropdown<GenderType>(
          label: _t['edit_plant_gender_label']!, // ✅ i18n
          value: _genderType,
          items: GenderType.values,
          onChanged: (value) => setState(() => _genderType = value!),
        ),
      ],
    );
  }

  Widget _buildGrowInfo() {
    // ✅ AUDIT FIX: i18n - Get translations for grow setup section
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['edit_plant_grow_setup_section']!, // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        _buildDropdown<Medium>(
          label: _t['edit_plant_medium_label']!, // ✅ i18n
          value: _medium,
          items: Medium.values,
          onChanged: (value) => setState(() => _medium = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown<PlantPhase>(
          label: _t['edit_plant_phase_label']!, // ✅ i18n
          value: _phase,
          items: PlantPhase.values,
          onChanged: (value) => setState(() => _phase = value!),
        ),
        const SizedBox(height: 12),
        if (_loadingGrows)
          const Center(child: CircularProgressIndicator())
        else
          DropdownButtonFormField<int?>(
            initialValue: _selectedGrowId,
            decoration: InputDecoration(
              labelText: _t['edit_plant_grow_label']!, // ✅ i18n
              prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
              border: const OutlineInputBorder(),
              helperText: _t['edit_plant_grow_helper']!, // ✅ i18n
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(_t['edit_plant_no_grow']!)), // ✅ i18n
              ..._grows.map((grow) {
                return DropdownMenuItem(
                  value: grow.id,
                  child: Text(grow.name),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedGrowId = value),
          ),
        const SizedBox(height: 12),
        if (_loadingRooms)
          const Center(child: CircularProgressIndicator())
        else
          DropdownButtonFormField<int?>(
            initialValue: _selectedRoomId,
            decoration: InputDecoration(
              labelText: _t['edit_plant_room_label']!, // ✅ i18n
              prefixIcon: const Icon(Icons.home),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(_t['edit_plant_no_room']!)), // ✅ i18n
              ..._rooms.map((room) {
                return DropdownMenuItem(
                  value: room.id,
                  child: Text(room.name),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedRoomId = value),
          ),
      ],
    );
  }

  Widget _buildContainerInfo() {
    // ✅ AUDIT FIX: i18n - Get translations for container info section
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isHydroSystem ? _t['edit_plant_system_info']! : _t['edit_plant_container_info']!, // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        if (_isHydroSystem)
          TextFormField(
            controller: _systemSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _t['edit_plant_system_size_label']!, // ✅ i18n
              hintText: _t['edit_plant_system_size_hint']!, // ✅ i18n
              prefixIcon: Icon(Icons.water, color: Colors.blue[600]),
              border: const OutlineInputBorder(),
              helperText: _t['edit_plant_system_size_helper']!, // ✅ i18n
            ),
          )
        else
          TextFormField(
            controller: _containerSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _t['edit_plant_pot_size_label']!, // ✅ i18n
              hintText: _t['edit_plant_pot_size_hint']!, // ✅ i18n
              prefixIcon: Icon(Icons.local_florist, color: Colors.brown[600]),
              border: const OutlineInputBorder(),
              helperText: _t['edit_plant_pot_size_helper']!, // ✅ i18n
            ),
          ),
      ],
    );
  }

  // ✅ BUG FIX #6: GenderType zu Dropdown hinzugefügt
  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        String displayName;
        if (item is SeedType) {
          displayName = (item as SeedType).displayName;
        } else if (item is GenderType) {
          displayName = (item as GenderType).displayName;
        } else if (item is Medium) {
          displayName = (item as Medium).displayName;
        } else if (item is PlantPhase) {
          displayName = (item as PlantPhase).displayName;
        } else {
          displayName = item.toString();
        }
        return DropdownMenuItem<T>(
          value: item,
          child: Text(displayName),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDatePicker() {
    // ✅ AUDIT FIX: i18n - Get translations for date picker
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.grey[700]),
      title: Text(_t['edit_plant_seed_date_label']!), // ✅ i18n
      subtitle: Text(
        _seedDate != null
            ? '${_seedDate!.day}.${_seedDate!.month}.${_seedDate!.year}'
            : _t['edit_plant_not_set']!, // ✅ i18n
      ),
      trailing: const Icon(Icons.edit),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _seedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) {
          setState(() => _seedDate = date);
        }
      },
    );
  }

  // ✅ v10: Phase History Date Pickers
  // ✅ AUDIT FIX: i18n extraction - phase date pickers
  Widget _buildPhaseDatePickers() {
    // ✅ AUDIT FIX: i18n - Get translations for phase dates section
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['edit_plant_phases_section']!, // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t['edit_plant_phases_description']!, // ✅ i18n
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 12),
        _buildVegDatePicker(),
        _buildBloomDatePicker(),
        _buildHarvestDatePicker(),
      ],
    );
  }

  Widget _buildVegDatePicker() {
    // ✅ AUDIT FIX: i18n - Get translations for veg date picker
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return ListTile(
      leading: Icon(Icons.eco, color: Colors.green[700]),
      title: Text(_t['edit_plant_veg_start_label']!), // ✅ i18n
      subtitle: Text(
        _vegDate != null
            ? '${_vegDate!.day}.${_vegDate!.month}.${_vegDate!.year}'
            : _t['edit_plant_not_set']!, // ✅ i18n
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_vegDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () => setState(() => _vegDate = null),
            ),
          const Icon(Icons.edit),
        ],
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _vegDate ?? _seedDate ?? DateTime.now(),
          firstDate: _seedDate ?? DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) {
          setState(() => _vegDate = date);
        }
      },
    );
  }

  Widget _buildBloomDatePicker() {
    // ✅ AUDIT FIX: i18n - Get translations for bloom date picker
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return ListTile(
      leading: Icon(Icons.local_florist, color: Colors.purple[700]),
      title: Text(_t['edit_plant_bloom_start_label']!), // ✅ i18n
      subtitle: Text(
        _bloomDate != null
            ? '${_bloomDate!.day}.${_bloomDate!.month}.${_bloomDate!.year}'
            : _t['edit_plant_not_set']!, // ✅ i18n
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_bloomDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () => setState(() => _bloomDate = null),
            ),
          const Icon(Icons.edit),
        ],
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _bloomDate ?? _vegDate ?? _seedDate ?? DateTime.now(),
          firstDate: _seedDate ?? DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) {
          setState(() => _bloomDate = date);
        }
      },
    );
  }

  Widget _buildHarvestDatePicker() {
    // ✅ AUDIT FIX: i18n - Get translations for harvest date picker
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return ListTile(
      leading: Icon(Icons.agriculture, color: Colors.brown[700]),
      title: Text(_t['edit_plant_harvest_start_label']!), // ✅ i18n
      subtitle: Text(
        _harvestDate != null
            ? '${_harvestDate!.day}.${_harvestDate!.month}.${_harvestDate!.year}'
            : _t['edit_plant_not_set']!, // ✅ i18n
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_harvestDate != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () => setState(() => _harvestDate = null),
            ),
          const Icon(Icons.edit),
        ],
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _harvestDate ?? _bloomDate ?? _vegDate ?? _seedDate ?? DateTime.now(),
          firstDate: _seedDate ?? DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (date != null && mounted) {
          setState(() => _harvestDate = date);
        }
      },
    );
  }

  Widget _buildSaveButton() {
    // ✅ AUDIT FIX: i18n - Get translations for save button
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return ElevatedButton(
      onPressed: _savePlant,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: Text(_t['edit_plant_save_button']!), // ✅ i18n
    );
  }

  Widget _buildDeleteButton() {
    // ✅ AUDIT FIX: i18n - Get translations for delete button
    final _t = AppTranslations(Localizations.localeOf(context).languageCode);

    return OutlinedButton.icon(
      onPressed: _deletePlant,
      icon: const Icon(Icons.delete),
      label: Text(_t['edit_plant_delete_button']!), // ✅ i18n
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red[700],
        side: BorderSide(color: Colors.red[700] ?? Colors.red),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}