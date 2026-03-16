// =============================================
// GROWLOG - Edit Log Screen
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/models/photo.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_log_fertilizer_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/services/interfaces/i_log_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class EditLogScreen extends StatefulWidget {
  final Plant plant;
  final PlantLog log;

  const EditLogScreen({super.key, required this.plant, required this.log});

  @override
  State<EditLogScreen> createState() => _EditLogScreenState();
}

class _EditLogScreenState extends State<EditLogScreen> {
  final _formKey = GlobalKey<FormState>();
  late AppTranslations _t;
  final ILogService _logService = getIt<ILogService>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ILogFertilizerRepository _logFertilizerRepo = getIt<ILogFertilizerRepository>();
  final IPhotoRepository _photoRepo = getIt<IPhotoRepository>();
  final ImagePicker _imagePicker = ImagePicker();

  final _waterAmountController = TextEditingController();
  final _phInController = TextEditingController();
  final _ecInController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _humidityController = TextEditingController();
  final _noteController = TextEditingController();
  final _phOutController = TextEditingController();
  final _ecOutController = TextEditingController();
  final _containerSizeController = TextEditingController();
  final _systemReservoirSizeController = TextEditingController();

  late ActionType _selectedAction;
  bool _runoffEnabled = false;
  bool _cleanse = false;
  PlantPhase? _selectedNewPhase;
  late DateTime _selectedDate;
  bool _isLoading = false;
  late int _dayNumber;
  List<Fertilizer> _availableFertilizers = [];
  Map<int, double> _selectedFertilizers = {};

  List<Photo> _existingPhotos = [];
  final List<XFile> _newPhotos = [];
  final Set<int> _photosToDelete = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _loadFertilizers();
    _loadExistingPhotos();
  }

  Future<void> _loadExistingData() async {
    _selectedAction = widget.log.actionType;
    _selectedDate = widget.log.logDate;
    _dayNumber = widget.log.dayNumber;

    _waterAmountController.text = widget.log.waterAmount?.toString() ?? '';
    _phInController.text = widget.log.phIn?.toString() ?? '';
    _ecInController.text = widget.log.ecIn?.toString() ?? '';
    _temperatureController.text = widget.log.temperature?.toString() ?? '';
    _humidityController.text = widget.log.humidity?.toString() ?? '';
    _noteController.text = widget.log.note ?? '';
    _runoffEnabled = widget.log.phOut != null || widget.log.ecOut != null || widget.log.runoff;
    _cleanse = widget.log.cleanse;
    _phOutController.text = widget.log.phOut?.toString() ?? '';
    _ecOutController.text = widget.log.ecOut?.toString() ?? '';
    _containerSizeController.text = widget.log.containerSize?.toString() ?? '';
    _systemReservoirSizeController.text = widget.log.systemReservoirSize?.toString() ?? '';

    if (widget.log.id != null) {
      final logFerts = await _logFertilizerRepo.findByLog(widget.log.id!);
      if (mounted) {
        setState(() {
          _selectedFertilizers = {for (final lf in logFerts) lf.fertilizerId: lf.amount};
        });
      }
    }
  }

  Future<void> _loadExistingPhotos() async {
    if (widget.log.id != null) {
      final photos = await _photoRepo.getPhotosByLogId(widget.log.id!);
      if (mounted) setState(() => _existingPhotos = photos);
    }
  }

  Future<void> _loadFertilizers() async {
    final fertilizers = await _fertilizerRepo.findAll();
    if (mounted) setState(() => _availableFertilizers = fertilizers);
  }

  @override
  void dispose() {
    _waterAmountController.dispose();
    _phInController.dispose();
    _ecInController.dispose();
    _temperatureController.dispose();
    _humidityController.dispose();
    _noteController.dispose();
    _phOutController.dispose();
    _ecOutController.dispose();
    _containerSizeController.dispose();
    _systemReservoirSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['edit_log_title'].replaceAll('{plant}', widget.plant.name),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 24),
                  _buildActionSelector(),
                  const SizedBox(height: 24),
                  if (_selectedAction == ActionType.phaseChange) ...[
                    _buildPhaseSelector(),
                    const SizedBox(height: 24),
                  ],
                  _dateTile(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 24),
                  if (_selectedAction == ActionType.water || _selectedAction == ActionType.feed) ...[
                    _section(_t['section_water_values']),
                    PlantryFormField(controller: _waterAmountController, label: _t['label_water_amount'], keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: PlantryFormField(controller: _phInController, label: _t['label_ph_in'], keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: PlantryFormField(controller: _ecInController, label: _t['label_ec_in'], keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRunoffSection(),
                    const SizedBox(height: 8),
                    _buildCleanseRow(),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedAction == ActionType.feed) ...[
                    _buildFertilizerSection(),
                    const SizedBox(height: 24),
                  ],
                  if (_selectedAction == ActionType.transplant) ...[
                    _section(_t['section_container_system']),
                    Row(
                      children: [
                        Expanded(child: PlantryFormField(controller: _containerSizeController, label: _t['label_pot_size'], keyboardType: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(child: PlantryFormField(controller: _systemReservoirSizeController, label: _t['label_reservoir_size'], keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  _section(_t['section_environment_note']),
                  Row(
                    children: [
                      Expanded(child: PlantryFormField(controller: _temperatureController, label: _t['label_temperature'], keyboardType: TextInputType.number)),
                      const SizedBox(width: 12),
                      Expanded(child: PlantryFormField(controller: _humidityController, label: _t['label_humidity'], keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _noteController, label: _t['notes'], maxLines: 3),
                  const SizedBox(height: 32),
                  PlantryButton(label: _t['save_changes'], onPressed: _save, fullWidth: true),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return PlantryCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: DT.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit_note, color: DT.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_t['day']} $_dayNumber', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DT.textPrimary)),
              Text(widget.plant.name, style: const TextStyle(fontSize: 13, color: DT.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t['action'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: ActionType.values.map((a) {
            final sel = _selectedAction == a;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedAction = a;
                if (a != ActionType.phaseChange) _selectedNewPhase = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: sel ? DT.accent : DT.elevated, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? DT.accent : DT.border)),
                child: Text(a.displayName, style: TextStyle(color: sel ? DT.onAccent : DT.textSecondary, fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _dateTile() {
    return PlantryCard(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
        if (d != null) setState(() => _selectedDate = DateTime(d.year, d.month, d.day, _selectedDate.hour, _selectedDate.minute));
      },
      child: Row(
        children: [
          const Icon(Icons.access_time, color: DT.textTertiary, size: 20),
          const SizedBox(width: 12),
          Text(DateFormat('dd.MM.yyyy HH:mm').format(_selectedDate), style: const TextStyle(color: DT.textPrimary)),
          const Spacer(),
          const Icon(Icons.edit, color: DT.accent, size: 18),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_t['photos'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
          IconButton(icon: const Icon(Icons.add_a_photo, color: DT.accent, size: 20), onPressed: () => _pickPhoto(ImageSource.camera)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._existingPhotos.map((p) {
                final del = _photosToDelete.contains(p.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => del ? _photosToDelete.remove(p.id) : _photosToDelete.add(p.id!)),
                    child: Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Opacity(opacity: del ? 0.3 : 1.0, child: Image.file(File(p.filePath), width: 80, height: 80, fit: BoxFit.cover))),
                      if (del) const Positioned.fill(child: Icon(Icons.delete_forever, color: DT.error)),
                    ]),
                  ),
                );
              }),
              ..._newPhotos.map((p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(p.path), width: 80, height: 80, fit: BoxFit.cover)),
                  Positioned(top: 2, right: 2, child: GestureDetector(onTap: () => setState(() => _newPhotos.remove(p)), child: Container(color: DT.canvas.withValues(alpha: 0.54), child: const Icon(Icons.close, color: DT.textPrimary, size: 16)))),
                ]),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickPhoto(ImageSource src) async {
    final p = await _imagePicker.pickImage(source: src);
    if (p != null && mounted) setState(() => _newPhotos.add(p));
  }

  Widget _buildFertilizerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_t['fertilizers'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: DT.accent, size: 20), onPressed: _addFert),
        ]),
        ..._selectedFertilizers.entries.map((e) {
          final f = _availableFertilizers.firstWhere((f) => f.id == e.key, orElse: () => Fertilizer(name: _t['fertilizer_unknown']));
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PlantryCard(isFlat: true, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children: [
              Expanded(child: Text(f.name, style: const TextStyle(color: DT.textPrimary, fontSize: 13))),
              Text('${e.value}ml', style: const TextStyle(fontWeight: FontWeight.bold, color: DT.accent)),
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: DT.error, size: 18), onPressed: () => setState(() => _selectedFertilizers.remove(e.key))),
            ])),
          );
        }),
      ],
    );
  }

  Future<void> _addFert() async {
    final sel = await showDialog<Fertilizer>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['choose_fertilizer'], style: const TextStyle(color: DT.textPrimary)),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: _availableFertilizers.length, itemBuilder: (ctx, i) => ListTile(title: Text(_availableFertilizers[i].name, style: const TextStyle(color: DT.textPrimary)), onTap: () => Navigator.pop(ctx, _availableFertilizers[i])))),
    ));
    if (sel != null) {
      if (!mounted) return;
      final amt = await showDialog<double>(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: Text(sel.name, style: const TextStyle(color: DT.textPrimary)),
        content: TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: _t['fertilizer_amount_label']), autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v))),
      ));
      if (amt != null && amt > 0) setState(() => _selectedFertilizers[sel.id!] = amt);
    }
  }

  Widget _buildPhaseSelector() {
    final phases = PlantPhase.values.where((p) => p != PlantPhase.archived).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t['section_new_phase'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: phases.map((p) {
            final sel = _selectedNewPhase == p;
            return GestureDetector(
              onTap: () => setState(() => _selectedNewPhase = p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? DT.accent : DT.elevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? DT.accent : DT.border),
                ),
                child: Text(
                  p.displayName,
                  style: TextStyle(
                    color: sel ? DT.onAccent : DT.textSecondary,
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRunoffSection() {
    return PlantryCard(
      isFlat: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t['runoff_measured_label'], style: const TextStyle(color: DT.textPrimary, fontSize: 13)),
              Switch(
                value: _runoffEnabled,
                onChanged: (v) => setState(() {
                  _runoffEnabled = v;
                  if (!v) {
                    _phOutController.clear();
                    _ecOutController.clear();
                  }
                }),
                activeThumbColor: DT.accent,
              ),
            ],
          ),
          if (_runoffEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: PlantryFormField(controller: _phOutController, label: _t['label_ph_out'], keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: PlantryFormField(controller: _ecOutController, label: _t['label_ec_out'], keyboardType: TextInputType.number)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanseRow() {
    return PlantryCard(
      isFlat: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_t['cleanse_label'], style: const TextStyle(color: DT.textPrimary, fontSize: 13)),
          Switch(
            value: _cleanse,
            onChanged: (v) => setState(() => _cleanse = v),
            activeThumbColor: DT.accent,
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12, top: 8), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAction == ActionType.phaseChange && _selectedNewPhase == null) {
      AppMessages.showError(context, _t['error_phase_required']);
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Delete photos marked for removal
      for (final pid in _photosToDelete) {
        await _photoRepo.deletePhoto(pid);
      }

      // Copy new photos to documents dir
      final photoPaths = <String>[];
      final dir = await getApplicationDocumentsDirectory();
      for (final p in _newPhotos) {
        final f = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(p.path)}';
        final saved = await File(p.path).copy(path.join(dir.path, 'photos', f));
        photoPaths.add(saved.path);
      }

      // Pre-delete fertilizers — saveSingleLog only deletes+reinserts when non-empty,
      // so we handle the "user removed all fertilizers" case explicitly here.
      await _logFertilizerRepo.deleteByLog(widget.log.id!);

      final updatedLog = widget.log.copyWith(
        actionType: _selectedAction,
        logDate: _selectedDate,
        waterAmount: double.tryParse(_waterAmountController.text),
        phIn: double.tryParse(_phInController.text),
        ecIn: double.tryParse(_ecInController.text),
        phOut: _runoffEnabled ? double.tryParse(_phOutController.text) : null,
        ecOut: _runoffEnabled ? double.tryParse(_ecOutController.text) : null,
        runoff: _runoffEnabled,
        cleanse: _cleanse,
        containerSize: _selectedAction == ActionType.transplant ? double.tryParse(_containerSizeController.text) : null,
        systemReservoirSize: _selectedAction == ActionType.transplant ? double.tryParse(_systemReservoirSizeController.text) : null,
        temperature: double.tryParse(_temperatureController.text),
        humidity: double.tryParse(_humidityController.text),
        note: _noteController.text,
      );

      // Route through LogService — handles log update, fertilizers, photos,
      // and plant phase/transplant updates atomically.
      await _logService.saveSingleLog(
        plant: widget.plant,
        log: updatedLog,
        fertilizers: _selectedFertilizers,
        photoPaths: photoPaths,
        newPhase: _selectedNewPhase,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppMessages.showError(context, _t['error_saving_log']);
      setState(() => _isLoading = false);
    }
  }
}
