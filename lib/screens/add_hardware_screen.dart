// =============================================
// GROWLOG - Add Hardware Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hardware.dart';
import '../models/enums.dart';
import '../repositories/hardware_repository.dart';
import '../utils/app_messages.dart';

class AddHardwareScreen extends StatefulWidget {
  final int roomId;

  const AddHardwareScreen({super.key, required this.roomId});

  @override
  State<AddHardwareScreen> createState() => _AddHardwareScreenState();
}

class _AddHardwareScreenState extends State<AddHardwareScreen> {
  final _formKey = GlobalKey<FormState>();
  final HardwareRepository _hardwareRepo = HardwareRepository();

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
    _selectedType = HardwareType.ledPanel;
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
        title: const Text('Hardware hinzufügen'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Fertig',
              style: TextStyle(
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
    final grouped = <HardwareCategory, List<HardwareType>>{};
    for (final type in HardwareType.values) {
      grouped.putIfAbsent(type.category, () => []).add(type);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hardware-Typ',
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
          'Basis-Informationen',
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
                  labelText: 'Marke *',
                  hintText: 'z.B. Mars Hydro',
                  prefixIcon: Icon(Icons.business, color: Colors.orange[700]),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bitte Marke eingeben';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Modell',
                  hintText: 'z.B. TS1000',
                  prefixIcon: Icon(Icons.info),
                  border: OutlineInputBorder(),
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
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Der Name wird automatisch generiert: Marke + Modell',
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
          'Technische Daten',
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
          decoration: const InputDecoration(
            labelText: 'Anzahl',
            hintText: '1',
            prefixIcon: Icon(Icons.numbers),
            border: OutlineInputBorder(),
            suffixText: 'Stk',
          ),
        ),
        
        // Spezifikationen
        const SizedBox(height: 12),
        TextFormField(
          controller: _specificationsController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Zusätzliche Spezifikationen',
            hintText: 'Weitere technische Details...',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
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
              labelText: 'Leistung (Watt) *',
              hintText: '150',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _spectrumController,
            decoration: const InputDecoration(
              labelText: 'Spektrum',
              hintText: 'z.B. Full Spectrum, 3000K-6500K',
              prefixIcon: Icon(Icons.wb_sunny),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Dimmbar'),
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
              labelText: 'Leistung (Watt) *',
              hintText: '600',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _colorTemperatureController,
            decoration: const InputDecoration(
              labelText: 'Farbtemperatur',
              hintText: 'z.B. 2100K',
              prefixIcon: Icon(Icons.wb_incandescent),
              border: OutlineInputBorder(),
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
              labelText: 'Luftdurchsatz (m³/h) *',
              hintText: '420',
              prefixIcon: Icon(Icons.air, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'm³/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _flangeSizeController,
            decoration: const InputDecoration(
              labelText: 'Flansch-Größe',
              hintText: 'z.B. 150mm oder 6"',
              prefixIcon: Icon(Icons.settings),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Regelbar'),
            value: _controllable ?? false,
            onChanged: (value) => setState(() => _controllable = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Leistung (Watt)',
              hintText: 'Optional',
              prefixIcon: Icon(Icons.bolt),
              border: OutlineInputBorder(),
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
              labelText: 'Luftdurchsatz (m³/h) *',
              hintText: '200',
              prefixIcon: Icon(Icons.air, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'm³/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Leistung (Watt)',
              hintText: '50',
              prefixIcon: Icon(Icons.bolt),
              border: OutlineInputBorder(),
              suffixText: 'W',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Oszillierend'),
            value: _oscillating ?? false,
            onChanged: (value) => setState(() => _oscillating = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _diameterController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Durchmesser',
              hintText: '30',
              prefixIcon: Icon(Icons.circle_outlined),
              border: OutlineInputBorder(),
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
              labelText: 'Kühlleistung (BTU) *',
              hintText: '9000',
              prefixIcon: Icon(Icons.ac_unit, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'BTU',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Leistung (Watt) *',
              hintText: '1000',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
        ];
      
      case HardwareType.heater:
        return [
          TextFormField(
            controller: _heatingPowerController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Heizleistung (Watt) *',
              hintText: '2000',
              prefixIcon: Icon(Icons.whatshot, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _coverageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Abdeckung',
              hintText: '20',
              prefixIcon: Icon(Icons.crop_square),
              border: OutlineInputBorder(),
              suffixText: 'm²',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Mit Thermostat'),
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
              labelText: 'Leistung (Watt) *',
              hintText: '300',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
        ];
      
      case HardwareType.humidifier:
        return [
          TextFormField(
            controller: _humidificationRateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Befeuchtungsleistung (ml/h) *',
              hintText: '300',
              prefixIcon: Icon(Icons.water_drop, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'ml/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Leistung (Watt) *',
              hintText: '30',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
        ];
      
      // ========== BEWÄSSERUNG ==========
      case HardwareType.pump:
        return [
          TextFormField(
            controller: _pumpRateController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Förderleistung (L/h) *',
              hintText: '1000',
              prefixIcon: Icon(Icons.water, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'L/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _wattageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Leistung (Watt) *',
              hintText: '50',
              prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'W',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
        ];
      
      case HardwareType.timer:
        return [
          CheckboxListTile(
            title: const Text('Digital'),
            subtitle: const Text('Analog wenn deaktiviert'),
            value: _isDigital ?? false,
            onChanged: (value) => setState(() => _isDigital = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _programCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Anzahl Programme',
              hintText: '8',
              prefixIcon: Icon(Icons.event_repeat),
              border: OutlineInputBorder(),
            ),
          ),
        ];
      
      case HardwareType.dripSystem:
        return [
          TextFormField(
            controller: _dripperCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Anzahl Tropfer',
              hintText: '12',
              prefixIcon: Icon(Icons.water_drop_outlined),
              border: OutlineInputBorder(),
            ),
          ),
        ];
      
      case HardwareType.reservoir:
        return [
          TextFormField(
            controller: _capacityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Kapazität (L) *',
              hintText: '100',
              prefixIcon: Icon(Icons.local_drink, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'L',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _materialController,
            decoration: const InputDecoration(
              labelText: 'Material',
              hintText: 'z.B. Kunststoff, Edelstahl',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Mit Chiller'),
            value: _hasChiller ?? false,
            onChanged: (value) => setState(() => _hasChiller = value),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Mit Luftpumpe'),
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
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Messgeräte benötigen keine speziellen technischen Daten',
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
              labelText: 'Durchsatz (m³/h) *',
              hintText: '420',
              prefixIcon: Icon(Icons.air, color: Colors.orange[700]),
              border: const OutlineInputBorder(),
              suffixText: 'm³/h',
            ),
            validator: (value) => value?.isEmpty ?? true ? 'Bitte angeben' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _filterDiameterController,
            decoration: const InputDecoration(
              labelText: 'Durchmesser',
              hintText: 'z.B. 150mm',
              prefixIcon: Icon(Icons.circle_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _filterLengthController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Länge',
              hintText: '50',
              prefixIcon: Icon(Icons.straighten),
              border: OutlineInputBorder(),
              suffixText: 'cm',
            ),
          ),
        ];
      
      case HardwareType.controller:
        return [
          TextFormField(
            controller: _controllerTypeController,
            decoration: const InputDecoration(
              labelText: 'Controller-Typ',
              hintText: 'z.B. Klima-Controller, Bewässerungs-Controller',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _outputCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Anzahl Ausgänge',
              hintText: '4',
              prefixIcon: Icon(Icons.power),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _controllerFunctionsController,
            decoration: const InputDecoration(
              labelText: 'Funktionen',
              hintText: 'z.B. Temp/Feuchte/Timer',
              prefixIcon: Icon(Icons.settings),
              border: OutlineInputBorder(),
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
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Text(
              'Nutze das Feld "Zusätzliche Spezifikationen" für Details',
              style: TextStyle(fontSize: 12),
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
          'Kauf-Informationen (optional)',
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
          title: const Text('Kaufdatum'),
          subtitle: Text(
            _purchaseDate != null
                ? dateFormat.format(_purchaseDate!)
                : 'Nicht gesetzt',
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
          decoration: const InputDecoration(
            labelText: 'Kaufpreis',
            hintText: '299.99',
            prefixIcon: Icon(Icons.euro),
            border: OutlineInputBorder(),
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
          'Notizen',
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
          decoration: const InputDecoration(
            hintText: 'Zusätzliche Informationen, Wartungshinweise, etc...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saveHardware,
      icon: const Icon(Icons.add),
      label: const Text('Hardware hinzufügen'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
