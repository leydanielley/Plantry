// =============================================
// GROWLOG - Edit Plant Screen
// =============================================

import 'package:flutter/material.dart';
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
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class EditPlantScreen extends StatefulWidget {
  final Plant plant;
  const EditPlantScreen({super.key, required this.plant});

  @override
  State<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends State<EditPlantScreen> {
  late AppTranslations _t;
  final _formKey = GlobalKey<FormState>();
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();

  late TextEditingController _nameController;
  late TextEditingController _strainController;
  late TextEditingController _breederController;

  late SeedType _seedType;
  late GenderType _genderType;
  late Medium _medium;
  late PlantPhase _phase;
  int? _selectedGrowId;
  int? _selectedRdwcId;
  int? _selectedRoomId;
  DateTime? _seedDate;
  bool _isLoading = false;

  List<Grow> _grows = [];
  List<RdwcSystem> _rdwcSystems = [];
  List<Room> _rooms = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plant.name);
    _strainController = TextEditingController(text: widget.plant.strain ?? '');
    _breederController = TextEditingController(
      text: widget.plant.breeder ?? '',
    );
    _seedType = widget.plant.seedType;
    _genderType = widget.plant.feminized
        ? GenderType.feminized
        : GenderType.regular;
    _medium = widget.plant.medium;
    _phase = widget.plant.phase;
    _selectedGrowId = widget.plant.growId;
    _selectedRdwcId = widget.plant.rdwcSystemId;
    _selectedRoomId = widget.plant.roomId;
    _seedDate = widget.plant.seedDate;
    _loadData();
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: 'Pflanze bearbeiten',
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: DT.error),
          onPressed: _delete,
        ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(
                    controller: _nameController,
                    label: 'Name',
                    validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null,
                  ),
                  const SizedBox(height: 16),
                  PlantryFormField(
                    controller: _strainController,
                    label: 'Strain',
                  ),
                  const SizedBox(height: 24),

                  _section('Genetik & Phase'),
                  _dropdown<PlantPhase>(
                    'Phase',
                    _phase,
                    PlantPhase.values,
                    (v) => setState(() => _phase = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdown<SeedType>(
                          'Typ',
                          _seedType,
                          SeedType.values,
                          (v) => setState(() => _seedType = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dropdown<GenderType>(
                          'Geschlecht',
                          _genderType,
                          GenderType.values,
                          (v) => setState(() => _genderType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _section('Setup'),
                  _dropdown<Medium>('Medium', _medium, Medium.values, (v) {
                    setState(() {
                      _medium = v!;
                      if (v != Medium.rdwc) _selectedRdwcId = null;
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

                  PlantryButton(
                    label: 'Änderungen speichern',
                    onPressed: _save,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: DT.textSecondary,
      ),
    ),
  );

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: DT.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: DT.elevated,
            borderRadius: BorderRadius.circular(DT.radiusInput),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: DT.elevated,
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        _getLabel(i),
                        style: const TextStyle(color: DT.textPrimary),
                      ),
                    ),
                  )
                  .toList(),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: DT.elevated,
        borderRadius: BorderRadius.circular(DT.radiusInput),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedGrowId,
          isExpanded: true,
          dropdownColor: DT.elevated,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                _t['no_grow'],
                style: const TextStyle(color: DT.textPrimary),
              ),
            ),
            ..._grows.map(
              (g) => DropdownMenuItem(
                value: g.id,
                child: Text(
                  g.name,
                  style: const TextStyle(color: DT.textPrimary),
                ),
              ),
            ),
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
    );
  }

  Widget _rdwcDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: DT.elevated,
        borderRadius: BorderRadius.circular(DT.radiusInput),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedRdwcId,
          isExpanded: true,
          dropdownColor: DT.elevated,
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(
                _t['choose_system'],
                style: const TextStyle(color: DT.textPrimary),
              ),
            ),
            ..._rdwcSystems.map(
              (s) => DropdownMenuItem(
                value: s.id,
                child: Text(
                  s.name,
                  style: const TextStyle(color: DT.textPrimary),
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() => _selectedRdwcId = v),
        ),
      ),
    );
  }

  Widget _roomDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Raum (Optional)',
          style: TextStyle(color: DT.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: DT.elevated,
            borderRadius: BorderRadius.circular(DT.radiusInput),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: _selectedRoomId,
              isExpanded: true,
              dropdownColor: DT.elevated,
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(
                    _t['no_room'],
                    style: const TextStyle(color: DT.textPrimary),
                  ),
                ),
                ..._rooms.map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(
                      r.name,
                      style: const TextStyle(color: DT.textPrimary),
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedRoomId = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateTile() {
    return PlantryCard(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _seedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (d != null) setState(() => _seedDate = d);
      },
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: DT.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            _seedDate == null
                ? 'Kein Datum'
                : '${_seedDate!.day}.${_seedDate!.month}.${_seedDate!.year}',
            style: const TextStyle(color: DT.textPrimary),
          ),
          const Spacer(),
          const Icon(Icons.edit, color: DT.accent, size: 18),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final p = widget.plant.copyWith(
        name: _nameController.text,
        strain: _strainController.text,
        breeder: _breederController.text,
        feminized: _genderType == GenderType.feminized,
        seedType: _seedType,
        medium: _medium,
        phase: _phase,
        growId: _selectedGrowId,
        roomId: _selectedRoomId,
        rdwcSystemId: _selectedRdwcId,
        seedDate: _seedDate,
      );
      await _plantRepo.save(p);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessages.showError(context, 'Fehler beim Speichern');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(
          _t['confirm_archive'],
          style: const TextStyle(color: DT.textPrimary),
        ),
        content: Text(
          _t['plant_will_be_archived'],
          style: const TextStyle(color: DT.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              _t['cancel'],
              style: const TextStyle(color: DT.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t['archive'], style: const TextStyle(color: DT.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _plantRepo.delete(widget.plant.id!);
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }
}
