// =============================================
// GROWLOG - Edit Fertilizer Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class EditFertilizerScreen extends StatefulWidget {
  final Fertilizer fertilizer;
  const EditFertilizerScreen({super.key, required this.fertilizer});

  @override
  State<EditFertilizerScreen> createState() => _EditFertilizerScreenState();
}

class _EditFertilizerScreenState extends State<EditFertilizerScreen> {
  final _formKey = GlobalKey<FormState>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  
  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _npkController;
  late TextEditingController _typeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fertilizer.name);
    _brandController = TextEditingController(text: widget.fertilizer.brand ?? '');
    _npkController = TextEditingController(text: widget.fertilizer.npk ?? '');
    _typeController = TextEditingController(text: widget.fertilizer.type ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _npkController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: 'Dünger bearbeiten',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: DT.accent))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PlantryFormField(controller: _nameController, label: 'Name', validator: (v) => v!.isEmpty ? 'Pflichtfeld' : null),
                  const SizedBox(height: 16),
                  PlantryFormField(controller: _brandController, label: 'Marke'),
                  const SizedBox(height: 24),

                  _section('Details'),
                  Row(children: [
                    Expanded(child: PlantryFormField(controller: _npkController, label: 'NPK')),
                    const SizedBox(width: 12),
                    Expanded(child: PlantryFormField(controller: _typeController, label: 'Typ')),
                  ]),
                  const SizedBox(height: 32),

                  PlantryButton(label: 'Änderungen speichern', onPressed: _save, fullWidth: true),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DT.textSecondary)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final f = widget.fertilizer.copyWith(name: _nameController.text, brand: _brandController.text, npk: _npkController.text, type: _typeController.text);
      await _fertilizerRepo.save(f);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}
