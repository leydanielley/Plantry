// =============================================
// GROWLOG - Add Fertilizer Screen
// =============================================

import 'package:flutter/material.dart';
import '../models/fertilizer.dart';
import '../models/app_settings.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../utils/app_messages.dart';
import '../di/service_locator.dart';

class AddFertilizerScreen extends StatefulWidget {
  const AddFertilizerScreen({super.key});

  @override
  State<AddFertilizerScreen> createState() => _AddFertilizerScreenState();
}

class _AddFertilizerScreenState extends State<AddFertilizerScreen> {
  final _formKey = GlobalKey<FormState>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _npkController = TextEditingController();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ecValueController = TextEditingController();
  final _ppmValueController = TextEditingController();

  bool _isLoading = true;
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _npkController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _ecValueController.dispose();
    _ppmValueController.dispose();
    super.dispose();
  }

  Future<void> _saveFertilizer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final ecValue = _ecValueController.text.isNotEmpty
          ? double.tryParse(_ecValueController.text)
          : null;
      final ppmValue = _ppmValueController.text.isNotEmpty
          ? double.tryParse(_ppmValueController.text)
          : null;

      final fertilizer = Fertilizer(
        name: _nameController.text,
        brand: _brandController.text.isNotEmpty ? _brandController.text : null,
        npk: _npkController.text.isNotEmpty ? _npkController.text : null,
        type: _typeController.text.isNotEmpty ? _typeController.text : null,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        ecValue: ecValue,
        ppmValue: ppmValue,
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
                  if (_settings?.isExpertMode ?? false) ...[
                    _buildExpertInfo(),
                    const SizedBox(height: 24),
                  ],
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

  Widget _buildExpertInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'RDWC Expert Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'EXPERT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[900],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200] ?? Colors.blue),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Diese Werte werden für EC/PPM-Berechnungen in RDWC-Logs verwendet.',
                  style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ecValueController,
          decoration: const InputDecoration(
            labelText: 'EC-Wert pro ml (optional)',
            hintText: 'z.B. 0.5',
            helperText: 'EC-Beitrag pro ml Dünger',
            prefixIcon: Icon(Icons.science),
            suffixText: 'mS/cm/ml',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final number = double.tryParse(value);
              if (number == null) {
                return 'Bitte gültige Zahl eingeben';
              }
              if (number < 0) {
                return 'Wert muss positiv sein';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ppmValueController,
          decoration: const InputDecoration(
            labelText: 'PPM-Wert pro ml (optional)',
            hintText: 'z.B. 250',
            helperText: 'PPM-Beitrag pro ml Dünger',
            prefixIcon: Icon(Icons.science),
            suffixText: 'PPM/ml',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final number = double.tryParse(value);
              if (number == null) {
                return 'Bitte gültige Zahl eingeben';
              }
              if (number < 0) {
                return 'Wert muss positiv sein';
              }
            }
            return null;
          },
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
