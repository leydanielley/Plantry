// =============================================
// GROWLOG - Plant Form Fields (Shared Widget)
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/enums.dart';
import 'package:growlog_app/models/room.dart';
import 'package:growlog_app/models/grow.dart';
import 'package:growlog_app/utils/input_constraints.dart';
import 'package:growlog_app/utils/translations.dart';

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
      medium == Medium.dwc || medium == Medium.rdwc || medium == Medium.aero;

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
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate('add_plant_basic_info'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: nameController,
          // ✅ FIX: Add maxLength to prevent database overflow
          maxLength: InputConstraints.nameMaxLength,
          decoration: InputDecoration(
            labelText: t.translate('add_plant_name_label'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.local_florist),
            counterText: '', // Hide character counter
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return t.translate('add_plant_name_required');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildGeneticsInfo(BuildContext context) {
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate('add_plant_genetics'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: strainController,
          // ✅ FIX: Add maxLength to prevent database overflow
          maxLength: InputConstraints.nameMaxLength,
          decoration: InputDecoration(
            labelText: t.translate('add_plant_strain'),
            border: const OutlineInputBorder(),
            hintText: 'z.B. Gorilla Glue #4',
            prefixIcon: const Icon(Icons.science),
            counterText: '', // Hide character counter
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: breederController,
          // ✅ FIX: Add maxLength to prevent database overflow
          maxLength: InputConstraints.shortNameMaxLength,
          decoration: InputDecoration(
            labelText: t.translate('add_plant_breeder'),
            border: const OutlineInputBorder(),
            hintText: t.translate('add_plant_breeder_hint'),
            prefixIcon: const Icon(Icons.business),
            counterText: '', // Hide character counter
          ),
        ),
        const SizedBox(height: 16),
        _buildDropdown<SeedType>(
          context: context,
          label: t.translate('add_plant_seed_type'),
          value: seedType,
          items: SeedType.values,
          onChanged: onSeedTypeChanged,
        ),
        const SizedBox(height: 16),
        _buildDropdown<GenderType>(
          context: context,
          label: t.translate('add_plant_gender'),
          value: genderType,
          items: GenderType.values,
          onChanged: onGenderTypeChanged,
        ),
        const SizedBox(height: 16),
        _buildDropdown<Medium>(
          context: context,
          label: t.translate('add_plant_medium'),
          value: medium,
          items: Medium.values,
          onChanged: onMediumChanged,
        ),
        if (showPhaseSelection) ...[
          const SizedBox(height: 16),
          _buildDropdown<PlantPhase>(
            context: context,
            label: t.translate('add_plant_phase'),
            value: phase,
            items: PlantPhase.values,
            onChanged: onPhaseChanged,
          ),
        ],
      ],
    );
  }

  Widget _buildGrowInfo(BuildContext context) {
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate('add_plant_grow_setup'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
                  decoration: InputDecoration(
                    labelText: t.translate('add_plant_grow_optional'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.eco),
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
                  tooltip: t.translate('add_plant_create_grow'),
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
            decoration: InputDecoration(
              labelText: t.translate('add_plant_room_optional'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.home),
            ),
            items: rooms.map((room) {
              return DropdownMenuItem(value: room.id, child: Text(room.name));
            }).toList(),
            onChanged: onRoomSelected,
          ),
      ],
    );
  }

  Widget _buildContainerInfo(BuildContext context) {
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate(
            _isHydroSystem
                ? 'add_plant_system_info'
                : 'add_plant_container_info',
          ),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_isHydroSystem)
          TextFormField(
            controller: systemSizeController,
            // ✅ FIX: Add maxLength to prevent database overflow
            maxLength: InputConstraints.numericMaxLength,
            decoration: InputDecoration(
              labelText: t.translate('add_plant_system_size'),
              border: const OutlineInputBorder(),
              hintText: t.translate('add_plant_system_size_hint'),
              prefixIcon: const Icon(Icons.water),
              counterText: '', // Hide character counter
            ),
            keyboardType: TextInputType.number,
          )
        else
          TextFormField(
            controller: containerSizeController,
            // ✅ FIX: Add maxLength to prevent database overflow
            maxLength: InputConstraints.numericMaxLength,
            decoration: InputDecoration(
              labelText: t.translate('add_plant_container_size'),
              border: const OutlineInputBorder(),
              hintText: t.translate('add_plant_container_size_hint'),
              prefixIcon: const Icon(Icons.local_florist),
              counterText: '', // Hide character counter
            ),
            keyboardType: TextInputType.number,
          ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.translate('add_plant_seed_date'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: Text(t.translate('add_plant_seed_date')),
          subtitle: Text(
            seedDate != null
                ? '${seedDate!.day}.${seedDate!.month}.${seedDate!.year}'
                : t.translate('add_plant_seed_date_not_set'),
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
