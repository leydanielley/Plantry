// =============================================
// GROWLOG - Add Harvest Screen
// =============================================

import 'package:flutter/material.dart';
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
import 'package:growlog_app/screens/harvest_detail_screen.dart';
import 'package:growlog_app/di/service_locator.dart';

class AddHarvestScreen extends StatefulWidget {
  final Plant plant;
  const AddHarvestScreen({super.key, required this.plant});

  @override
  State<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends State<AddHarvestScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final _formKey = GlobalKey<FormState>();

  final _wetWeightController = TextEditingController();
  final _dryingMethodController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dryingMethodController.text.isEmpty) _dryingMethodController.text = 'Hängend';
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
      title: 'Ernte erfassen',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPlantCard(),
                  const SizedBox(height: 24),
                  _section('Ernte-Daten'),
                  PlantryFormField(controller: _wetWeightController, label: 'Nassgewicht (g)', keyboardType: TextInputType.number, prefixIcon: const Icon(Icons.scale, color: DT.accent, size: 20)),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _dryingMethodController, label: 'Trocknungs-Methode', hint: 'z.B. Hängend, Netz'),
                  const SizedBox(height: 24),
                  _section('Zusätzliches'),
                  PlantryFormField(controller: _notesController, label: 'Notizen', maxLines: 3),
                  const SizedBox(height: 32),
                  PlantryButton(label: 'Ernte speichern', onPressed: _save, fullWidth: true),
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
            decoration: BoxDecoration(color: DT.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.grass, color: DT.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.plant.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DT.textPrimary)),
                Text(widget.plant.strain ?? 'Unbekannter Strain', style: const TextStyle(fontSize: 13, color: DT.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final h = Harvest(
        plantId: widget.plant.id!,
        harvestDate: DateTime.now(),
        wetWeight: double.tryParse(_wetWeightController.text),
        dryingStartDate: DateTime.now(),
        dryingMethod: _dryingMethodController.text,
        overallNotes: _notesController.text,
      );
      final id = await _harvestRepo.createHarvest(h);
      await getIt<IPlantRepository>().update(widget.plant.copyWith(phase: PlantPhase.harvest, phaseStartDate: DateTime.now()));
      
      if (mounted) {
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
