// =============================================
// GROWLOG - Edit Plant Screen (✅ BUG FIX #6 & #7: GenderType + mounted-checks)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
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

    // ✅ FIX: Check if seed date changed and logs exist
    if (_seedDate != widget.plant.seedDate && widget.plant.id != null) {
      final logCount = await _plantRepo.getLogCount(widget.plant.id!);

      if (logCount > 0) {
        final confirmed = await _showSeedDateChangeWarning(logCount);
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
          proceedWithChange = await _showPhaseChangeWarning(
              'Du möchtest von Harvest zurück zu ${_phase.displayName} wechseln. '
                  'Dies ist ungewöhnlich. Fortfahren?'
          );
        }
        // Von Archived zurück
        else if (widget.plant.phase == PlantPhase.archived &&
            _phase != PlantPhase.archived) {
          proceedWithChange = await _showPhaseChangeWarning(
              'Pflanze reaktivieren auf ${_phase.displayName}. Fortfahren?'
          );
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
        AppMessages.updatedSuccessfully(context, 'Pflanze');
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Warnung'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Fortfahren'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// ✅ FIX: Warning when changing seed date with existing logs
  Future<bool> _showSeedDateChangeWarning(int logCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700], size: 28),
            const SizedBox(width: 12),
            const Text('Seed-Datum ändern?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diese Pflanze hat bereits $logCount Log-Einträge.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Was passiert beim Ändern des Seed-Datums:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('✅ Alle Tagnummern (day_number) werden neu berechnet'),
            const SizedBox(height: 4),
            const Text('⚠️ Logs vor dem neuen Seed-Datum werden gelöscht'),
            const SizedBox(height: 12),
            const Text(
              'Diese Aktion kann nicht rückgängig gemacht werden!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Ja, Seed-Datum ändern'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deletePlant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pflanze löschen?'),
        content: Text(
          'Möchtest du "${widget.plant.name}" wirklich löschen? '
              'Alle Logs und Daten gehen verloren.\n\n'
              'Diese Aktion kann nicht rückgängig gemacht werden!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
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
        Navigator.of(context).pop(true);
        Navigator.of(context).pop(true);
        AppMessages.deletedSuccessfully(context, 'Pflanze');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pflanze bearbeiten'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basis Info',
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
            prefixIcon: Icon(Icons.label),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Bitte Namen eingeben';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _strainController,
          decoration: const InputDecoration(
            labelText: 'Strain',
            prefixIcon: Icon(Icons.local_florist),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _breederController,
          decoration: const InputDecoration(
            labelText: 'Breeder',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // ✅ BUG FIX #6: Switch durch Dropdown ersetzt
  Widget _buildGeneticsInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genetik',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        _buildDropdown<SeedType>(
          label: 'Seed Type',
          value: _seedType,
          items: SeedType.values,
          onChanged: (value) => setState(() => _seedType = value!),
        ),
        const SizedBox(height: 12),
        // ✅ BUG FIX #6: Dropdown statt Switch
        _buildDropdown<GenderType>(
          label: 'Geschlecht',
          value: _genderType,
          items: GenderType.values,
          onChanged: (value) => setState(() => _genderType = value!),
        ),
      ],
    );
  }

  Widget _buildGrowInfo() {
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
        _buildDropdown<Medium>(
          label: 'Medium',
          value: _medium,
          items: Medium.values,
          onChanged: (value) => setState(() => _medium = value!),
        ),
        const SizedBox(height: 12),
        _buildDropdown<PlantPhase>(
          label: 'Phase',
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
              labelText: 'Grow (optional)',
              prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
              border: const OutlineInputBorder(),
              helperText: 'Pflanze einem Grow zuordnen',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Kein Grow')),
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
            decoration: const InputDecoration(
              labelText: 'Raum (optional)',
              prefixIcon: Icon(Icons.home),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Kein Raum')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isHydroSystem ? 'System Info' : 'Container Info',
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
              labelText: 'System Größe (Liter)',
              hintText: 'z.B. 100',
              prefixIcon: Icon(Icons.water, color: Colors.blue[600]),
              border: const OutlineInputBorder(),
              helperText: 'Gesamtgröße des Hydro-Systems',
            ),
          )
        else
          TextFormField(
            controller: _containerSizeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Topfgröße (Liter)',
              hintText: 'z.B. 11',
              prefixIcon: Icon(Icons.local_florist, color: Colors.brown[600]),
              border: const OutlineInputBorder(),
              helperText: 'Aktueller Topf',
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
    return ListTile(
      leading: Icon(Icons.calendar_today, color: Colors.grey[700]),
      title: const Text('Seed-Datum'),
      subtitle: Text(
        _seedDate != null
            ? '${_seedDate!.day}.${_seedDate!.month}.${_seedDate!.year}'
            : 'Nicht gesetzt',
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
  Widget _buildPhaseDatePickers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phasen-Daten (optional)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Setze die Startdaten für jede Phase manuell. Dies ermöglicht retroaktive Korrekturen.',
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
    return ListTile(
      leading: Icon(Icons.eco, color: Colors.green[700]),
      title: const Text('Veg-Start'),
      subtitle: Text(
        _vegDate != null
            ? '${_vegDate!.day}.${_vegDate!.month}.${_vegDate!.year}'
            : 'Nicht gesetzt',
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
    return ListTile(
      leading: Icon(Icons.local_florist, color: Colors.purple[700]),
      title: const Text('Bloom-Start'),
      subtitle: Text(
        _bloomDate != null
            ? '${_bloomDate!.day}.${_bloomDate!.month}.${_bloomDate!.year}'
            : 'Nicht gesetzt',
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
    return ListTile(
      leading: Icon(Icons.agriculture, color: Colors.brown[700]),
      title: const Text('Harvest-Start'),
      subtitle: Text(
        _harvestDate != null
            ? '${_harvestDate!.day}.${_harvestDate!.month}.${_harvestDate!.year}'
            : 'Nicht gesetzt',
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
    return ElevatedButton(
      onPressed: _savePlant,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: const Text('Änderungen speichern'),
    );
  }

  Widget _buildDeleteButton() {
    return OutlinedButton.icon(
      onPressed: _deletePlant,
      icon: const Icon(Icons.delete),
      label: const Text('Pflanze löschen'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red[700],
        side: BorderSide(color: Colors.red[700]!),
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}