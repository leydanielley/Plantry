// =============================================
// GROWLOG - Add Harvest Screen (Multi-Step) - FIXED BUG #9
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_repository.dart';
import 'package:growlog_app/utils/validators.dart';
import 'package:growlog_app/utils/app_messages.dart';
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

  int _currentStep = 0;

  // Step 1: Basic Harvest Data
  final DateTime _harvestDate = DateTime.now();
  final TextEditingController _wetWeightController = TextEditingController();

  // Step 2: Drying Data
  final DateTime _dryingStartDate = DateTime.now();
  final TextEditingController _dryingMethodController = TextEditingController(
    text: 'Hängend',
  );
  final TextEditingController _dryingTempController = TextEditingController();
  final TextEditingController _dryingHumidityController =
      TextEditingController();

  // Step 3: Optional
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _wetWeightController.dispose();
    _dryingMethodController.dispose();
    _dryingTempController.dispose();
    _dryingHumidityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveHarvest() async {
    if (!_formKey.currentState!.validate()) return;

    AppLogger.info('AddHarvestScreen', '🟢 Starting to save harvest...');

    try {
      // ✅ CRITICAL FIX: Use tryParse to prevent crash on invalid input
      final harvest = Harvest(
        plantId: widget.plant.id!,
        harvestDate: _harvestDate,
        wetWeight: _wetWeightController.text.isNotEmpty
            ? double.tryParse(_wetWeightController.text)
            : null,
        dryingStartDate: _dryingStartDate,
        dryingMethod: _dryingMethodController.text.isNotEmpty
            ? _dryingMethodController.text
            : null,
        dryingTemperature: _dryingTempController.text.isNotEmpty
            ? double.tryParse(_dryingTempController.text)
            : null,
        dryingHumidity: _dryingHumidityController.text.isNotEmpty
            ? double.tryParse(_dryingHumidityController.text)
            : null,
        overallNotes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
      );

      final harvestId = await _harvestRepo.createHarvest(harvest);

      final plantRepo = getIt<IPlantRepository>();
      final updatedPlant = widget.plant.copyWith(
        phase: PlantPhase.harvest,
        phaseStartDate: DateTime.now(),
      );
      await plantRepo.update(updatedPlant);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HarvestDetailScreen(harvestId: harvestId),
          ),
          (route) => route.isFirst,
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            AppMessages.harvestCreated(context);
          }
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error('AddHarvestScreen', '❌ Error: $e');
      AppLogger.error('AddHarvestScreen', '❌ StackTrace: $stackTrace');
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ernte erfassen'),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() => _currentStep++);
            } else {
              _saveHarvest();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.of(context).pop();
            }
          },
          controlsBuilder: (context, details) {
            return Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_currentStep == 2 ? 'Speichern' : 'Weiter'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_currentStep == 0 ? 'Abbrechen' : 'Zurück'),
                ),
              ],
            );
          },
          steps: [
            Step(
              title: const Text('Ernte-Daten'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green[200] ?? Colors.green,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.grass, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plant.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                widget.plant.strain ?? 'Unknown Strain',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[300] ?? Colors.grey,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ernte-Datum',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd.MM.yyyy').format(_harvestDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Heute',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ BUG #9 FIX: Validierung hinzugefügt!
                  TextFormField(
                    controller: _wetWeightController,
                    decoration: InputDecoration(
                      labelText: 'Nassgewicht (optional)',
                      hintText: 'z.B. 500',
                      suffixText: 'g',
                      prefixIcon: Icon(Icons.scale, color: Colors.green[700]),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => Validators.validatePositiveNumber(
                      value,
                      min: 1.0,
                      max: 10000.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Das Gewicht direkt nach der Ernte',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            Step(
              title: const Text('Trocknung'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey[300] ?? Colors.grey,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trocknungs-Start',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat(
                                  'dd.MM.yyyy',
                                ).format(_dryingStartDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Heute',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _dryingMethodController,
                    decoration: InputDecoration(
                      labelText: 'Trocknungs-Methode',
                      hintText: 'z.B. Hängend, Netz, Box',
                      prefixIcon: Icon(
                        Icons.dry_cleaning,
                        color: Colors.orange[700],
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✅ BUG #9 FIX: Validierung hinzugefügt!
                  TextFormField(
                    controller: _dryingTempController,
                    decoration: InputDecoration(
                      labelText: 'Temperatur (optional)',
                      hintText: 'z.B. 18',
                      suffixText: '°C',
                      prefixIcon: Icon(
                        Icons.thermostat,
                        color: Colors.orange[700],
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => Validators.validateTemperature(value),
                  ),
                  const SizedBox(height: 12),

                  // ✅ BUG #9 FIX: Validierung hinzugefügt!
                  TextFormField(
                    controller: _dryingHumidityController,
                    decoration: InputDecoration(
                      labelText: 'Luftfeuchtigkeit (optional)',
                      hintText: 'z.B. 55',
                      suffixText: '%',
                      prefixIcon: Icon(
                        Icons.water_drop,
                        color: Colors.orange[700],
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => Validators.validateHumidity(value),
                  ),
                ],
              ),
            ),

            Step(
              title: const Text('Notizen'),
              isActive: _currentStep >= 2,
              state: StepState.indexed,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notizen (optional)',
                      hintText: 'Zusätzliche Informationen...',
                      prefixIcon: Icon(Icons.note, color: Colors.blue[700]),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Du kannst die Ernte später mit Trockengewicht, Curing-Daten und Bewertungen ergänzen.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
