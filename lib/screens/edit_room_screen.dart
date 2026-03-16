// =============================================
// GROWLOG - Edit Room Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

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
  
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _widthController;
  late TextEditingController _depthController;
  late TextEditingController _heightController;
  late TextEditingController _wattsController;

  GrowType? _growType;
  WateringSystem? _wateringSystem;
  int? _selectedRdwcId;
  List<RdwcSystem> _rdwcSystems = [];
  bool _isLoading = false;
  late AppTranslations _t;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room.name);
    _descController = TextEditingController(text: widget.room.description ?? '');
    _widthController = TextEditingController(text: (widget.room.width * 100).toInt().toString());
    _depthController = TextEditingController(text: (widget.room.depth * 100).toInt().toString());
    _heightController = TextEditingController(text: (widget.room.height * 100).toInt().toString());
    _wattsController = TextEditingController(text: widget.room.lightWatts?.toString() ?? '');
    _growType = widget.room.growType;
    _wateringSystem = widget.room.wateringSystem;
    _selectedRdwcId = widget.room.rdwcSystemId;
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
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _widthController.dispose();
    _depthController.dispose();
    _heightController.dispose();
    _wattsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['edit_room_title'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(controller: _nameController, label: _t['add_room_name_label'], validator: (v) => v!.isEmpty ? _t['error_field_required'] : null),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _descController, label: _t['add_room_description_label'], maxLines: 2),
                  const SizedBox(height: 24),

                  _section(_t['room_section_setup']),
                  _dropdown<GrowType>(_t['room_label_environment'], _growType ?? GrowType.indoor, GrowType.values, (v) => setState(() => _growType = v)),
                  const SizedBox(height: 16),
                  _dropdown<WateringSystem>(_t['room_label_watering'], _wateringSystem ?? WateringSystem.manual, WateringSystem.values, (v) => setState(() => _wateringSystem = v)),
                  const SizedBox(height: 16),
                  if (_wateringSystem == WateringSystem.rdwc) ...[_rdwcDropdown(), const SizedBox(height: 16)],

                  _section(_t['room_section_dimensions']),
                  Row(children: [
                    Expanded(child: PlantryFormField(controller: _widthController, label: _t['room_label_width'], keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(controller: _depthController, label: _t['room_label_depth'], keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(controller: _heightController, label: _t['room_label_height'], keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 16),
                  PlantryFormField(
                    controller: _wattsController,
                    label: _t['light_watts'],
                    hint: _t['room_hint_watts'],
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),

                  PlantryButton(label: _t['save_changes'], onPressed: _save, fullWidth: true),
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
              value: value, isExpanded: true, dropdownColor: DT.elevated,
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
          value: _selectedRdwcId, isExpanded: true, dropdownColor: DT.elevated,
          items: [
            DropdownMenuItem(value: null, child: Text(_t['select_system'], style: const TextStyle(color: DT.textPrimary))),
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
      final r = widget.room.copyWith(
        name: _nameController.text, description: _descController.text,
        growType: _growType, wateringSystem: _wateringSystem, rdwcSystemId: _selectedRdwcId,
        width: (double.tryParse(_widthController.text) ?? 0) / 100,
        depth: (double.tryParse(_depthController.text) ?? 0) / 100,
        height: (double.tryParse(_heightController.text) ?? 0) / 100,
        lightWatts: _wattsController.text.isEmpty ? null : int.tryParse(_wattsController.text),
      );
      await _roomRepo.save(r);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessages.showError(context, _t['error_saving']);
      setState(() => _isLoading = false);
    }
  }
}
