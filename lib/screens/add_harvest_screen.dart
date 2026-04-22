// =============================================
// GROWLOG - Add Harvest Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/screens/harvest_detail_screen.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/di/service_locator.dart';

class AddHarvestScreen extends StatefulWidget {
  final Plant plant;
  const AddHarvestScreen({super.key, required this.plant});

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final _formKey = GlobalKey<FormState>();

  final _wetWeightController = TextEditingController();
  final _dryingMethodController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _harvestDate = DateTime.now();
  bool _isLoading = false;
  late AppTranslations _t = AppTranslations('de');

  @override
  void initState() {
    super.initState();
    _initTranslations();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
        if (_dryingMethodController.text.isEmpty) {
          _dryingMethodController.text = _t['drying_method_hanging'];
        }
      });
    }
  }

  @override
  void dispose() {
    _wetWeightController.dispose();
    _dryingMethodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['harvest'],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPlantCard(),
                  const SizedBox(height: 24),
                  _section(_t['edit_harvest_tab_basic']),
                  // Harvest Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _harvestDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setState(() => _harvestDate = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: _t['harvest_date_label'],
                        prefixIcon: const Icon(
                          Icons.calendar_today,
                          color: DT.accent,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        DateFormat('dd.MM.yyyy').format(_harvestDate),
                        style: const TextStyle(
                          fontSize: 16,
                          color: DT.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  PlantryFormField(
                    controller: _wetWeightController,
                    label: _t['edit_harvest_wet_weight_label'],
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(
                      Icons.scale,
                      color: DT.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PlantryFormField(
                    controller: _dryingMethodController,
                    label: _t['edit_harvest_drying_method_label'],
                    hint: _t['edit_harvest_drying_method_hint'],
                  ),
                  const SizedBox(height: 24),
                  _section(_t['notes']),
                  PlantryFormField(
                    controller: _notesController,
                    label: _t['notes'],
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  PlantryButton(
                    label: _t['save'],
                    onPressed: _save,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildPlantCard() {
    return PlantryCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: DT.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.grass, color: DT.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plant.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DT.textPrimary,
                  ),
                ),
                Text(
                  widget.plant.strain ?? _t['unknown_strain'],
                  style: const TextStyle(fontSize: 13, color: DT.textSecondary),
                ),
              ],
            ),
          ),
        ],
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final h = Harvest(
        plantId: widget.plant.id!,
        harvestDate: _harvestDate,
        wetWeight: double.tryParse(_wetWeightController.text),
        dryingStartDate: _harvestDate,
        dryingMethod: _dryingMethodController.text,
        overallNotes: _notesController.text,
      );
      final id = await _harvestRepo.createHarvest(h);
      await getIt<IPlantRepository>().update(
        widget.plant.copyWith(
          phase: PlantPhase.harvest,
          phaseStartDate: _harvestDate,
        ),
      );

      if (mounted) {
        AppMessages.showSuccess(context, _t['harvest_created_msg']);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HarvestDetailScreen(harvestId: id)),
          (r) => r.isFirst,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
