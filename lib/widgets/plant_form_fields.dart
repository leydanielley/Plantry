// =============================================
// GROWLOG - Plant Form Fields (Shared Widget)
// =============================================

import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../models/room.dart';
import '../models/grow.dart';
import '../utils/input_constraints.dart';

/// Reusable form fields for plant creation and editing
///
/// This widget extracts common form fields to reduce duplication
/// between AddPlantScreen and EditPlantScreen (~300 lines saved)
class PlantFormFields extends StatelessWidget {
  // Form Controllers
  final TextEditingController nameController;
  final TextEditingController strainController;
  final TextEditingController breederController;
  final TextEditingController containerSizeController;
  final TextEditingController systemSizeController;

  // Current values
  final SeedType seedType;
  final GenderType genderType;
  final Medium medium;
  final PlantPhase phase;
  final int? selectedRoomId;
  final int? selectedGrowId;
  final DateTime? seedDate;

  // Data sources
  final List<Room> rooms;
  final List<Grow> grows;
  final bool loadingRooms;
  final bool loadingGrows;

  // Callbacks
  final ValueChanged<SeedType> onSeedTypeChanged;
  final ValueChanged<GenderType> onGenderTypeChanged;
  final ValueChanged<Medium> onMediumChanged;
  final ValueChanged<PlantPhase> onPhaseChanged;
  final ValueChanged<int?> onRoomSelected;
  final ValueChanged<int?> onGrowSelected;
  final ValueChanged<DateTime?> onSeedDateChanged;

  // Optional features
  final VoidCallback? onCreateGrow;
  final bool showCreateGrowButton;
  final bool disableGrowSelection;
  final bool showPhaseSelection;

  const PlantFormFields({
    super.key,
    required this.nameController,
    required this.strainController,
    required this.breederController,
    required this.containerSizeController,
    required this.systemSizeController,
    required this.seedType,
    required this.genderType,
    required this.medium,
    required this.phase,
    required this.selectedRoomId,
    required this.selectedGrowId,
    required this.seedDate,
    required this.rooms,
    required this.grows,
    required this.loadingRooms,
    required this.loadingGrows,
    required this.onSeedTypeChanged,
    required this.onGenderTypeChanged,
    required this.onMediumChanged,
    required this.onPhaseChanged,
    required this.onRoomSelected,
    required this.onGrowSelected,
    required this.onSeedDateChanged,
    this.onCreateGrow,
    this.showCreateGrowButton = false,
    this.disableGrowSelection = false,
    this.showPhaseSelection = true,
  });

  bool get _isHydroSystem =>
      medium == Medium.dwc ||
      medium == Medium.rdwc ||
      medium == Medium.aero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicInfo(context),
        const SizedBox(height: 24),
        _buildGeneticsInfo(context),
        const SizedBox(height: 24),
        _buildGrowInfo(context),
        const SizedBox(height: 24),
        _buildContainerInfo(context),
        const SizedBox(height: 24),
        _buildDatePicker(context),
      ],
    );
  }

  Widget _buildBasicInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grundlegende Informationen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: nameController,
          // ✅ FIX: Add maxLength to prevent database overflow
          maxLength: InputConstraints.nameMaxLength,
          decoration: const InputDecoration(
            labelText: 'Pflanzenname *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_florist),
            counterText: '', // Hide character counter
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Bitte Namen eingeben';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGeneticsInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Genetik-Informationen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: strainController,
          // ✅ FIX: Add maxLength to prevent database overflow
          maxLength: InputConstraints.nameMaxLength,
          decoration: const InputDecoration(
            labelText: 'Strain/Sorte',
            border: OutlineInputBorder(),
            hintText: 'z.B. Gorilla Glue #4',
            prefixIcon: Icon(Icons.science),
            counterText: '', // Hide character counter
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: breederController,
          // ✅ FIX: Add maxLength to prevent database overflow
          maxLength: InputConstraints.shortNameMaxLength,
          decoration: const InputDecoration(
            labelText: 'Breeder',
            border: OutlineInputBorder(),
            hintText: 'z.B. Original Sensible',
            prefixIcon: Icon(Icons.business),
            counterText: '', // Hide character counter
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdown<SeedType>(
          context: context,
          label: 'Samen-Typ',
          value: seedType,
          items: SeedType.values,
          onChanged: onSeedTypeChanged,
        ),
        const SizedBox(height: 16),
        _buildDropdown<GenderType>(
          context: context,
          label: 'Geschlecht',
          value: genderType,
          items: GenderType.values,
          onChanged: onGenderTypeChanged,
        ),
        const SizedBox(height: 16),
        _buildDropdown<Medium>(
          context: context,
          label: 'Medium',
          value: medium,
          items: Medium.values,
          onChanged: onMediumChanged,
        ),
        if (showPhaseSelection) ...[
          const SizedBox(height: 16),
          _buildDropdown<PlantPhase>(
            context: context,
            label: 'Phase',
            value: phase,
            items: PlantPhase.values,
            onChanged: onPhaseChanged,
          ),
        ],
      ],
    );
  }

  Widget _buildGrowInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grow-Zuordnung',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (loadingGrows)
          const Center(child: CircularProgressIndicator())
        else
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedGrowId,
                  decoration: const InputDecoration(
                    labelText: 'Grow zuweisen',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.eco),
                  ),
                  items: grows.map((grow) {
                    return DropdownMenuItem(
                      value: grow.id,
                      child: Text(grow.name),
                    );
                  }).toList(),
                  onChanged: disableGrowSelection ? null : onGrowSelected,
                ),
              ),
              if (showCreateGrowButton && onCreateGrow != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Colors.green[700],
                  onPressed: onCreateGrow,
                  tooltip: 'Neuen Grow erstellen',
                ),
              ],
            ],
          ),
        const SizedBox(height: 16),
        if (loadingRooms)
          const Center(child: CircularProgressIndicator())
        else
          DropdownButtonFormField<int>(
            initialValue: selectedRoomId,
            decoration: const InputDecoration(
              labelText: 'Raum zuweisen',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home),
            ),
            items: rooms.map((room) {
              return DropdownMenuItem(
                value: room.id,
                child: Text(room.name),
              );
            }).toList(),
            onChanged: onRoomSelected,
          ),
      ],
    );
  }

  Widget _buildContainerInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Container-Informationen',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isHydroSystem)
          TextFormField(
            controller: systemSizeController,
            // ✅ FIX: Add maxLength to prevent database overflow
            maxLength: InputConstraints.numericMaxLength,
            decoration: const InputDecoration(
              labelText: 'System-Größe (L)',
              border: OutlineInputBorder(),
              hintText: 'z.B. 80 für 80L System',
              prefixIcon: Icon(Icons.water),
              counterText: '', // Hide character counter
            ),
            keyboardType: TextInputType.number,
          )
        else
          TextFormField(
            controller: containerSizeController,
            // ✅ FIX: Add maxLength to prevent database overflow
            maxLength: InputConstraints.numericMaxLength,
            decoration: const InputDecoration(
              labelText: 'Container-Größe (L)',
              border: OutlineInputBorder(),
              hintText: 'z.B. 11 für 11L Topf',
              prefixIcon: Icon(Icons.local_florist),
              counterText: '', // Hide character counter
            ),
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start-Datum',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Seed/Klon Datum'),
          subtitle: Text(
            seedDate != null
                ? '${seedDate!.day}.${seedDate!.month}.${seedDate!.year}'
                : 'Nicht gesetzt',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _selectDate(context),
          ),
          onTap: () => _selectDate(context),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: seedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      // Set time to midnight to avoid time zone issues
      final dateOnly = DateTime(picked.year, picked.month, picked.day);
      onSeedDateChanged(dateOnly);
    }
  }

  Widget _buildDropdown<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(_getEnumDisplayName(item)),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }

  String _getEnumDisplayName(dynamic enumValue) {
    if (enumValue is SeedType) {
      return enumValue.displayName;
    } else if (enumValue is GenderType) {
      return enumValue.displayName;
    } else if (enumValue is Medium) {
      return enumValue.displayName;
    } else if (enumValue is PlantPhase) {
      return enumValue.displayName;
    }
    return enumValue.toString().split('.').last.toUpperCase();
  }
}
