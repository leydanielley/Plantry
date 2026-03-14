import 'package:flutter/material.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_form_field.dart';
import 'package:growlog_app/widgets/plantry_button.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';
import 'package:growlog_app/models/fertilizer.dart';
import 'package:growlog_app/database/prefilled_fertilizers.dart';
import 'package:growlog_app/repositories/interfaces/i_fertilizer_repository.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/di/service_locator.dart';

class AddFertilizerScreen extends StatefulWidget {
  const AddFertilizerScreen({super.key});

  @override
  State<AddFertilizerScreen> createState() => _AddFertilizerScreenState();
}

class _AddFertilizerScreenState extends State<AddFertilizerScreen> {
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  final _searchController = TextEditingController();
  List<Fertilizer> _filteredFertilizers = [];
  late AppTranslations _t;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _filteredFertilizers = PrefilledFertilizers.all;
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _filteredFertilizers = PrefilledFertilizers.all
              .where((f) =>
                  f.name.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                  (f.brand?.toLowerCase().contains(_searchController.text.toLowerCase()) ?? false))
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectFertilizer(Fertilizer fertilizer) async {
    try {
      await _fertilizerRepo.save(fertilizer);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  void _addCustom() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomFertilizerScreen()),
    ).then((res) {
      if (res == true && mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['add_fertilizer'],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: PlantryFormField(
              controller: _searchController,
              label: 'Dünger suchen...',
              prefixIcon: const Icon(Icons.search, color: DT.textTertiary),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredFertilizers.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _filteredFertilizers.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: PlantryButton(
                      label: 'Eigenen Dünger erstellen',
                      onPressed: _addCustom,
                      isPrimary: false,
                    ),
                  );
                }
                final fertilizer = _filteredFertilizers[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PlantryCard(
                    onTap: () => _selectFertilizer(fertilizer),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fertilizer.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: DT.textPrimary,
                                ),
                              ),
                              Text(
                                fertilizer.brand ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: DT.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (fertilizer.npk != null)
                          Text(
                            fertilizer.npk!,
                            style: DT.mono(color: DT.accent, weight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Separate screen for custom fertilizer creation
class CustomFertilizerScreen extends StatefulWidget {
  const CustomFertilizerScreen({super.key});

  @override
  State<CustomFertilizerScreen> createState() => _CustomFertilizerScreenState();
}

class _CustomFertilizerScreenState extends State<CustomFertilizerScreen> {
  final _formKey = GlobalKey<FormState>();
  final IFertilizerRepository _fertilizerRepo = getIt<IFertilizerRepository>();
  late AppTranslations _t;
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _npkController = TextEditingController();
  final _typeController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _npkController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final f = Fertilizer(
        name: _nameController.text,
        brand: _brandController.text,
        npk: _npkController.text,
        type: _typeController.text,
        isCustom: true,
      );
      await _fertilizerRepo.save(f);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['add_fertilizer_title'],
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PlantryFormField(
              controller: _nameController,
              label: _t['add_fertilizer_name_label'],
              validator: (v) => v!.isEmpty ? _t['add_fertilizer_name_required'] : null,
            ),
            const SizedBox(height: 16),
            PlantryFormField(controller: _brandController, label: _t['add_fertilizer_brand_label']),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: PlantryFormField(controller: _npkController, label: _t['add_fertilizer_npk_label'])),
                const SizedBox(width: 12),
                Expanded(child: PlantryFormField(controller: _typeController, label: _t['add_fertilizer_type_label'])),
              ],
            ),
            const SizedBox(height: 32),
            PlantryButton(
              label: _t['save'],
              onPressed: _save,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
