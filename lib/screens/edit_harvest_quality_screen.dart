// =============================================
// GROWLOG - Edit Harvest Quality Control Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/models/harvest.dart';
import 'package:growlog_app/repositories/interfaces/i_harvest_repository.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class EditHarvestQualityScreen extends StatefulWidget {
  final Harvest harvest;

  const EditHarvestQualityScreen({super.key, required this.harvest});

  @override
  State<EditHarvestQualityScreen> createState() =>
      _EditHarvestQualityScreenState();
}

class _EditHarvestQualityScreenState extends State<EditHarvestQualityScreen>
    with SingleTickerProviderStateMixin {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  late AppTranslations _t;
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // Quality Data
  final TextEditingController _thcController = TextEditingController();
  final TextEditingController _cbdController = TextEditingController();
  final TextEditingController _terpeneController = TextEditingController();

  // Rating Data
  int? _rating;
  final TextEditingController _tasteController = TextEditingController();
  final TextEditingController _effectController = TextEditingController();
  final TextEditingController _overallNotesController = TextEditingController();

  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    _thcController.text = widget.harvest.thcPercentage?.toString() ?? '';
    _cbdController.text = widget.harvest.cbdPercentage?.toString() ?? '';
    _terpeneController.text = widget.harvest.terpeneProfile ?? '';
    _rating = widget.harvest.rating;
    _tasteController.text = widget.harvest.tasteNotes ?? '';
    _effectController.text = widget.harvest.effectNotes ?? '';
    _overallNotesController.text = widget.harvest.overallNotes ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _thcController.dispose();
    _cbdController.dispose();
    _terpeneController.dispose();
    _tasteController.dispose();
    _effectController.dispose();
    _overallNotesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final updated = widget.harvest.copyWith(
        thcPercentage: double.tryParse(_thcController.text),
        cbdPercentage: double.tryParse(_cbdController.text),
        terpeneProfile: _terpeneController.text.isNotEmpty
            ? _terpeneController.text
            : null,
        rating: _rating,
        tasteNotes: _tasteController.text.isNotEmpty
            ? _tasteController.text
            : null,
        effectNotes: _effectController.text.isNotEmpty
            ? _effectController.text
            : null,
        overallNotes: _overallNotesController.text.isNotEmpty
            ? _overallNotesController.text
            : null,
        updatedAt: DateTime.now(),
      );

      await _harvestRepo.updateHarvest(updated);

      if (mounted) {
        Navigator.pop(context, true);
        AppMessages.showSuccess(context, _t['harvest_quality_updated']);
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
      title: _t['quality_control_edit'],
      actions: [
        if (!_isSaving)
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: DT.accent,
        tabs: [
          Tab(
            icon: const Icon(Icons.science, color: DT.textPrimary),
            child: Text(
              _t['edit_harvest_tab_quality'],
              style: const TextStyle(color: DT.textPrimary),
            ),
          ),
          Tab(
            icon: const Icon(Icons.star, color: DT.textPrimary),
            child: Text(
              _t['edit_harvest_tab_rating'],
              style: const TextStyle(color: DT.textPrimary),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [_buildQualityTab(), _buildRatingTab()],
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DT.textPrimary,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? _t['saving'] : _t['save']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.secondary,
                  foregroundColor: DT.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DT.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DT.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.science, color: DT.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t['harvest_section_cannabinoids'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // THC
          TextFormField(
            controller: _thcController,
            decoration: InputDecoration(
              labelText: _t['label_thc'],
              hintText: _t['hint_thc'],
              suffixText: '%',
              prefixIcon: const Icon(Icons.science, color: DT.error),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: _t['helper_thc'],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // CBD
          TextFormField(
            controller: _cbdController,
            decoration: InputDecoration(
              labelText: _t['label_cbd'],
              hintText: _t['hint_cbd'],
              suffixText: '%',
              prefixIcon: const Icon(Icons.science, color: DT.success),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: _t['helper_cbd'],
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),

          // Preview
          if (_thcController.text.isNotEmpty || _cbdController.text.isNotEmpty)
            _buildCannabinoidPreview(),
          const SizedBox(height: 20),

          // Terpenes
          TextFormField(
            controller: _terpeneController,
            decoration: InputDecoration(
              labelText: _t['label_terpene'],
              hintText: _t['hint_terpene'],
              prefixIcon: const Icon(
                Icons.format_list_bulleted,
                color: DT.info,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),

          // Terpene Suggestions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  'Myrcene',
                  'Limonene',
                  'Caryophyllene',
                  'Pinene',
                  'Linalool',
                  'Humulene',
                ].map((terpene) {
                  return ActionChip(
                    label: Text(terpene),
                    onPressed: () {
                      final current = _terpeneController.text;
                      if (current.isEmpty) {
                        _terpeneController.text = terpene;
                      } else if (!current.contains(terpene)) {
                        _terpeneController.text = '$current, $terpene';
                      }
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),

          // Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DT.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DT.secondary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: DT.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t['edit_harvest_quality_info'],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCannabinoidPreview() {
    final thc = double.tryParse(_thcController.text);
    final cbd = double.tryParse(_cbdController.text);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DT.info.withValues(alpha: 0.08),
            DT.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DT.secondary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t['cannabinoid_preview_title'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: DT.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (thc != null) _buildCannabinoidBar('THC', thc, DT.error),
          if (cbd != null) ...[
            const SizedBox(height: 12),
            _buildCannabinoidBar('CBD', cbd, DT.success),
          ],
        ],
      ),
    );
  }

  Widget _buildCannabinoidBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 30).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: DT.elevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DT.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DT.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: DT.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t['rating_section_title'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Star Rating
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _t['overall_rating_title'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          (_rating ?? 0) > index
                              ? Icons.star
                              : Icons.star_border,
                          size: 40,
                        ),
                        color: DT.warning,
                        onPressed: () {
                          setState(() => _rating = index + 1);
                        },
                      );
                    }),
                  ),
                  if (_rating != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '$_rating / 5 Sterne',
                      style: const TextStyle(
                        fontSize: 14,
                        color: DT.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_rating == null)
                    Text(
                      _t['rating_prompt'],
                      style: const TextStyle(fontSize: 12, color: DT.textTertiary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Taste Notes
          TextFormField(
            controller: _tasteController,
            decoration: InputDecoration(
              labelText: _t['label_taste'],
              hintText: _t['hint_taste'],
              prefixIcon: const Icon(Icons.restaurant, color: DT.warning),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                [
                  'Fruchtig',
                  'Erdig',
                  'Zitrusartig',
                  'Süß',
                  'Würzig',
                  'Blumig',
                ].map((taste) {
                  return ActionChip(
                    label: Text(taste),
                    onPressed: () {
                      final current = _tasteController.text;
                      if (current.isEmpty) {
                        _tasteController.text = taste;
                      } else if (!current.contains(taste)) {
                        _tasteController.text = '$current, $taste';
                      }
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 20),

          // Effect Notes
          TextFormField(
            controller: _effectController,
            decoration: InputDecoration(
              labelText: _t['label_effect'],
              hintText: _t['hint_effect'],
              prefixIcon: const Icon(Icons.psychology, color: DT.info),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                [
                  'Entspannend',
                  'Euphorisch',
                  'Kreativ',
                  'Energetisch',
                  'Fokussiert',
                  'Schläfrig',
                ].map((effect) {
                  return ActionChip(
                    label: Text(effect),
                    onPressed: () {
                      final current = _effectController.text;
                      if (current.isEmpty) {
                        _effectController.text = effect;
                      } else if (!current.contains(effect)) {
                        _effectController.text = '$current, $effect';
                      }
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 20),

          // Overall Notes
          TextFormField(
            controller: _overallNotesController,
            decoration: InputDecoration(
              labelText: _t['label_overall_notes'],
              hintText: _t['hint_overall_notes'],
              prefixIcon: const Icon(Icons.note, color: DT.secondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}
