// =============================================
// GROWLOG - Add Grow Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/utils/app_messages.dart';

class AddGrowScreen extends StatefulWidget {
  const AddGrowScreen({super.key});

  @override
  State<AddGrowScreen> createState() => _AddGrowScreenState();
}

class _AddGrowScreenState extends State<AddGrowScreen> {
  final _formKey = GlobalKey<FormState>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  late AppTranslations _t;

  DateTime _startDate = DateTime.now();
  int? _selectedRoomId;
  List<Room> _rooms = [];
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
    if (_nameController.text.isEmpty) {
      _nameController.text = 'Grow ${DateTime.now().year}-${DateTime.now().month}';
    }
  }

  Future<void> _loadData() async {
    final rooms = await _roomRepo.findAll();
    if (mounted) setState(() => _rooms = rooms);
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['add_grow_title'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(controller: _nameController, label: _t['add_grow_name_label'], hint: 'z.B. Winter Grow 2024', validator: (v) => v!.isEmpty ? 'Name erforderlich' : null),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _descriptionController, label: _t['add_grow_description_label'], maxLines: 3),
                  const SizedBox(height: 24),
                  
                  _section('Raumzuordnung'),
                  _roomDropdown(),
                  const SizedBox(height: 24),

                  _section('Zeitplan'),
                  _dateTile(),
                  const SizedBox(height: 32),

                  PlantryButton(label: _t['add_grow_create_button'], onPressed: _save, fullWidth: true),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));

  Widget _roomDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _selectedRoomId,
          isExpanded: true,
          dropdownColor: DT.elevated,
          items: [
            DropdownMenuItem(value: null, child: Text(_t['add_grow_no_room'], style: const TextStyle(color: DT.textPrimary))),
            ..._rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name, style: const TextStyle(color: DT.textPrimary)))),
          ],
          onChanged: (v) => setState(() => _selectedRoomId = v),
        ),
      ),
    );
  }

  Widget _dateTile() {
    return PlantryCard(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
        if (d != null) setState(() => _startDate = d);
      },
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: DT.accent, size: 20),
          const SizedBox(width: 12),
          Text('${_startDate.day}.${_startDate.month}.${_startDate.year}', style: const TextStyle(color: DT.textPrimary)),
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
      final g = Grow(name: _nameController.text, description: _descriptionController.text, startDate: _startDate, roomId: _selectedRoomId);
      await _growRepo.create(g);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessages.showError(context, 'Fehler beim Speichern');
      setState(() => _isLoading = false);
    }
  }
}
