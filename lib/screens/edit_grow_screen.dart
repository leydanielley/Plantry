// =============================================
// GROWLOG - Edit Grow Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/repositories/interfaces/i_grow_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/utils/translations.dart';

class EditGrowScreen extends StatefulWidget {
  final Grow grow;
  const EditGrowScreen({super.key, required this.grow});

  @override
  State<EditGrowScreen> createState() => _EditGrowScreenState();
}

class _EditGrowScreenState extends State<EditGrowScreen> {
  final _formKey = GlobalKey<FormState>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  late TextEditingController _nameController;
  late TextEditingController _descController;

  late AppTranslations _t;
  late DateTime _startDate;
  int? _selectedRoomId;
  List<Room> _rooms = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.grow.name);
    _descController = TextEditingController(text: widget.grow.description ?? '');
    _startDate = widget.grow.startDate;
    _selectedRoomId = widget.grow.roomId;
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  Future<void> _loadData() async {
    final rooms = await _roomRepo.findAll();
    if (mounted) setState(() => _rooms = rooms);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: 'Grow bearbeiten',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(controller: _nameController, label: 'Name', validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _descController, label: 'Beschreibung', maxLines: 3),
                  const SizedBox(height: 24),

                  _section('Raumzuordnung'),
                  _roomDropdown(),
                  const SizedBox(height: 24),

                  _section('Zeitplan'),
                  _dateTile(),
                  const SizedBox(height: 32),

                  PlantryButton(label: 'Änderungen speichern', onPressed: _save, fullWidth: true),
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
          value: _selectedRoomId, isExpanded: true, dropdownColor: DT.elevated,
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
          const Icon(Icons.edit, color: DT.accent, size: 18),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _growRepo.update(widget.grow.copyWith(name: _nameController.text, description: _descController.text, startDate: _startDate, roomId: _selectedRoomId));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
