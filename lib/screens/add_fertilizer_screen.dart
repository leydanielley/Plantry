// =============================================
// GROWLOG - Add Fertilizer Screen
// =============================================

import 'package:flutter/material.dart';
import '../models/fertilizer.dart';
import '../repositories/fertilizer_repository.dart';
import '../utils/app_messages.dart';

class AddFertilizerScreen extends StatefulWidget {
  const AddFertilizerScreen({super.key});

  @override
  State<AddFertilizerScreen> createState() => _AddFertilizerScreenState();
}

class _AddFertilizerScreenState extends State<AddFertilizerScreen> {
  final _formKey = GlobalKey<FormState>();
  final FertilizerRepository _fertilizerRepo = FertilizerRepository();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _npkController = TextEditingController();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

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
      final fertilizer = Fertilizer(
        name: _nameController.text,
        brand: _brandController.text.isNotEmpty ? _brandController.text : null,
        npk: _npkController.text.isNotEmpty ? _npkController.text : null,
        type: _typeController.text.isNotEmpty ? _typeController.text : null,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
      );

      await _fertilizerRepo.save(fertilizer);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.savedSuccessfully(context, 'Dünger');
      }
    } catch (e) {
      // Error saving: $e
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
        title: const Text('Neuer Dünger'),
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
                  _buildInfoCard(),
                  const SizedBox(height: 24),
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

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Füge Dünger hinzu, um sie später in Logs zu verwenden.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
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
            hintText: 'z.B. Bloom A+B',
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
            hintText: 'z.B. Canna, BioBizz, Advanced Nutrients',
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
        TextFormField(
          controller: _npkController,
          decoration: const InputDecoration(
            labelText: 'NPK Verhältnis',
            hintText: 'z.B. 2-2-4 oder 5-4-3',
            prefixIcon: Icon(Icons.analytics),
            border: OutlineInputBorder(),
          ),
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
      child: const Text('Dünger speichern'),
    );
  }
}
