// =============================================
// GROWLOG - Edit Hardware Screen
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

class EditHardwareScreen extends StatefulWidget {
  final Hardware hardware;
  const EditHardwareScreen({super.key, required this.hardware});

  @override
  State<EditHardwareScreen> createState() => _EditHardwareScreenState();
}

class _EditHardwareScreenState extends State<EditHardwareScreen> {
  final _formKey = GlobalKey<FormState>();
  final IHardwareRepository _hardwareRepo = getIt<IHardwareRepository>();
  
  late TextEditingController _brandController;
  late TextEditingController _modelController;
  late TextEditingController _wattageController;
  late TextEditingController _qtyController;
  late HardwareType _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(text: widget.hardware.brand ?? '');
    _modelController = TextEditingController(text: widget.hardware.model ?? '');
    _wattageController = TextEditingController(text: widget.hardware.wattage?.toString() ?? '');
    _qtyController = TextEditingController(text: widget.hardware.quantity.toString());
    _selectedType = widget.hardware.type;
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _wattageController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: 'Hardware bearbeiten',
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
                  PlantryFormField(controller: _brandController, label: 'Marke'),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _modelController, label: 'Modell'),
                  const SizedBox(height: 24),

                  _section('Technische Daten'),
                  Row(children: [
                    Expanded(child: PlantryFormField(controller: _wattageController, label: 'Watt', keyboardType: TextInputType.number)),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(controller: _qtyController, label: 'Anzahl', keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 32),

                  PlantryButton(label: 'Speichern', onPressed: _save, fullWidth: true),
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
      final h = widget.hardware.copyWith(
        brand: _brandController.text, model: _modelController.text,
        type: _selectedType, wattage: int.tryParse(_wattageController.text),
        quantity: int.tryParse(_qtyController.text) ?? 1,
        name: '${_brandController.text} ${_modelController.text}'.trim().isNotEmpty ? '${_brandController.text} ${_modelController.text}'.trim() : _selectedType.displayName,
      );
      await _hardwareRepo.save(h);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
