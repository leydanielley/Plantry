// =============================================
// GROWLOG - Edit Hardware Screen
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import 'package:intl/intl.dart';
import '../models/hardware.dart';
import '../models/room.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_hardware_repository.dart';
import '../repositories/interfaces/i_room_repository.dart';
import '../di/service_locator.dart';

class EditHardwareScreen extends StatefulWidget {
  final Hardware hardware;

  const EditHardwareScreen({super.key, required this.hardware});

  @override
  State<EditHardwareScreen> createState() => _EditHardwareScreenState();
}

class _EditHardwareScreenState extends State<EditHardwareScreen> {
  final _formKey = GlobalKey<FormState>();
  final IHardwareRepository _hardwareRepo = getIt<IHardwareRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  Room? _room;

  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _wattageController;
  late final TextEditingController _quantityController;
  late final TextEditingController _specificationsController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _notesController;

  late HardwareType _selectedType;
  DateTime? _purchaseDate;
  bool _isLoading = false;

  /// Prüft ob Wattage für diesen Hardware-Typ relevant ist
  bool get _isWattageRelevant {
    switch (_selectedType.category) {
      case HardwareCategory.lighting:
        return true;
      case HardwareCategory.climate:
        return true;
      case HardwareCategory.watering:
        return _selectedType == HardwareType.pump;
      case HardwareCategory.monitoring:
        return false;
      case HardwareCategory.other:
        return _selectedType == HardwareType.controller;
    }
  }

  /// Generiert automatisch einen Namen aus Marke, Modell und Typ
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

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing hardware data
    _nameController = TextEditingController(text: widget.hardware.name);
    _brandController = TextEditingController(text: widget.hardware.brand ?? '');
    _modelController = TextEditingController(text: widget.hardware.model ?? '');
    _wattageController = TextEditingController(
      text: widget.hardware.wattage?.toString() ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.hardware.quantity?.toString() ?? '1',
    );
    _specificationsController = TextEditingController(
      text: widget.hardware.specifications ?? '',
    );
    _purchasePriceController = TextEditingController(
      text: widget.hardware.purchasePrice?.toString() ?? '',
    );
    _notesController = TextEditingController(text: widget.hardware.notes ?? '');
    
    _selectedType = widget.hardware.type;
    _purchaseDate = widget.hardware.purchaseDate;

    _loadRoom();
  }

  Future<void> _loadRoom() async {
    final room = await _roomRepo.findById(widget.hardware.roomId);
    if (mounted) {
      setState(() {
        _room = room;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _wattageController.dispose();
    _quantityController.dispose();
    _specificationsController.dispose();
    _purchasePriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveHardware() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final hardware = widget.hardware.copyWith(
        name: _generateName(), // Automatisch generierter Name
        type: _selectedType,
        brand: _brandController.text.trim().isNotEmpty
            ? _brandController.text.trim()
            : null,
        model: _modelController.text.trim().isNotEmpty
            ? _modelController.text.trim()
            : null,
        wattage: _isWattageRelevant && _wattageController.text.isNotEmpty
            ? int.tryParse(_wattageController.text)
            : null,
        quantity: _quantityController.text.isNotEmpty
            ? int.tryParse(_quantityController.text) ?? 1
            : 1,
        specifications: _specificationsController.text.trim().isNotEmpty
            ? _specificationsController.text.trim()
            : null,
        purchaseDate: _purchaseDate,
        purchasePrice: _purchasePriceController.text.isNotEmpty
            ? double.tryParse(_purchasePriceController.text)
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      await _hardwareRepo.save(hardware);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('EditHardwareScreen', 'Error saving: $e');
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
        title: const Text('Hardware bearbeiten'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
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

    // Gruppiere nach Kategorie
    final grouped = <HardwareCategory, List<HardwareType>>{};
    for (final type in availableTypes) {
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
        Row(
          children: [
            if (_isWattageRelevant) ...[  // Nur zeigen wenn relevant
              Expanded(
                child: TextFormField(
                  controller: _wattageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Leistung (Watt)',
                    hintText: '150',
                    prefixIcon: Icon(Icons.bolt, color: Colors.orange[700]),
                    border: const OutlineInputBorder(),
                    suffixText: 'W',
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: TextFormField(
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
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _specificationsController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Spezifikationen',
            hintText: 'z.B. Full Spectrum, 2.7 µmol/J, dimmbar',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
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
    return ElevatedButton(
      onPressed: _saveHardware,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      child: const Text('Änderungen speichern'),
    );
  }
}
