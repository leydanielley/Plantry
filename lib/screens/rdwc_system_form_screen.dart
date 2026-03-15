// =============================================
// GROWLOG - RDWC System Form
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class RdwcSystemFormScreen extends StatefulWidget {
  final RdwcSystem? system;
  const RdwcSystemFormScreen({super.key, this.system});

  @override
  State<RdwcSystemFormScreen> createState() => _RdwcSystemFormScreenState();
}

class _RdwcSystemFormScreenState extends State<RdwcSystemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  
  late TextEditingController _nameController;
  late TextEditingController _capacityController;
  late TextEditingController _bucketsController;
  late TextEditingController _ecMinController;
  late TextEditingController _ecMaxController;
  
  late AppTranslations _t;
  List<Room> _rooms = [];
  int? _selectedRoomId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.system?.name ?? '');
    _capacityController = TextEditingController(text: widget.system?.maxCapacity.toString() ?? '100');
    _bucketsController = TextEditingController(text: widget.system?.bucketCount.toString() ?? '4');
    _ecMinController = TextEditingController(text: widget.system?.ecWarningMin?.toString() ?? '');
    _ecMaxController = TextEditingController(text: widget.system?.ecWarningMax?.toString() ?? '');
    _selectedRoomId = widget.system?.roomId;
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = await _settingsRepo.getSettings();
    final rooms = await _roomRepo.findAll();
    if (mounted) setState(() { _t = AppTranslations(settings.language); _rooms = rooms; _isLoading = false; });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    _bucketsController.dispose();
    _ecMinController.dispose();
    _ecMaxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: widget.system == null ? _t['add_rdwc_system'] : _t['edit_rdwc_system'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(controller: _nameController, label: _t['system_name'], hint: 'z.B. Hauptzelt System', validator: (v) => v!.isEmpty ? _t['required_field'] : null),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: PlantryFormField(controller: _capacityController, label: _t['max_capacity'], keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(controller: _bucketsController, label: _t['bucket_count'], keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 24),
                  
                  _section(_t['ec_target_hint']),
                  Row(children: [
                    Expanded(child: PlantryFormField(
                      controller: _ecMinController,
                      label: _t['ec_target_min'],
                      hint: 'z.B. 1.4',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && double.tryParse(v) == null) return _t['invalid_number'];
                        return null;
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(
                      controller: _ecMaxController,
                      label: _t['ec_target_max'],
                      hint: 'z.B. 2.0',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && double.tryParse(v) == null) return _t['invalid_number'];
                        return null;
                      },
                    )),
                  ]),
                  const SizedBox(height: 24),

                  _section(_t['add_grow_room_section']),
                  _roomDropdown(),
                  const SizedBox(height: 32),

                  PlantryButton(label: _t['save'], onPressed: _isSaving ? null : _save, fullWidth: true),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final cap = double.tryParse(_capacityController.text) ?? 100;
      final bc = int.tryParse(_bucketsController.text) ?? 4;
      final ecMin = _ecMinController.text.isNotEmpty ? double.tryParse(_ecMinController.text) : null;
      final ecMax = _ecMaxController.text.isNotEmpty ? double.tryParse(_ecMaxController.text) : null;

      if (widget.system == null) {
        await _rdwcRepo.createSystem(RdwcSystem(name: _nameController.text, maxCapacity: cap, currentLevel: cap, bucketCount: bc, roomId: _selectedRoomId, ecWarningMin: ecMin, ecWarningMax: ecMax));
      } else {
        await _rdwcRepo.updateSystem(widget.system!.copyWith(name: _nameController.text, maxCapacity: cap, bucketCount: bc, roomId: _selectedRoomId, ecWarningMin: ecMin, ecWarningMax: ecMax));
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      AppLogger.error('RDWC Form', 'Error saving system', e);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t['error_saving']), backgroundColor: Colors.red),
        );
      }
    }
  }
}
