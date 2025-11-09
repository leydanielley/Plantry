// =============================================
// GROWLOG - Add Plant Screen (✅ KORRIGIERT: Genetik-Bereich)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../models/plant.dart';
import '../models/room.dart';
import '../models/grow.dart';
import '../models/rdwc_system.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import '../repositories/interfaces/i_room_repository.dart';
import '../repositories/interfaces/i_grow_repository.dart';
import '../repositories/interfaces/i_rdwc_repository.dart';
import '../utils/app_messages.dart';
import '../di/service_locator.dart';

class AddPlantScreen extends StatefulWidget {
  final int? preselectedGrowId;

  const AddPlantScreen({super.key, this.preselectedGrowId});

  @override
  State<AddPlantScreen> createState() => _AddPlantScreenState();
}

class _AddPlantScreenState extends State<AddPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();

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
  int? _selectedRdwcSystemId;
  int? _selectedBucketNumber;
  DateTime? _seedDate;

  List<Room> _rooms = [];
  List<Grow> _grows = [];
  List<RdwcSystem> _rdwcSystems = [];
  List<int> _occupiedBuckets = [];
  bool _isLoading = false;
  bool _loadingRooms = true;
  bool _loadingGrows = true;
  bool _loadingRdwcSystems = true;

  @override
  void initState() {
    super.initState();
    _selectedGrowId = widget.preselectedGrowId;
    _loadRooms();
    _loadGrows();
    _loadRdwcSystems();
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

  Future<void> _loadRdwcSystems() async {
    try {
      final systems = await _rdwcRepo.getAllSystems();
      if (mounted) {
        setState(() {
          _rdwcSystems = systems;
          _loadingRdwcSystems = false;
        });
      }
    } catch (e) {
      AppLogger.error('AddPlantScreen', 'Error loading RDWC systems: $e');
      if (mounted) {
        setState(() => _loadingRdwcSystems = false);
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

  /// Get occupied bucket numbers for an RDWC system
  Future<List<int>> _getOccupiedBuckets(int systemId) async {
    final plants = await _plantRepo.findByRdwcSystem(systemId);
    return plants
        .where((p) => p.bucketNumber != null)
        .map((p) => p.bucketNumber!)
        .toList();
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

      // Bei RDWC: Verfügbare Buckets ermitteln für Auto-Assignment
      List<int>? availableBuckets;
      if (_medium == Medium.rdwc && _selectedRdwcSystemId != null && quantity > 1) {
        final occupiedBuckets = await _getOccupiedBuckets(_selectedRdwcSystemId!);
        final selectedSystem = _rdwcSystems.firstWhere((s) => s.id == _selectedRdwcSystemId);
        availableBuckets = [];
        for (int b = 1; b <= selectedSystem.bucketCount; b++) {
          if (!occupiedBuckets.contains(b)) {
            availableBuckets.add(b);
          }
        }

        // Prüfen ob genug Buckets frei sind
        if (availableBuckets.length < quantity) {
          if (mounted) {
            AppMessages.showError(
              context,
              'Nur ${availableBuckets.length} freie Buckets verfügbar, aber $quantity Plants gewählt!',
            );
          }
          return;
        }
      }

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

        // ✅ FIX: Bei Multiple Plants automatisch Buckets verteilen
        int? assignedBucket;
        if (_medium == Medium.rdwc && _selectedRdwcSystemId != null) {
          if (quantity > 1 && availableBuckets != null) {
            // Automatische Zuweisung: Nimm nächsten freien Bucket
            assignedBucket = availableBuckets[i - 1];
            AppLogger.debug('AddPlantScreen', 'Auto-assigning plant #$i to bucket $assignedBucket');
          } else {
            // Single plant: Verwende gewählten Bucket
            assignedBucket = _selectedBucketNumber;
          }
        }

        final plant = Plant(
          name: plantName,
          strain: _strainController.text.isNotEmpty ? _strainController.text : null,
          breeder: _breederController.text.isNotEmpty ? _breederController.text : null,
          feminized: _genderType == GenderType.feminized,
          seedType: _seedType,
          medium: _medium,
          phase: _phase,
          growId: _selectedGrowId,
          roomId: _medium == Medium.rdwc ? null : _selectedRoomId,
          rdwcSystemId: _medium == Medium.rdwc ? _selectedRdwcSystemId : null,
          bucketNumber: assignedBucket,
          seedDate: effectiveSeedDate,
          phaseStartDate: effectiveSeedDate,
          createdBy: 'User',
          currentContainerSize: _containerSizeController.text.isNotEmpty
              ? double.tryParse(_containerSizeController.text)
              : null,
          currentSystemSize: _medium == Medium.rdwc ? null : (
            _systemSizeController.text.isNotEmpty
                ? double.tryParse(_systemSizeController.text)
                : null
          ),
        );

        AppLogger.debug('AddPlantScreen', 'Plant #$i: ${plant.name}, bucket: $assignedBucket');
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
          decoration: const InputDecoration(
            labelText: 'Anzahl',
            hintText: '1-50',
            prefixIcon: Icon(Icons.filter_list, color: Color(0xFF004225)),
            border: OutlineInputBorder(),
            helperText: 'Wie viele Pflanzen erstellen?',
          ),
          onChanged: (value) {
            // Trigger rebuild to update bucket info
            setState(() {});
          },
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
          onChanged: (value) {
            setState(() {
              _medium = value!;
              // Reset RDWC/Room selections when changing medium
              if (_medium == Medium.rdwc) {
                _selectedRoomId = null;
              } else {
                _selectedRdwcSystemId = null;
                _selectedBucketNumber = null;
              }
            });
          },
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
                  prefixIcon: const Icon(Icons.eco, color: Color(0xFF004225)),
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
        // RDWC System Selection (nur wenn Medium = RDWC)
        if (_medium == Medium.rdwc) ...[
          if (_loadingRdwcSystems)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<int?>(
              initialValue: _selectedRdwcSystemId,
              decoration: const InputDecoration(
                labelText: 'RDWC System *',
                prefixIcon: Icon(Icons.water),
                border: OutlineInputBorder(),
                helperText: 'Wähle das RDWC System für diese Pflanze',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Kein System')),
                ..._rdwcSystems.map((system) {
                  return DropdownMenuItem(
                    value: system.id,
                    child: Text('${system.name} (${system.bucketCount} Buckets)'),
                  );
                }),
              ],
              onChanged: (value) async {
                setState(() {
                  _selectedRdwcSystemId = value;
                  _selectedBucketNumber = null; // Reset bucket number
                  _occupiedBuckets = []; // Reset
                });
                // Load occupied buckets for this system
                if (value != null) {
                  final occupied = await _getOccupiedBuckets(value);
                  if (mounted) {
                    setState(() => _occupiedBuckets = occupied);
                  }
                }
              },
              validator: (value) {
                if (_medium == Medium.rdwc && value == null) {
                  return 'RDWC System erforderlich';
                }
                return null;
              },
            ),
          const SizedBox(height: 12),
          // Bucket Number Selection (nur wenn System gewählt)
          if (_selectedRdwcSystemId != null)
            Builder(
              builder: (context) {
                final selectedSystem = _rdwcSystems.firstWhere(
                  (s) => s.id == _selectedRdwcSystemId,
                  orElse: () => _rdwcSystems.first,
                );

                // Bei Quantity > 1: Keine manuelle Auswahl, automatische Verteilung
                final quantity = int.tryParse(_quantityController.text) ?? 1;

                if (quantity > 1) {
                  // Zeige Info über automatische Verteilung
                  final freeBuckets = <int>[];
                  for (int b = 1; b <= selectedSystem.bucketCount; b++) {
                    if (!_occupiedBuckets.contains(b)) {
                      freeBuckets.add(b);
                    }
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Automatische Verteilung:\nBuckets ${freeBuckets.take(quantity).join(', ')} werden verwendet',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Bei Single Plant: Zeige nur freie Buckets
                return DropdownButtonFormField<int?>(
                  initialValue: _selectedBucketNumber,
                  decoration: InputDecoration(
                    labelText: 'Bucket Nummer *',
                    prefixIcon: const Icon(Icons.filter_list),
                    border: const OutlineInputBorder(),
                    helperText: '${_occupiedBuckets.length}/${selectedSystem.bucketCount} Buckets belegt',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Wähle Bucket')),
                    ...List.generate(selectedSystem.bucketCount, (index) {
                      final bucketNum = index + 1;
                      final isOccupied = _occupiedBuckets.contains(bucketNum);
                      if (isOccupied) return null;
                      return DropdownMenuItem(
                        value: bucketNum,
                        child: Text('Bucket $bucketNum'),
                      );
                    }).whereType<DropdownMenuItem<int?>>(),
                  ],
                  onChanged: (value) => setState(() => _selectedBucketNumber = value),
                  validator: (value) {
                    if (_medium == Medium.rdwc && _selectedRdwcSystemId != null && value == null) {
                      return 'Bucket Nummer erforderlich';
                    }
                    return null;
                  },
                );
              },
            ),
        ]
        // Room Selection (nur wenn NICHT RDWC)
        else if (_loadingRooms)
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
    // Bei RDWC: System Size kommt vom RDWC System, nicht von der Plant
    if (_medium == Medium.rdwc) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'System-Größe wird vom RDWC System übernommen',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

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
              helperText: 'Gesamtgröße des Hydro-Systems (DWC/Hydro)',
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