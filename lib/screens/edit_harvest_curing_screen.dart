// =============================================
// GROWLOG - Edit Harvest Curing Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class EditHarvestCuringScreen extends StatefulWidget {
  final Harvest harvest;

  const EditHarvestCuringScreen({super.key, required this.harvest});

  @override
  State<EditHarvestCuringScreen> createState() =>
      _EditHarvestCuringScreenState();
}

class _EditHarvestCuringScreenState extends State<EditHarvestCuringScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  late AppTranslations _t;
  final _formKey = GlobalKey<FormState>();

  DateTime? _curingStartDate;
  DateTime? _curingEndDate;
  final TextEditingController _methodController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _curingStartDate = widget.harvest.curingStartDate;
    _curingEndDate = widget.harvest.curingEndDate;
    _methodController.text = widget.harvest.curingMethod ?? '';
    _notesController.text = widget.harvest.curingNotes ?? '';
  }

  @override
  void dispose() {
    _methodController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      int? curingDays;
      if (_curingStartDate != null && _curingEndDate != null) {
        curingDays = _curingEndDate!.difference(_curingStartDate!).inDays;
      }

      final updated = widget.harvest.copyWith(
        curingStartDate: _curingStartDate,
        curingEndDate: _curingEndDate,
        curingDays: curingDays,
        curingMethod: _methodController.text.isNotEmpty
            ? _methodController.text
            : null,
        curingNotes: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
        updatedAt: DateTime.now(),
      );

      await _harvestRepo.updateHarvest(updated);

      if (mounted) {
        Navigator.pop(context, true);
        AppMessages.showSuccess(context, _t['curing_updated_msg']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: _t['edit_curing_title'],
      actions: [
        if (!_isSaving)
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
      ],
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DT.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DT.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2, color: DT.info),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _t['harvest_section_curing'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _buildDateField(
                label: _t['label_start_date'],
                date: _curingStartDate,
                icon: Icons.play_arrow,
                color: DT.info,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _curingStartDate ?? DateTime.now(),
                    firstDate:
                        widget.harvest.dryingEndDate ??
                        widget.harvest.harvestDate,
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (date != null) setState(() => _curingStartDate = date);
                },
                onClear: () => setState(() => _curingStartDate = null),
              ),
              const SizedBox(height: 16),

              _buildDateField(
                label: _t['label_end_date'],
                date: _curingEndDate,
                icon: Icons.stop,
                color: DT.success,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _curingEndDate ?? DateTime.now(),
                    firstDate:
                        _curingStartDate ??
                        widget.harvest.dryingEndDate ??
                        widget.harvest.harvestDate,
                    lastDate: DateTime.now().add(const Duration(days: 270)),
                  );
                  if (date != null) setState(() => _curingEndDate = date);
                },
                onClear: () => setState(() => _curingEndDate = null),
              ),
              const SizedBox(height: 20),

              if (_curingStartDate != null && _curingEndDate != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DT.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: DT.secondary),
                      const SizedBox(width: 8),
                      Text(
                        '${_t['drying_duration_label']}: ${_curingEndDate!.difference(_curingStartDate!).inDays} ${_t['days']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: DT.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _methodController,
                decoration: InputDecoration(
                  labelText: _t['label_curing_method'],
                  hintText: _t['hint_curing_method'],
                  prefixIcon: const Icon(Icons.dashboard),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                children:
                    [
                      _t['curing_method_glass_jars'],
                      _t['curing_method_grove_bags'],
                      _t['curing_method_cvault'],
                      _t['curing_method_vacuum'],
                    ].map((method) {
                      return ActionChip(
                        label: Text(method),
                        onPressed: () => _methodController.text = method,
                      );
                    }).toList(),
              ),
              const SizedBox(height: 20),

              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: _t['label_curing_notes'],
                  hintText: _t['hint_curing_notes'],
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DT.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: DT.info.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: DT.info),
                        const SizedBox(width: 8),
                        Text(
                          _t['curing_tips_title'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...[
                      _t['curing_tip_weeks'],
                      _t['curing_tip_burp'],
                      _t['curing_tip_humidity'],
                      _t['curing_tip_storage'],
                    ].map(
                      (tip) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: DT.success,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                tip,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DT.surface,
          boxShadow: [
            BoxShadow(
              color: DT.canvas.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: Text(_t['cancel']),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? _t['saving'] : _t['save']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.info,
                  foregroundColor: DT.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: DT.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DT.textSecondary,
                    ),
                  ),
                  Text(
                    date != null
                        ? DateFormat('dd.MM.yyyy').format(date)
                        : _t['edit_harvest_not_set'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: date != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: date != null ? DT.textPrimary : DT.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null && onClear != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
                color: DT.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
