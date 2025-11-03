// =============================================
// GROWLOG - Add Plant Screen (✅ KORRIGIERT: Genetik-Bereich)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/grow.dart';
import '../models/enums.dart';
import '../repositories/plant_repository.dart';
import '../repositories/room_repository.dart';
import '../repositories/grow_repository.dart';
import '../utils/app_messages.dart';

class AddPlantScreen extends StatefulWidget {
  final int? preselectedGrowId;

  const AddPlantScreen({super.key, this.preselectedGrowId});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final PlantRepository _plantRepo = PlantRepository();
  final RoomRepository _roomRepo = RoomRepository();
  final GrowRepository _growRepo = GrowRepository();

  // Form Controllers
  final _nameController = TextEditingController();
  final _strainController = TextEditingController();
  final _breederController = TextEditingController();
  final _containerSizeController = TextEditingController();
  final _systemSizeController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  SeedType _seedType = SeedType.photo;
  GenderType _genderType = GenderType.feminized;  // ✅ KORRIGIERT: Neues Enum
  Medium _medium = Medium.erde;
  PlantPhase _phase = PlantPhase.seedling;
  int? _selectedRoomId;
  int? _selectedGrowId;
  DateTime? _seedDate;

  List<Room> _rooms = [];
  List<Grow> _grows = [];
  bool _isLoading = false;
  bool _loadingRooms = true;
  bool _loadingGrows = true;

  @override
  void initState() {
    super.initState();
    _selectedGrowId = widget.preselectedGrowId;
    _loadRooms();
    _loadGrows();
  }

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
      AppLogger.error('AddPlantScreen', 'Error loading rooms: $e');
      if (mounted) {
        setState(() => _loadingRooms = false);
      }
    }
  }

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
      AppLogger.error('AddPlantScreen', 'Error loading grows: $e');
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
    _quantityController.dispose();
    super.dispose();
  }

  bool get _isHydroSystem {
    return _medium == Medium.dwc || _medium == Medium.rdwc || _medium == Medium.hydro;
  }

  Future<void> _createNewGrow() async {
    final nameController = TextEditingController(
      text: 'Grow ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
    );
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neuen Grow erstellen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'z.B. Winter Grow 2025',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung (optional)',
                  hintText: 'z.B. 5x Wedding Cake',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF004225)),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final grow = Grow(
          name: nameController.text,
          description: descriptionController.text.isNotEmpty
              ? descriptionController.text
              : null,
          startDate: DateTime.now(),
        );

        final growId = await _growRepo.create(grow);

        await _loadGrows();

        if (mounted) {
          setState(() {
            _selectedGrowId = growId;
          });
        }

        if (mounted) {
          AppMessages.growCreated(context);
        }
      } catch (e) {
        AppLogger.error('AddPlantScreen', 'Error creating grow: $e');
        if (mounted) {
          AppMessages.savingError(context, e.toString());
        }
      }
    }

    nameController.dispose();
    descriptionController.dispose();
  }

  Future<void> _savePlant() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final quantity = int.parse(_quantityController.text);
      final baseName = _nameController.text;

      AppLogger.info('AddPlantScreen', 'Saving $quantity plant(s) with growId: $_selectedGrowId');

      for (int i = 1; i <= quantity; i++) {
        final plantName = quantity > 1 ? '$baseName #$i' : baseName;

        // ✅ Seed-Datum ohne Uhrzeit
        DateTime effectiveSeedDate;
        if (_seedDate != null) {
          effectiveSeedDate = DateTime(_seedDate!.year, _seedDate!.month, _seedDate!.day);
        } else {
          final now = DateTime.now();
          effectiveSeedDate = DateTime(now.year, now.month, now.day);
        }

        final plant = Plant(
          name: plantName,
          strain: _strainController.text.isNotEmpty ? _strainController.text : null,
          breeder: _breederController.text.isNotEmpty ? _breederController.text : null,
          feminized: _genderType == GenderType.feminized,  // ✅ KORRIGIERT: Verwende GenderType
          seedType: _seedType,
          medium: _medium,
          phase: _phase,
          growId: _selectedGrowId,
          roomId: _selectedRoomId,
          seedDate: effectiveSeedDate,
          phaseStartDate: effectiveSeedDate,
          createdBy: 'User',
          currentContainerSize: _containerSizeController.text.isNotEmpty
              ? double.tryParse(_containerSizeController.text)
              : null,
          currentSystemSize: _systemSizeController.text.isNotEmpty
              ? double.tryParse(_systemSizeController.text)
              : null,
        );

        AppLogger.debug('AddPlantScreen', 'Plant #$i: ${plant.name}, growId: ${plant.growId}');
        await _plantRepo.save(plant);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.plantCreated(context, quantity);
      }
    } catch (e) {
      AppLogger.error('AddPlantScreen', 'Error saving: $e');
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
        title: const Text('Neue Pflanze'),
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
              _buildSaveButton(),
              const SizedBox(height: 16),
            ]
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
            hintText: 'z.B. Wedding Cake',
            prefixIcon: Icon(Icons.spa),
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
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Anzahl',
            hintText: '1-50',
            prefixIcon: Icon(Icons.filter_list, color: const Color(0xFF004225)),
            border: const OutlineInputBorder(),
            helperText: 'Wie viele Pflanzen erstellen?',
          ),
          validator: (value) {
            final count = int.tryParse(value ?? '');
            if (count == null || count < 1 || count > 50) {
              return 'Zahl zwischen 1-50';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _strainController,
          decoration: const InputDecoration(
            labelText: 'Strain',
            hintText: 'z.B. Wedding Cake',
            prefixIcon: Icon(Icons.local_florist),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _breederController,
          decoration: const InputDecoration(
            labelText: 'Breeder',
            hintText: 'z.B. Barney\'s Farm',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  // ✅ KORRIGIERT: Genetik-Bereich mit Dropdown statt Switch
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
        // ✅ KORRIGIERT: Dropdown statt Switch
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
          Column(
            children: [
              DropdownButtonFormField<int?>(
                initialValue: _selectedGrowId,
                decoration: InputDecoration(
                  labelText: widget.preselectedGrowId != null ? 'Grow (vorgegeben)' : 'Grow (optional)',
                  prefixIcon: Icon(Icons.eco, color: const Color(0xFF004225)),
                  border: const OutlineInputBorder(),
                  helperText: widget.preselectedGrowId != null
                      ? 'Diese Pflanze wird diesem Grow zugeordnet'
                      : 'Mehrere Pflanzen zu einem Grow zusammenfassen',
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
                onChanged: widget.preselectedGrowId != null
                    ? null
                    : (value) => setState(() => _selectedGrowId = value),
              ),
              if (widget.preselectedGrowId == null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _createNewGrow,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Neuen Grow erstellen'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF004225),
                  ),
                ),
              ],
            ],
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
          _isHydroSystem ? 'System Info (optional)' : 'Container Info (optional)',
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

  // ✅ KORRIGIERT: Unterstützung für GenderType hinzugefügt
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
          displayName = (item as GenderType).displayName;  // ✅ NEU
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.calendar_today, color: Colors.grey[700]),
              title: const Text('Seed-Datum'),
              subtitle: Text(
                _seedDate != null
                    ? '${_seedDate!.day}.${_seedDate!.month}.${_seedDate!.year}'
                    : 'Nicht gesetzt (wird auf Erstellungszeitpunkt gesetzt)',
                style: TextStyle(
                  color: _seedDate != null ? null : Colors.orange[700],
                  fontStyle: _seedDate != null ? null : FontStyle.italic,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_seedDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        if (mounted) {
                          setState(() => _seedDate = null);
                        }
                      },
                      tooltip: 'Datum zurücksetzen',
                    ),
                  const Icon(Icons.edit),
                ],
              ),
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
            ),
            if (_seedDate == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tipp: Setze ein Datum für genaueres Day-Tracking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _savePlant,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: const Text('Pflanze(n) erstellen'),
    );
  }
}