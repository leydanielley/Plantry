// =============================================
// GROWLOG - Add Room Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
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

  late AppTranslations _t;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _widthController = TextEditingController();
  final _depthController = TextEditingController();
  final _heightController = TextEditingController();
  final _wattsController = TextEditingController();

  GrowType _growType = GrowType.indoor;
  WateringSystem _wateringSystem = WateringSystem.manual;
  int? _selectedRdwcId;
  List<RdwcSystem> _rdwcSystems = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  Future<void> _loadData() async {
    final systems = await _rdwcRepo.getAllSystems();
    if (mounted) setState(() => _rdwcSystems = systems);
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['add_room_title'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(controller: _nameController, label: _t['add_room_name_label'], hint: 'z.B. Zelt 1', validator: (v) => v!.isEmpty ? 'Name erforderlich' : null),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _descController, label: _t['add_room_description_label'], maxLines: 2),
                  const SizedBox(height: 24),

                  _section('Setup'),
                  _dropdown<GrowType>('Umgebung', _growType, GrowType.values, (v) => setState(() => _growType = v!)),
                  const SizedBox(height: 16),
                  _dropdown<WateringSystem>('Bewässerung', _wateringSystem, WateringSystem.values, (v) => setState(() => _wateringSystem = v!)),
                  const SizedBox(height: 16),
                  if (_wateringSystem == WateringSystem.rdwc) ...[
                    _rdwcDropdown(),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),

                  _section('Maße (in cm)'),
                  Row(
                    children: [
                      Expanded(child: PlantryFormField(controller: _widthController, label: 'Breite', keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: PlantryFormField(controller: _depthController, label: 'Tiefe', keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: PlantryFormField(controller: _heightController, label: 'Höhe', keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PlantryFormField(
                    controller: _wattsController,
                    label: _t['light_watts'],
                    hint: 'z.B. 600',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),

                  PlantryButton(label: _t['add_room_save_button'], onPressed: _save, fullWidth: true),
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
    if (i is GrowType) return i.displayName;
    if (i is WateringSystem) return i.displayName;
    return i.toString();
  }

  Widget _rdwcDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedRdwcId,
          isExpanded: true,
          dropdownColor: DT.elevated,
          items: [
            const DropdownMenuItem(value: null, child: Text('System wählen...', style: TextStyle(color: DT.textPrimary))),
            ..._rdwcSystems.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(color: DT.textPrimary)))),
          ],
          onChanged: (v) => setState(() => _selectedRdwcId = v),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final r = Room(
        name: _nameController.text,
        description: _descController.text,
        growType: _growType,
        wateringSystem: _wateringSystem,
        rdwcSystemId: _selectedRdwcId,
        width: (double.tryParse(_widthController.text) ?? 0) / 100,
        depth: (double.tryParse(_depthController.text) ?? 0) / 100,
        height: (double.tryParse(_heightController.text) ?? 0) / 100,
        lightWatts: int.tryParse(_wattsController.text),
      );
      await _roomRepo.save(r);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
