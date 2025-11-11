// =============================================
// GROWLOG - RDWC System Create/Edit Form
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/repositories/interfaces/i_rdwc_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_room_repository.dart';
import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/unit_converter.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';

class RdwcSystemFormScreen extends StatefulWidget {
  final RdwcSystem? system; // null = create, not null = edit

  const RdwcSystemFormScreen({super.key, this.system});

  @override
  State<RdwcSystemFormScreen> createState() => _RdwcSystemFormScreenState();
}

class _RdwcSystemFormScreenState extends State<RdwcSystemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final IRdwcRepository _rdwcRepo = getIt<IRdwcRepository>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  late TextEditingController _nameController;
  late TextEditingController _maxCapacityController;
  late TextEditingController _currentLevelController;
  late TextEditingController _bucketCountController;
  late TextEditingController _descriptionController;
  // Hardware fields - Water Pump
  late TextEditingController _pumpBrandController;
  late TextEditingController _pumpModelController;
  late TextEditingController _pumpWattageController;
  late TextEditingController _pumpFlowRateController;
  // Hardware fields - Air Pump
  late TextEditingController _airPumpBrandController;
  late TextEditingController _airPumpModelController;
  late TextEditingController _airPumpWattageController;
  late TextEditingController _airPumpFlowRateController;
  // Hardware fields - Chiller
  late TextEditingController _chillerBrandController;
  late TextEditingController _chillerModelController;
  late TextEditingController _chillerWattageController;
  late TextEditingController _chillerCoolingPowerController;
  late TextEditingController _accessoriesController;

  List<Room> _rooms = [];
  int? _selectedRoomId;
  bool _isLoading = true;
  bool _isSaving = false;
  late AppTranslations _t;
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _maxCapacityController = TextEditingController();
    _currentLevelController = TextEditingController();
    _bucketCountController = TextEditingController();
    _descriptionController = TextEditingController();
    _pumpBrandController = TextEditingController();
    _pumpModelController = TextEditingController();
    _pumpWattageController = TextEditingController();
    _pumpFlowRateController = TextEditingController();
    _airPumpBrandController = TextEditingController();
    _airPumpModelController = TextEditingController();
    _airPumpWattageController = TextEditingController();
    _airPumpFlowRateController = TextEditingController();
    _chillerBrandController = TextEditingController();
    _chillerModelController = TextEditingController();
    _chillerWattageController = TextEditingController();
    _chillerCoolingPowerController = TextEditingController();
    _accessoriesController = TextEditingController();
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = await _settingsRepo.getSettings();
    final rooms = await _roomRepo.findAll();

    if (mounted) {
      setState(() {
        _settings = settings;
        _t = AppTranslations(settings.language);
        _rooms = rooms;
        _isLoading = false;
      });

      // Pre-fill if editing
      if (widget.system != null) {
        _nameController.text = widget.system!.name;
        _maxCapacityController.text = widget.system!.maxCapacity.toStringAsFixed(1);
        _currentLevelController.text = widget.system!.currentLevel.toStringAsFixed(1);
        _bucketCountController.text = widget.system!.bucketCount.toString();
        _descriptionController.text = widget.system!.description ?? '';
        _pumpBrandController.text = widget.system!.pumpBrand ?? '';
        _pumpModelController.text = widget.system!.pumpModel ?? '';
        _pumpWattageController.text = widget.system!.pumpWattage?.toString() ?? '';
        _pumpFlowRateController.text = widget.system!.pumpFlowRate?.toString() ?? '';
        _airPumpBrandController.text = widget.system!.airPumpBrand ?? '';
        _airPumpModelController.text = widget.system!.airPumpModel ?? '';
        _airPumpWattageController.text = widget.system!.airPumpWattage?.toString() ?? '';
        _airPumpFlowRateController.text = widget.system!.airPumpFlowRate?.toString() ?? '';
        _chillerBrandController.text = widget.system!.chillerBrand ?? '';
        _chillerModelController.text = widget.system!.chillerModel ?? '';
        _chillerWattageController.text = widget.system!.chillerWattage?.toString() ?? '';
        _chillerCoolingPowerController.text = widget.system!.chillerCoolingPower?.toString() ?? '';
        _accessoriesController.text = widget.system!.accessories ?? '';
        _selectedRoomId = widget.system!.roomId;
      } else {
        // Default values for new system
        _bucketCountController.text = '4';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxCapacityController.dispose();
    _currentLevelController.dispose();
    _bucketCountController.dispose();
    _descriptionController.dispose();
    _pumpBrandController.dispose();
    _pumpModelController.dispose();
    _pumpWattageController.dispose();
    _pumpFlowRateController.dispose();
    _airPumpBrandController.dispose();
    _airPumpModelController.dispose();
    _airPumpWattageController.dispose();
    _airPumpFlowRateController.dispose();
    _chillerBrandController.dispose();
    _chillerModelController.dispose();
    _chillerWattageController.dispose();
    _chillerCoolingPowerController.dispose();
    _accessoriesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      // ✅ CRITICAL FIX: Use tryParse to prevent crash on invalid input
      final maxCapacity = double.tryParse(_maxCapacityController.text) ?? 0.0;
      final currentLevel = double.tryParse(_currentLevelController.text) ?? 0.0;
      final bucketCount = int.tryParse(_bucketCountController.text) ?? 4;
      final description = _descriptionController.text.trim();
      final pumpBrand = _pumpBrandController.text.trim();
      final pumpModel = _pumpModelController.text.trim();
      final pumpWattage = _pumpWattageController.text.trim().isNotEmpty
          ? int.tryParse(_pumpWattageController.text.trim())
          : null;
      final pumpFlowRate = _pumpFlowRateController.text.trim().isNotEmpty
          ? double.tryParse(_pumpFlowRateController.text.trim())
          : null;
      final airPumpBrand = _airPumpBrandController.text.trim();
      final airPumpModel = _airPumpModelController.text.trim();
      final airPumpWattage = _airPumpWattageController.text.trim().isNotEmpty
          ? int.tryParse(_airPumpWattageController.text.trim())
          : null;
      final airPumpFlowRate = _airPumpFlowRateController.text.trim().isNotEmpty
          ? double.tryParse(_airPumpFlowRateController.text.trim())
          : null;
      final chillerBrand = _chillerBrandController.text.trim();
      final chillerModel = _chillerModelController.text.trim();
      final chillerWattage = _chillerWattageController.text.trim().isNotEmpty
          ? int.tryParse(_chillerWattageController.text.trim())
          : null;
      final chillerCoolingPower = _chillerCoolingPowerController.text.trim().isNotEmpty
          ? int.tryParse(_chillerCoolingPowerController.text.trim())
          : null;
      final accessories = _accessoriesController.text.trim();

      if (widget.system == null) {
        // Create new system
        final system = RdwcSystem(
          name: name,
          roomId: _selectedRoomId,
          maxCapacity: maxCapacity,
          currentLevel: currentLevel,
          bucketCount: bucketCount,
          description: description.isNotEmpty ? description : null,
          pumpBrand: pumpBrand.isNotEmpty ? pumpBrand : null,
          pumpModel: pumpModel.isNotEmpty ? pumpModel : null,
          pumpWattage: pumpWattage,
          pumpFlowRate: pumpFlowRate,
          airPumpBrand: airPumpBrand.isNotEmpty ? airPumpBrand : null,
          airPumpModel: airPumpModel.isNotEmpty ? airPumpModel : null,
          airPumpWattage: airPumpWattage,
          airPumpFlowRate: airPumpFlowRate,
          chillerBrand: chillerBrand.isNotEmpty ? chillerBrand : null,
          chillerModel: chillerModel.isNotEmpty ? chillerModel : null,
          chillerWattage: chillerWattage,
          chillerCoolingPower: chillerCoolingPower,
          accessories: accessories.isNotEmpty ? accessories : null,
        );
        await _rdwcRepo.createSystem(system);
      } else {
        // Update existing system
        final updated = widget.system!.copyWith(
          name: name,
          roomId: _selectedRoomId,
          maxCapacity: maxCapacity,
          currentLevel: currentLevel,
          bucketCount: bucketCount,
          description: description.isNotEmpty ? description : null,
          pumpBrand: pumpBrand.isNotEmpty ? pumpBrand : null,
          pumpModel: pumpModel.isNotEmpty ? pumpModel : null,
          pumpWattage: pumpWattage,
          pumpFlowRate: pumpFlowRate,
          airPumpBrand: airPumpBrand.isNotEmpty ? airPumpBrand : null,
          airPumpModel: airPumpModel.isNotEmpty ? airPumpModel : null,
          airPumpWattage: airPumpWattage,
          airPumpFlowRate: airPumpFlowRate,
          chillerBrand: chillerBrand.isNotEmpty ? chillerBrand : null,
          chillerModel: chillerModel.isNotEmpty ? chillerModel : null,
          chillerWattage: chillerWattage,
          chillerCoolingPower: chillerCoolingPower,
          accessories: accessories.isNotEmpty ? accessories : null,
        );
        await _rdwcRepo.updateSystem(updated);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.showSuccess(
          context,
          widget.system == null ? 'System created!' : 'System updated!',
        );
      }
    } catch (e) {
      AppLogger.error('RdwcSystemFormScreen', 'Error saving system', e);
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context, 'Error saving system: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.system == null ? _t['add_rdwc_system'] : _t['edit']),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _t['system_name'],
                hintText: 'Main Tent RDWC',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: _t['description'],
                hintText: '4 buckets + 40L reservoir',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Room Selection (optional)
            DropdownButtonFormField<int>(
              initialValue: _selectedRoomId,
              decoration: InputDecoration(
                labelText: '${_t['rooms']} (${_t['optional']})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.room),
              ),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Text('- ${_t['none']} -'),
                ),
                ..._rooms.map((room) => DropdownMenuItem<int>(
                  value: room.id,
                  child: Text(room.name),
                )),
              ],
              onChanged: (value) {
                setState(() => _selectedRoomId = value);
              },
            ),
            const SizedBox(height: 16),

            // Bucket Count
            TextFormField(
              controller: _bucketCountController,
              decoration: InputDecoration(
                labelText: _t['bucket_count'],
                hintText: '4',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.grid_4x4),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bucket count is required';
                }
                final number = int.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Max Capacity
            TextFormField(
              controller: _maxCapacityController,
              decoration: InputDecoration(
                labelText: _t['max_capacity'],
                hintText: '100',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.water),
                suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Max capacity is required';
                }
                final number = double.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Must be greater than 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Current Level
            TextFormField(
              controller: _currentLevelController,
              decoration: InputDecoration(
                labelText: _t['current_level'],
                hintText: '100',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.water_drop),
                suffixText: UnitConverter.getVolumeUnitSuffix(_settings.volumeUnit),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Current level is required';
                }
                final number = double.tryParse(value);
                if (number == null || number < 0) {
                  return 'Must be 0 or greater';
                }
                final maxCapacity = double.tryParse(_maxCapacityController.text);
                if (maxCapacity != null && number > maxCapacity) {
                  return 'Cannot exceed max capacity';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Hardware Specifications Section
            Text(
              'Hardware Specifications (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // Pump Brand
            TextFormField(
              controller: _pumpBrandController,
              decoration: InputDecoration(
                labelText: 'Pump Brand',
                hintText: 'Hailea, Eheim, Aqua One',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.settings_input_component, color: Colors.blue[700]),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Pump Model
            TextFormField(
              controller: _pumpModelController,
              decoration: InputDecoration(
                labelText: 'Pump Model',
                hintText: 'HX-6540',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.precision_manufacturing, color: Colors.blue[700]),
              ),
            ),
            const SizedBox(height: 16),

            // Pump Wattage & Flow Rate (Row)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pumpWattageController,
                    decoration: const InputDecoration(
                      labelText: 'Wattage (W)',
                      hintText: '35',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flash_on, color: Colors.orange),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _pumpFlowRateController,
                    decoration: const InputDecoration(
                      labelText: 'Flow Rate (L/h)',
                      hintText: '1200',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed, color: Colors.cyan),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = double.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Air Pump Section
            Text(
              'Air Pump (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // Air Pump Brand
            TextFormField(
              controller: _airPumpBrandController,
              decoration: InputDecoration(
                labelText: 'Air Pump Brand',
                hintText: 'Hailea, Aqua One',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.air, color: Colors.cyan[700]),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Air Pump Model
            TextFormField(
              controller: _airPumpModelController,
              decoration: InputDecoration(
                labelText: 'Air Pump Model',
                hintText: 'ACO-9602',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.precision_manufacturing, color: Colors.cyan[700]),
              ),
            ),
            const SizedBox(height: 16),

            // Air Pump Wattage & Flow Rate (Row)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _airPumpWattageController,
                    decoration: const InputDecoration(
                      labelText: 'Wattage (W)',
                      hintText: '15',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flash_on, color: Colors.orange),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _airPumpFlowRateController,
                    decoration: const InputDecoration(
                      labelText: 'Flow Rate (L/h)',
                      hintText: '600',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.speed, color: Colors.cyan),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = double.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chiller Section
            Text(
              'Chiller (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),

            // Chiller Brand
            TextFormField(
              controller: _chillerBrandController,
              decoration: InputDecoration(
                labelText: 'Chiller Brand',
                hintText: 'Hailea, Teco',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.ac_unit, color: Colors.lightBlue[700]),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Chiller Model
            TextFormField(
              controller: _chillerModelController,
              decoration: InputDecoration(
                labelText: 'Chiller Model',
                hintText: 'HC-300A',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.precision_manufacturing, color: Colors.lightBlue[700]),
              ),
            ),
            const SizedBox(height: 16),

            // Chiller Wattage & Cooling Power (Row)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chillerWattageController,
                    decoration: const InputDecoration(
                      labelText: 'Wattage (W)',
                      hintText: '210',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flash_on, color: Colors.orange),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _chillerCoolingPowerController,
                    decoration: const InputDecoration(
                      labelText: 'Cooling Power (W)',
                      hintText: '300',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.thermostat, color: Colors.lightBlue),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return 'Must be > 0';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Accessories
            Text(
              'Other Accessories (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accessoriesController,
              decoration: InputDecoration(
                labelText: 'Accessories',
                hintText: 'Filters, sensors, etc.',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.construction, color: Colors.green[700]),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : _t['save']),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
