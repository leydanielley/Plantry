// =============================================
// GROWLOG - Nutrient Dilution Calculator (Expert Mode)
// =============================================

import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../utils/unit_converter.dart';

class NutrientDilutionCalculatorScreen extends StatefulWidget {
  const NutrientDilutionCalculatorScreen({super.key});

  @override
  State<NutrientDilutionCalculatorScreen> createState() =>
      _NutrientDilutionCalculatorScreenState();
}

class _NutrientDilutionCalculatorScreenState
    extends State<NutrientDilutionCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final SettingsRepository _settingsRepo = SettingsRepository();

  final _currentVolumeController = TextEditingController();
  final _currentStrengthController = TextEditingController();
  final _targetStrengthController = TextEditingController();

  AppSettings? _settings;
  bool _isLoading = true;

  // Results
  double? _finalVolume;
  double? _waterToAdd;

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
    _currentVolumeController.dispose();
    _currentStrengthController.dispose();
    _targetStrengthController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    final currentVolume = double.parse(_currentVolumeController.text);
    final currentStrength = double.parse(_currentStrengthController.text);
    final targetStrength = double.parse(_targetStrengthController.text);

    // Convert PPM to EC if needed for calculation
    final currentEC = _settings!.nutrientUnit == NutrientUnit.ppm
        ? UnitConverter.ppmToEc(currentStrength, _settings!.ppmScale)
        : currentStrength;
    final targetEC = _settings!.nutrientUnit == NutrientUnit.ppm
        ? UnitConverter.ppmToEc(targetStrength, _settings!.ppmScale)
        : targetStrength;

    // Formula: C1 × V1 = C2 × V2
    // V2 = (C1 × V1) / C2
    final finalVol = (currentEC * currentVolume) / targetEC;
    final waterAdd = finalVol - currentVolume;

    setState(() {
      _finalVolume = finalVol;
      _waterToAdd = waterAdd;
    });
  }

  void _reset() {
    _currentVolumeController.clear();
    _currentStrengthController.clear();
    _targetStrengthController.clear();
    setState(() {
      _finalVolume = null;
      _waterToAdd = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nutrient Dilution Calculator'),
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final nutrientUnit = _settings!.nutrientUnit;
    final ppmScale = _settings!.ppmScale;
    final volumeUnit = _settings!.volumeUnit;

    final strengthLabel = nutrientUnit == NutrientUnit.ec
        ? 'EC'
        : 'PPM (${ppmScale.scaleLabel})';
    final volumeLabel = UnitConverter.getVolumeUnitSuffix(volumeUnit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrient Dilution Calculator'),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Dilution Calculator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calculate how much water to add to dilute your nutrient solution. '
                        'Formula: C₁ × V₁ = C₂ × V₂',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Current Volume
              TextFormField(
                controller: _currentVolumeController,
                decoration: InputDecoration(
                  labelText: 'Current Volume ($volumeLabel)',
                  hintText: '50',
                  prefixIcon: const Icon(Icons.water_drop, color: Colors.blue),
                  border: const OutlineInputBorder(),
                  suffixText: volumeLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Must be > 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Current Strength
              TextFormField(
                controller: _currentStrengthController,
                decoration: InputDecoration(
                  labelText: 'Current $strengthLabel',
                  hintText: nutrientUnit == NutrientUnit.ec ? '2.4' : '1600',
                  prefixIcon: Icon(Icons.science, color: Colors.orange[700]),
                  border: const OutlineInputBorder(),
                  suffixText: strengthLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Must be > 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Target Strength
              TextFormField(
                controller: _targetStrengthController,
                decoration: InputDecoration(
                  labelText: 'Target $strengthLabel',
                  hintText: nutrientUnit == NutrientUnit.ec ? '1.8' : '1200',
                  prefixIcon: Icon(Icons.flag, color: Colors.green[700]),
                  border: const OutlineInputBorder(),
                  suffixText: strengthLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  final number = double.tryParse(value);
                  if (number == null || number <= 0) {
                    return 'Must be > 0';
                  }
                  // Target should be less than current for dilution
                  final current = double.tryParse(_currentStrengthController.text);
                  if (current != null && number >= current) {
                    return 'Target must be < current for dilution';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Calculate Button
              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('Calculate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // Results
              if (_waterToAdd != null && _finalVolume != null) ...[
                const SizedBox(height: 32),
                const Divider(thickness: 2),
                const SizedBox(height: 16),

                // Results Card
                Card(
                  color: Colors.green[50],
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 48,
                          color: Colors.green[700],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Results',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Water to Add
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300, width: 2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Add Water',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _waterToAdd!.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    volumeLabel,
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Final Volume
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildResultItem(
                              'Final Volume',
                              '${_finalVolume!.toStringAsFixed(1)} $volumeLabel',
                              Icons.water,
                              Colors.blue,
                            ),
                            _buildResultItem(
                              'Dilution Factor',
                              '${(_finalVolume! / double.parse(_currentVolumeController.text)).toStringAsFixed(2)}x',
                              Icons.expand,
                              Colors.purple,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Actions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickActionChip(
                              'Halve Strength',
                              () => _quickAction(0.5),
                            ),
                            _buildQuickActionChip(
                              '75% Strength',
                              () => _quickAction(0.75),
                            ),
                            _buildQuickActionChip(
                              '66% Strength',
                              () => _quickAction(0.66),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip(String label, VoidCallback onPressed) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: Colors.blue[50],
      labelStyle: TextStyle(color: Colors.blue[900]),
    );
  }

  void _quickAction(double factor) {
    final current = double.tryParse(_currentStrengthController.text);
    if (current == null) return;

    final target = current * factor;
    _targetStrengthController.text = target.toStringAsFixed(1);
    _calculate();
  }
}
