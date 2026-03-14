// =============================================
// GROWLOG - Add Hardware Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/hardware.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_hardware_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class AddHardwareScreen extends StatefulWidget {
  final int roomId;
  const AddHardwareScreen({super.key, required this.roomId});

  @override
  State<AddHardwareScreen> createState() => _AddHardwareScreenState();
}

class _AddHardwareScreenState extends State<AddHardwareScreen> {
  final _formKey = GlobalKey<FormState>();
  final IHardwareRepository _hardwareRepo = getIt<IHardwareRepository>();
  
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _wattageController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  
  HardwareType _selectedType = HardwareType.ledPanel;
  bool _isLoading = false;

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _wattageController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: 'Hardware hinzufügen',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section('Typ'),
                  _typeSelector(),
                  const SizedBox(height: 24),

                  _section('Basis Info'),
                  PlantryFormField(controller: _brandController, label: 'Marke', hint: 'z.B. AC Infinity'),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _modelController, label: 'Modell', hint: 'z.B. T6'),
                  const SizedBox(height: 24),

                  _section('Technische Daten'),
                  Row(children: [
                    Expanded(child: PlantryFormField(controller: _wattageController, label: 'Leistung (Watt)', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(controller: _quantityController, label: 'Anzahl', keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 32),

                  PlantryButton(label: 'Hinzufügen', onPressed: _save, fullWidth: true),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));

  Widget _typeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(DT.radiusInput)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HardwareType>(
          value: _selectedType, isExpanded: true, dropdownColor: DT.elevated,
          items: HardwareType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.displayName, style: const TextStyle(color: DT.textPrimary)))).toList(),
          onChanged: (v) => setState(() => _selectedType = v!),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final h = Hardware(
        roomId: widget.roomId,
        name: '${_brandController.text} ${_modelController.text}'.trim().isNotEmpty ? '${_brandController.text} ${_modelController.text}'.trim() : _selectedType.displayName,
        type: _selectedType,
        brand: _brandController.text,
        model: _modelController.text,
        wattage: int.tryParse(_wattageController.text),
        quantity: int.tryParse(_quantityController.text) ?? 1,
      );
      await _hardwareRepo.save(h);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
