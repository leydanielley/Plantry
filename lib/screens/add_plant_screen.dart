// =============================================
// GROWLOG - Add Plant Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/di/service_locator.dart';

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
  
  late AppTranslations _t;
  final _nameController = TextEditingController();
  final _strainController = TextEditingController();
  final _breederController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  SeedType _seedType = SeedType.photo;
  GenderType _genderType = GenderType.feminized;
  Medium _medium = Medium.erde;
  final PlantPhase _phase = PlantPhase.seedling;
  int? _selectedGrowId;
  int? _selectedRdwcSystemId;
  int? _selectedRoomId;
  DateTime? _seedDate;

  List<Grow> _grows = [];
  List<RdwcSystem> _rdwcSystems = [];
  List<Room> _rooms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedGrowId = widget.preselectedGrowId;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  Future<void> _loadData() async {
    final res = await Future.wait([
      _roomRepo.findAll(),
      _growRepo.getAll(),
      _rdwcRepo.getAllSystems(),
    ]);
    if (mounted) {
      setState(() {
        _rooms = res[0] as List<Room>;
        _grows = res[1] as List<Grow>;
        _rdwcSystems = res[2] as List<RdwcSystem>;
        // Auto-set room if grow is preselected
        if (_selectedGrowId != null) {
          final grow = _grows.where((g) => g.id == _selectedGrowId).firstOrNull;
          if (grow?.roomId != null) _selectedRoomId = grow!.roomId;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['add_plant_title'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Basis Info'),
                  PlantryFormField(controller: _nameController, label: _t['add_plant_name_label'], hint: 'z.B. White Widow #1', validator: (v) => v!.isEmpty ? 'Name erforderlich' : null),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _quantityController, label: _t['add_plant_quantity'], keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _strainController, label: _t['add_plant_strain']),
                  const SizedBox(height: 24),
                  
                  _section('Genetik'),
                  _dropdown<SeedType>(_t['add_plant_seed_type'], _seedType, SeedType.values, (v) => setState(() => _seedType = v!)),
                  const SizedBox(height: 16),
                  _dropdown<GenderType>(_t['add_plant_gender'], _genderType, GenderType.values, (v) => setState(() => _genderType = v!)),
                  const SizedBox(height: 24),

                  _section('Setup'),
                  _dropdown<Medium>(_t['add_plant_medium'], _medium, Medium.values, (v) {
                    setState(() {
                      _medium = v!;
                      if (v != Medium.rdwc) _selectedRdwcSystemId = null;
                    });
                  }),
                  const SizedBox(height: 16),
                  if (_medium == Medium.rdwc) ...[
                    _rdwcDropdown(),
                    const SizedBox(height: 16),
                  ],
                  _growDropdown(),
                  const SizedBox(height: 16),
                  _roomDropdown(),
                  const SizedBox(height: 24),

                  _section('Datum'),
                  _dateTile(),
                  const SizedBox(height: 32),

                  PlantryButton(label: _t['add_plant_create_button'], onPressed: _save, fullWidth: true),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));

  Widget _dropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: DT.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: DT.elevated,
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(_getLabel(i), style: const TextStyle(color: DT.textPrimary)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  String _getLabel(dynamic i) {
    if (i is SeedType) return i.displayName;
    if (i is GenderType) return i.displayName;
    if (i is Medium) return i.displayName;
    if (i is PlantPhase) return i.displayName;
    return i.toString();
  }

  Widget _growDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Grow (Optional)', style: TextStyle(color: DT.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedGrowId,
              isExpanded: true,
              dropdownColor: DT.elevated,
              items: [
                DropdownMenuItem(value: null, child: Text(_t['no_grow'], style: const TextStyle(color: DT.textPrimary))),
                ..._grows.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name, style: const TextStyle(color: DT.textPrimary)))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedGrowId = v;
                  // Auto-set room from grow (or clear if grow has no room)
                  if (v != null) {
                    final grow = _grows.where((g) => g.id == v).firstOrNull;
                    _selectedRoomId = grow?.roomId;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Raum (Optional)', style: TextStyle(color: DT.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedRoomId,
              isExpanded: true,
              dropdownColor: DT.elevated,
              items: [
                const DropdownMenuItem(value: null, child: Text('Kein Raum', style: TextStyle(color: DT.textPrimary))),
                ..._rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name, style: const TextStyle(color: DT.textPrimary)))),
              ],
              onChanged: (v) => setState(() => _selectedRoomId = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rdwcDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RDWC System', style: TextStyle(color: DT.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedRdwcSystemId,
              isExpanded: true,
              dropdownColor: DT.elevated,
              items: [
                DropdownMenuItem(value: null, child: Text(_t['choose_system'], style: const TextStyle(color: DT.textPrimary))),
                ..._rdwcSystems.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: DT.textPrimary)))),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedRdwcSystemId = v;
                  // Auto-set room from RDWC system
                  if (v != null) {
                    final sys = _rdwcSystems.where((s) => s.id == v).firstOrNull;
                    if (sys?.roomId != null) _selectedRoomId = sys!.roomId;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateTile() {
    return PlantryCard(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _seedDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
        if (d != null) setState(() => _seedDate = d);
      },
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: DT.accent, size: 20),
          const SizedBox(width: 12),
          Text(_seedDate == null ? 'Kein Datum gesetzt' : '${_seedDate!.day}.${_seedDate!.month}.${_seedDate!.year}', style: const TextStyle(color: DT.textPrimary)),
          const Spacer(),
          Text(_t['change_btn'], style: const TextStyle(color: DT.accent, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final qty = int.tryParse(_quantityController.text) ?? 1;
      for (int i = 1; i <= qty; i++) {
        final p = Plant(
          name: qty > 1 ? '${_nameController.text} #$i' : _nameController.text,
          strain: _strainController.text,
          breeder: _breederController.text,
          feminized: _genderType == GenderType.feminized,
          seedType: _seedType,
          medium: _medium,
          phase: _phase,
          growId: _selectedGrowId,
          roomId: _selectedRoomId,
          rdwcSystemId: _selectedRdwcSystemId,
          seedDate: _seedDate ?? DateTime.now(),
          phaseStartDate: _seedDate ?? DateTime.now(),
          createdBy: 'User',
        );
        await _plantRepo.save(p);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
