// =============================================
// GROWLOG - Edit Fertilizer Screen - FIXED BUG #12
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/fertilizer.dart';
import '../repositories/fertilizer_repository.dart';
import '../utils/validators.dart';

class EditFertilizerScreen extends StatefulWidget {
  final Fertilizer fertilizer;

  const EditFertilizerScreen({super.key, required this.fertilizer});

  @override
  State<EditFertilizerScreen> createState() => _EditFertilizerScreenState();
}

class _EditFertilizerScreenState extends State<EditFertilizerScreen> {
  final _formKey = GlobalKey<FormState>();
  final FertilizerRepository _fertilizerRepo = FertilizerRepository();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _npkController;
  late TextEditingController _typeController;
  late TextEditingController _descriptionController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fertilizer.name);
    _brandController = TextEditingController(text: widget.fertilizer.brand ?? '');
    _npkController = TextEditingController(text: widget.fertilizer.npk ?? '');
    _typeController = TextEditingController(text: widget.fertilizer.type ?? '');
    _descriptionController = TextEditingController(
      text: widget.fertilizer.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _npkController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveFertilizer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedFertilizer = widget.fertilizer.copyWith(
        name: _nameController.text,
        brand: _brandController.text.isNotEmpty ? _brandController.text : null,
        npk: _npkController.text.isNotEmpty ? _npkController.text : null,
        type: _typeController.text.isNotEmpty ? _typeController.text : null,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
      );

      await _fertilizerRepo.save(updatedFertilizer);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.updatedSuccessfully(context, 'Dünger');
      }
    } catch (e) {
      AppLogger.error('EditFertilizerScreen', 'Error saving: $e');
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dünger bearbeiten'),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBasicInfo(),
                  const SizedBox(height: 24),
                  _buildDetailsInfo(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grundinformationen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name *',
            prefixIcon: Icon(Icons.science),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Bitte Namen eingeben';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _brandController,
          decoration: const InputDecoration(
            labelText: 'Hersteller',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        // ✅ BUG #12 FIX: NPK Validator hinzugefügt!
        TextFormField(
          controller: _npkController,
          decoration: const InputDecoration(
            labelText: 'NPK Verhältnis',
            hintText: 'z.B. 2-2-4 oder 10-10-10',
            prefixIcon: Icon(Icons.analytics),
            border: OutlineInputBorder(),
            helperText: 'Format: N-P-K (z.B. 4-2-3 oder 10.5-5.2-8.1)',
          ),
          validator: (value) => Validators.validateNpk(value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _typeController,
          decoration: const InputDecoration(
            labelText: 'Typ',
            hintText: 'z.B. BLOOM, VEGA, ROOT, ADDITIVE',
            prefixIcon: Icon(Icons.category),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Beschreibung',
            hintText: 'Zusätzliche Infos, Dosierung, etc...',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveFertilizer,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: const Text('Änderungen speichern'),
    );
  }
}
