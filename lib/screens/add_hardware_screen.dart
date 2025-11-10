// =============================================
// GROWLOG - Add Hardware Screen
// ✅ AUDIT FIX: i18n extraction
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hardware.dart';
import '../models/room.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_hardware_repository.dart';
import '../repositories/interfaces/i_room_repository.dart';
import '../utils/app_messages.dart';
import '../utils/translations.dart'; // ✅ AUDIT FIX: i18n
import '../di/service_locator.dart';

class AddHardwareScreen extends StatefulWidget {
  final int roomId;

  const AddHardwareScreen({super.key, required this.roomId});

  @override
  State<AddHardwareScreen> createState() => _AddHardwareScreenState();
}

class _AddHardwareScreenState extends State<AddHardwareScreen> {
  final _formKey = GlobalKey<FormState>();
  final IHardwareRepository _hardwareRepo = getIt<IHardwareRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();
  late final AppTranslations _t; // ✅ AUDIT FIX: i18n

  Room? _room;

  // Basis-Controller
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  
  // Allgemeine Controller
  final _wattageController = TextEditingController();
  
  // Beleuchtung
  final _spectrumController = TextEditingController();
  final _colorTemperatureController = TextEditingController();
  
  // Lüftung
  final _airflowController = TextEditingController();
  final _flangeSizeController = TextEditingController();
  final _diameterController = TextEditingController();
  
  // Klimatechnik
  final _coolingPowerController = TextEditingController();
  final _heatingPowerController = TextEditingController();
  final _coverageController = TextEditingController();
  final _humidificationRateController = TextEditingController();
  
  // Bewässerung
  final _pumpRateController = TextEditingController();
  final _programCountController = TextEditingController();
  final _dripperCountController = TextEditingController();
  final _capacityController = TextEditingController();
  final _materialController = TextEditingController();
  
  // Filter & Controller
  final _filterDiameterController = TextEditingController();
  final _filterLengthController = TextEditingController();
  final _controllerTypeController = TextEditingController();
  final _outputCountController = TextEditingController();
  final _controllerFunctionsController = TextEditingController();
  
  // Optional
  final _specificationsController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _notesController = TextEditingController();

  late HardwareType _selectedType;
  DateTime? _purchaseDate;
  bool _isLoading = false;
  
  // Boolean Flags
  bool? _dimmable;
  bool? _controllable;
  bool? _oscillating;
  bool? _hasThermostat;
  bool? _isDigital;
  bool? _hasChiller;
  bool? _hasAirPump;

  @override
  void initState() {
    super.initState();
    _t = AppTranslations(Localizations.localeOf(context).languageCode); // ✅ AUDIT FIX: i18n
    _selectedType = HardwareType.ledPanel;
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    final room = await _roomRepo.findById(widget.roomId);
    if (mounted) {
      setState(() {
        _room = room;
      });
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _quantityController.dispose();
    _wattageController.dispose();
    _spectrumController.dispose();
    _colorTemperatureController.dispose();
    _airflowController.dispose();
    _flangeSizeController.dispose();
    _diameterController.dispose();
    _coolingPowerController.dispose();
    _heatingPowerController.dispose();
    _coverageController.dispose();
    _humidificationRateController.dispose();
    _pumpRateController.dispose();
    _programCountController.dispose();
    _dripperCountController.dispose();
    _capacityController.dispose();
    _materialController.dispose();
    _filterDiameterController.dispose();
    _filterLengthController.dispose();
    _controllerTypeController.dispose();
    _outputCountController.dispose();
    _controllerFunctionsController.dispose();
    _specificationsController.dispose();
    _purchasePriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _generateName() {
    final parts = <String>[];
    if (_brandController.text.trim().isNotEmpty) {
      parts.add(_brandController.text.trim());
    }
    if (_modelController.text.trim().isNotEmpty) {
      parts.add(_modelController.text.trim());
    }
    if (parts.isEmpty) {
      return _selectedType.displayName;
    }
    return parts.join(' ');
  }

  Future<void> _saveHardware() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hardware = Hardware(
        roomId: widget.roomId,
        name: _generateName(),
        type: _selectedType,
        brand: _brandController.text.trim().isNotEmpty ? _brandController.text.trim() : null,
        model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
        quantity: int.tryParse(_quantityController.text) ?? 1,
        wattage: _wattageController.text.isNotEmpty ? int.tryParse(_wattageController.text) : null,
        spectrum: _spectrumController.text.trim().isNotEmpty ? _spectrumController.text.trim() : null,
        colorTemperature: _colorTemperatureController.text.trim().isNotEmpty ? _colorTemperatureController.text.trim() : null,
        dimmable: _dimmable,
        airflow: _airflowController.text.isNotEmpty ? int.tryParse(_airflowController.text) : null,
        flangeSize: _flangeSizeController.text.trim().isNotEmpty ? _flangeSizeController.text.trim() : null,
        controllable: _controllable,
        oscillating: _oscillating,
        diameter: _diameterController.text.isNotEmpty ? int.tryParse(_diameterController.text) : null,
        coolingPower: _coolingPowerController.text.isNotEmpty ? int.tryParse(_coolingPowerController.text) : null,
        heatingPower: _heatingPowerController.text.isNotEmpty ? int.tryParse(_heatingPowerController.text) : null,
        coverage: _coverageController.text.isNotEmpty ? double.tryParse(_coverageController.text) : null,
        hasThermostat: _hasThermostat,
        humidificationRate: _humidificationRateController.text.isNotEmpty ? int.tryParse(_humidificationRateController.text) : null,
        pumpRate: _pumpRateController.text.isNotEmpty ? int.tryParse(_pumpRateController.text) : null,
        isDigital: _isDigital,
        programCount: _programCountController.text.isNotEmpty ? int.tryParse(_programCountController.text) : null,
        dripperCount: _dripperCountController.text.isNotEmpty ? int.tryParse(_dripperCountController.text) : null,
        capacity: _capacityController.text.isNotEmpty ? int.tryParse(_capacityController.text) : null,
        material: _materialController.text.trim().isNotEmpty ? _materialController.text.trim() : null,
        hasChiller: _hasChiller,
        hasAirPump: _hasAirPump,
        filterDiameter: _filterDiameterController.text.trim().isNotEmpty ? _filterDiameterController.text.trim() : null,
        filterLength: _filterLengthController.text.isNotEmpty ? int.tryParse(_filterLengthController.text) : null,
        controllerType: _controllerTypeController.text.trim().isNotEmpty ? _controllerTypeController.text.trim() : null,
        outputCount: _outputCountController.text.isNotEmpty ? int.tryParse(_outputCountController.text) : null,
        controllerFunctions: _controllerFunctionsController.text.trim().isNotEmpty ? _controllerFunctionsController.text.trim() : null,
        specifications: _specificationsController.text.trim().isNotEmpty ? _specificationsController.text.trim() : null,
        purchaseDate: _purchaseDate,
        purchasePrice: _purchasePriceController.text.isNotEmpty ? double.tryParse(_purchasePriceController.text) : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      await _hardwareRepo.save(hardware);

      if (mounted) {
        AppMessages.savedSuccessfully(context, hardware.name);
        
        _resetForm();
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

  void _resetForm() {
    _brandController.clear();
    _modelController.clear();
    _quantityController.text = '1';
    _wattageController.clear();
    _spectrumController.clear();
    _colorTemperatureController.clear();
    _airflowController.clear();
    _flangeSizeController.clear();
    _diameterController.clear();
    _coolingPowerController.clear();
    _heatingPowerController.clear();
    _coverageController.clear();
    _humidificationRateController.clear();
    _pumpRateController.clear();
    _programCountController.clear();
    _dripperCountController.clear();
    _capacityController.clear();
    _materialController.clear();
    _filterDiameterController.clear();
    _filterLengthController.clear();
    _controllerTypeController.clear();
    _outputCountController.clear();
    _controllerFunctionsController.clear();
    _specificationsController.clear();
    _purchasePriceController.clear();
    _notesController.clear();
    
    setState(() {
      _selectedType = HardwareType.ledPanel;
      _purchaseDate = null;
      _dimmable = null;
      _controllable = null;
      _oscillating = null;
      _hasThermostat = null;
      _isDigital = null;
      _hasChiller = null;
      _hasAirPump = null;
    });
    
    FocusScope.of(context).requestFocus(FocusNode());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t['add_hardware_title']), // ✅ i18n
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              _t['add_hardware_done'], // ✅ i18n
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTypeSelector(),
                  const SizedBox(height: 24),
                  _buildBasicInfoSection(),
                  const SizedBox(height: 24),
                  _buildTechnicalSection(),
                  const SizedBox(height: 24),
                  _buildPurchaseSection(),
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeSelector() {
    // Filter out entire watering category if room has RDWC system
    final hasRdwcSystem = _room?.rdwcSystemId != null;
    final availableTypes = hasRdwcSystem
        ? HardwareType.values.where((type) => type.category != HardwareCategory.watering).toList()
        : HardwareType.values.toList();

    final grouped = <HardwareCategory, List<HardwareType>>{};
    for (final type in availableTypes) {
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_hardware_type'], // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) {
          final category = entry.key;
          final types = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  category.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: types.map((type) {
                  final isSelected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedType = type);
                    },
                    selectedColor: Colors.orange[600],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_hardware_basic_info'], // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: _t['add_hardware_brand_label'], // ✅ i18n
                  hintText: _t['add_hardware_brand_hint'], // ✅ i18n
                  prefixIcon: Icon(Icons.business, color: Colors.orange[700]),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _t['add_hardware_brand_required']; // ✅ i18n
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: _t['add_hardware_model_label'], // ✅ i18n
                  hintText: _t['add_hardware_model_hint'], // ✅ i18n
                  prefixIcon: const Icon(Icons.info),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200] ?? Colors.orange),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t['add_hardware_name_info'], // ✅ i18n
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_hardware_technical_data'], // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        
        // Dynamische Felder je nach Typ
        ..._buildTypeSpecificFields(),
        
        // Anzahl (immer anzeigen)
        const SizedBox(height: 12),
        TextFormField(
          controller: _quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _t['add_hardware_quantity'], // ✅ i18n
            hintText: '1',
            prefixIcon: const Icon(Icons.numbers),
            border: const OutlineInputBorder(),
            suffixText: _t['add_hardware_quantity_unit'], // ✅ i18n
          ),
        ),

        // Spezifikationen
        const SizedBox(height: 12),
        TextFormField(
          controller: _specificationsController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: _t['add_hardware_specifications'], // ✅ i18n
            hintText: _t['add_hardware_specifications_hint'], // ✅ i18n
            prefixIcon: const Icon(Icons.description),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTypeSpecificFields() {
    switch (_selectedType) {
      // ========== BELEUCHTUNG ==========
      case HardwareType.ledPanel:
        return [
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage'], // ✅ i18n
              hintText: '150',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _spectrumController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_spectrum'], // ✅ i18n
              hintText: 'z.B. Full Spectrum, 3000K-6500K',
              prefixIcon: Icon(Icons.wb_sunny),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(_t['add_hardware_dimmable']), // ✅ i18n
            value: _dimmable ?? false,
            onChanged: (value) => setState(() => _dimmable = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ];
      
      case HardwareType.hpsLamp:
      case HardwareType.mhLamp:
      case HardwareType.cflLamp:
        return [
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage'], // ✅ i18n
              hintText: '600',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _colorTemperatureController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_color_temp'], // ✅ i18n
              hintText: 'z.B. 2100K',
              prefixIcon: Icon(Icons.wb_incandescent),
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      
      // ========== LÜFTUNG ==========
      case HardwareType.exhaustFan:
        return [
          TextFormField(
            controller: _airflowController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_airflow'], // ✅ i18n
              hintText: '420',
              prefixIcon: Icon(Icons.air, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'm³/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _flangeSizeController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_flange_size'], // ✅ i18n
              hintText: 'z.B. 150mm oder 6"',
              prefixIcon: Icon(Icons.settings),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(_t['add_hardware_controllable']), // ✅ i18n
            value: _controllable ?? false,
            onChanged: (value) => setState(() => _controllable = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage_optional'], // ✅ i18n
              hintText: _t['add_hardware_wattage_hint_optional'], // ✅ i18n
              prefixIcon: Icon(Icons.bolt),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
          ),
        ];
      
      case HardwareType.circulationFan:
        return [
          TextFormField(
            controller: _airflowController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_airflow'], // ✅ i18n
              hintText: '200',
              prefixIcon: Icon(Icons.air, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'm³/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage_optional'], // ✅ i18n
              hintText: '50',
              prefixIcon: Icon(Icons.bolt),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(_t['add_hardware_oscillating']), // ✅ i18n
            value: _oscillating ?? false,
            onChanged: (value) => setState(() => _oscillating = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _diameterController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_diameter'], // ✅ i18n
              hintText: '30',
              prefixIcon: Icon(Icons.circle_outlined),
              border: const OutlineInputBorder(),
              suffixText: 'cm',
            ),
          ),
        ];
      
      // ========== KLIMATECHNIK ==========
      case HardwareType.airConditioner:
        return [
          TextFormField(
            controller: _coolingPowerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_cooling_power'], // ✅ i18n
              hintText: '9000',
              prefixIcon: Icon(Icons.ac_unit, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'BTU',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage'], // ✅ i18n
              hintText: '1000',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
        ];
      
      case HardwareType.heater:
        return [
          TextFormField(
            controller: _heatingPowerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_heating_power'], // ✅ i18n
              hintText: '2000',
              prefixIcon: Icon(Icons.whatshot, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _coverageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _t['add_hardware_coverage'], // ✅ i18n
              hintText: '20',
              prefixIcon: Icon(Icons.crop_square),
              border: const OutlineInputBorder(),
              suffixText: 'm²',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(_t['add_hardware_thermostat']), // ✅ i18n
            value: _hasThermostat ?? false,
            onChanged: (value) => setState(() => _hasThermostat = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ];
      
      case HardwareType.dehumidifier:
        return [
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage'], // ✅ i18n
              hintText: '300',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
        ];
      
      case HardwareType.humidifier:
        return [
          TextFormField(
            controller: _humidificationRateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_humidification'], // ✅ i18n
              hintText: '300',
              prefixIcon: Icon(Icons.water_drop, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'ml/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage'], // ✅ i18n
              hintText: '30',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
        ];
      
      // ========== BEWÄSSERUNG ==========
      case HardwareType.pump:
        return [
          TextFormField(
            controller: _pumpRateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_pump_rate'], // ✅ i18n
              hintText: '1000',
              prefixIcon: Icon(Icons.water, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'L/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_wattage'], // ✅ i18n
              hintText: '50',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
        ];
      
      case HardwareType.timer:
        return [
          CheckboxListTile(
            title: Text(_t['add_hardware_digital']), // ✅ i18n
            subtitle: Text(_t['add_hardware_analog_subtitle']), // ✅ i18n
            value: _isDigital ?? false,
            onChanged: (value) => setState(() => _isDigital = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _programCountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_program_count'], // ✅ i18n
              hintText: '8',
              prefixIcon: Icon(Icons.event_repeat),
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      
      case HardwareType.dripSystem:
        return [
          TextFormField(
            controller: _dripperCountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_dripper_count'], // ✅ i18n
              hintText: '12',
              prefixIcon: Icon(Icons.water_drop_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      
      case HardwareType.reservoir:
        return [
          TextFormField(
            controller: _capacityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_capacity'], // ✅ i18n
              hintText: '100',
              prefixIcon: Icon(Icons.local_drink, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'L',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _materialController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_material'], // ✅ i18n
              hintText: 'z.B. Kunststoff, Edelstahl',
              prefixIcon: Icon(Icons.category),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(_t['add_hardware_chiller']), // ✅ i18n
            value: _hasChiller ?? false,
            onChanged: (value) => setState(() => _hasChiller = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(_t['add_hardware_air_pump']), // ✅ i18n
            value: _hasAirPump ?? false,
            onChanged: (value) => setState(() => _hasAirPump = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ];
      
      // ========== MONITORING ==========
      case HardwareType.phMeter:
      case HardwareType.ecMeter:
      case HardwareType.thermometer:
      case HardwareType.hygrometer:
      case HardwareType.co2Sensor:
        return [
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
                    _t['add_hardware_meter_info'], // ✅ i18n
                    style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ];
      
      // ========== SONSTIGES ==========
      case HardwareType.filter:
        return [
          TextFormField(
            controller: _airflowController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_throughput'], // ✅ i18n
              hintText: '420',
              prefixIcon: Icon(Icons.air, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'm³/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? _t['add_hardware_required'] : null, // ✅ i18n
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _filterDiameterController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_diameter'], // ✅ i18n
              hintText: _t['add_hardware_diameter_hint'], // ✅ i18n
              prefixIcon: const Icon(Icons.circle_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _filterLengthController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_length'], // ✅ i18n
              hintText: '50',
              prefixIcon: const Icon(Icons.straighten),
              border: const OutlineInputBorder(),
              suffixText: 'cm',
            ),
          ),
        ];
      
      case HardwareType.controller:
        return [
          TextFormField(
            controller: _controllerTypeController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_controller_type'], // ✅ i18n
              hintText: _t['add_hardware_controller_hint'], // ✅ i18n
              prefixIcon: const Icon(Icons.category),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _outputCountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _t['add_hardware_output_count'], // ✅ i18n
              hintText: '4',
              prefixIcon: const Icon(Icons.power),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllerFunctionsController,
            decoration: InputDecoration(
              labelText: _t['add_hardware_functions'], // ✅ i18n
              hintText: _t['add_hardware_functions_hint'], // ✅ i18n
              prefixIcon: const Icon(Icons.settings),
              border: const OutlineInputBorder(),
            ),
          ),
        ];
      
      case HardwareType.other:
      default:
        return [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300] ?? Colors.grey),
            ),
            child: Text(
              _t['add_hardware_other_info'], // ✅ i18n
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ];
    }
  }

  Widget _buildPurchaseSection() {
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['add_hardware_purchase_info'], // ✅ i18n
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.calendar_today, color: Colors.grey[700]),
          title: Text(_t['add_hardware_purchase_date']), // ✅ i18n
          subtitle: Text(
            _purchaseDate != null
                ? dateFormat.format(_purchaseDate!)
                : _t['add_hardware_not_set'], // ✅ i18n
          ),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _purchaseDate ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() => _purchaseDate = date);
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _purchasePriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _t['add_hardware_purchase_price'], // ✅ i18n
            hintText: '299.99',
            prefixIcon: const Icon(Icons.euro),
            border: const OutlineInputBorder(),
            suffixText: '€',
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t['notes'], // ✅ i18n (reused)
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: _t['add_hardware_notes_hint'], // ✅ i18n
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saveHardware,
      icon: const Icon(Icons.add),
      label: Text(_t['add_hardware_add_button']), // ✅ i18n
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
