// =============================================
// GROWLOG - Edit Harvest Curing Screen
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/translations.dart';
import 'package:intl/intl.dart';
import '../models/harvest.dart';
import '../repositories/interfaces/i_harvest_repository.dart';
import '../di/service_locator.dart';

class EditHarvestCuringScreen extends StatefulWidget {
  final Harvest harvest;

  const EditHarvestCuringScreen({super.key, required this.harvest});

  @override
  State<EditHarvestCuringScreen> createState() => _EditHarvestCuringScreenState();
}

class _EditHarvestCuringScreenState extends State<EditHarvestCuringScreen> {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final _formKey = GlobalKey<FormState>();
  
  DateTime? _curingStartDate;
  DateTime? _curingEndDate;
  final TextEditingController _methodController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  bool _isSaving = false;

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

    try{
      int? curingDays;
      if (_curingStartDate != null && _curingEndDate != null) {
        curingDays = _curingEndDate!.difference(_curingStartDate!).inDays;
      }

      final updated = widget.harvest.copyWith(
        curingStartDate: _curingStartDate,
        curingEndDate: _curingEndDate,
        curingDays: curingDays,
        curingMethod: _methodController.text.isNotEmpty ? _methodController.text : null,
        curingNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
        updatedAt: DateTime.now(),
      );

      await _harvestRepo.updateHarvest(updated);

      if (mounted) {
        Navigator.pop(context, true);
        AppMessages.showSuccess(context, 'Curing aktualisiert! ✅');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppMessages.showError(context,
'Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Curing bearbeiten'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
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
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200] ?? Colors.purple),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.purple[700]),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Curing-Daten',
                        style: TextStyle(
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
                label: 'Start-Datum',
                date: _curingStartDate,
                icon: Icons.play_arrow,
                color: Colors.purple,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _curingStartDate ?? DateTime.now(),
                    firstDate: widget.harvest.dryingEndDate ?? widget.harvest.harvestDate,
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (date != null) setState(() => _curingStartDate = date);
                },
                onClear: () => setState(() => _curingStartDate = null),
              ),
              const SizedBox(height: 16),
              
              _buildDateField(
                label: 'End-Datum',
                date: _curingEndDate,
                icon: Icons.stop,
                color: Colors.green,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _curingEndDate ?? DateTime.now(),
                    firstDate: _curingStartDate ?? widget.harvest.dryingEndDate ?? widget.harvest.harvestDate,
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
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Dauer: ${_curingEndDate!.difference(_curingStartDate!).inDays} Tage',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _methodController,
                decoration: InputDecoration(
                  labelText: 'Curing-Methode',
                  hintText: 'z.B. Glass Jars, Grove Bags',
                  prefixIcon: const Icon(Icons.dashboard),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              Wrap(
                spacing: 8,
                children: ['Glass Jars', 'Grove Bags', 'CVault', 'Vacuum Sealed'].map((method) {
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
                  labelText: 'Curing Notizen',
                  hintText: 'Burping Schedule, Besonderheiten...',
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
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple[200] ?? Colors.purple),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Tipps',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...[
                      'Mindestens 2-4 Wochen curen',
                      'Täglich "burpen" in Woche 1-2',
                      'Luftfeuchtigkeit: 58-62% ideal',
                      'Dunkel und kühl lagern',
                    ].map((tip) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text(tip, style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    )),
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
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                child: const Text('Abbrechen'),
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
                label: Text(_isSaving ? 'Speichert...' : 'Speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
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
          border: Border.all(color: Colors.grey[300] ?? Colors.grey),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    date != null ? DateFormat('dd.MM.yyyy').format(date) : AppTranslations(Localizations.localeOf(context).languageCode)['edit_harvest_not_set'],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                      color: date != null ? Colors.black : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            if (date != null && onClear != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: onClear,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }
}
