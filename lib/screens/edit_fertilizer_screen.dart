// =============================================
// GROWLOG - Edit Fertilizer Screen - FIXED BUG #12
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/fertilizer.dart';
import '../models/app_settings.dart';
import '../repositories/interfaces/i_fertilizer_repository.dart';
import '../repositories/interfaces/i_settings_repository.dart';
import '../utils/validators.dart';
import '../di/service_locator.dart';

class EditFertilizerScreen extends StatefulWidget {
  final Fertilizer fertilizer;

  const EditFertilizerScreen({super.key, required this.fertilizer});

  @override
  State<EditFertilizerScreen> createState() => _EditFertilizerScreenState();
}

class _EditFertilizerScreenState extends State<EditFertilizerScreen> {
  final _formKey = GlobalKey<FormState>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _npkController;
  late TextEditingController _typeController;
  late TextEditingController _descriptionController;
  late TextEditingController _ecValueController;
  late TextEditingController _ppmValueController;

  bool _isLoading = true;
  AppSettings? _settings;

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
    _ecValueController = TextEditingController(
      text: widget.fertilizer.ecValue != null ? widget.fertilizer.ecValue.toString() : '',
    );
    _ppmValueController = TextEditingController(
      text: widget.fertilizer.ppmValue != null ? widget.fertilizer.ppmValue.toString() : '',
    );
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

      final updatedFertilizer = widget.fertilizer.copyWith(
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
      child: const Text('Änderungen speichern'),
    );
  }
}
