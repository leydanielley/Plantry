// =============================================
// GROWLOG - Edit Harvest Screen (Enhanced)
// ✅ AUDIT FIX: i18n extraction
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../utils/translations.dart'; // ✅ AUDIT FIX: i18n
import 'package:intl/intl.dart';
import '../models/harvest.dart';
import '../repositories/interfaces/i_harvest_repository.dart';
import '../di/service_locator.dart';

class EditHarvestScreen extends StatefulWidget {
  final Harvest harvest;

  const EditHarvestScreen({super.key, required this.harvest});

  @override
  State<EditHarvestScreen> createState() => _EditHarvestScreenState();
}

class _EditHarvestScreenState extends State<EditHarvestScreen> with SingleTickerProviderStateMixin {
  late final AppTranslations _t; // ✅ AUDIT FIX: i18n
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  
  // Basic Data
  late DateTime _harvestDate;
  final TextEditingController _wetWeightController = TextEditingController();
  final TextEditingController _dryWeightController = TextEditingController();
  
  // Drying Data
  DateTime? _dryingStartDate;
  DateTime? _dryingEndDate;
  final TextEditingController _dryingMethodController = TextEditingController();
  final TextEditingController _dryingTempController = TextEditingController();
  final TextEditingController _dryingHumidityController = TextEditingController();
  
  // Curing Data
  DateTime? _curingStartDate;
  DateTime? _curingEndDate;
  final TextEditingController _curingMethodController = TextEditingController();
  final TextEditingController _curingNotesController = TextEditingController();
  
  // Quality Data
  final TextEditingController _thcController = TextEditingController();
  final TextEditingController _cbdController = TextEditingController();
  final TextEditingController _terpeneController = TextEditingController();
  
  // Rating & Notes
  int? _rating;
  final TextEditingController _tasteController = TextEditingController();
  final TextEditingController _effectController = TextEditingController();
  final TextEditingController _overallNotesController = TextEditingController();
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _t = AppTranslations(Localizations.localeOf(context).languageCode); // ✅ AUDIT FIX: i18n
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  void _loadData() {
    final h = widget.harvest;
    
    _harvestDate = h.harvestDate;
    _wetWeightController.text = h.wetWeight?.toString() ?? '';
    _dryWeightController.text = h.dryWeight?.toString() ?? '';
    
    _dryingStartDate = h.dryingStartDate;
    _dryingEndDate = h.dryingEndDate;
    _dryingMethodController.text = h.dryingMethod ?? '';
    _dryingTempController.text = h.dryingTemperature?.toString() ?? '';
    _dryingHumidityController.text = h.dryingHumidity?.toString() ?? '';
    
    _curingStartDate = h.curingStartDate;
    _curingEndDate = h.curingEndDate;
    _curingMethodController.text = h.curingMethod ?? '';
    _curingNotesController.text = h.curingNotes ?? '';
    
    _thcController.text = h.thcPercentage?.toString() ?? '';
    _cbdController.text = h.cbdPercentage?.toString() ?? '';
    _terpeneController.text = h.terpeneProfile ?? '';
    
    _rating = h.rating;
    _tasteController.text = h.tasteNotes ?? '';
    _effectController.text = h.effectNotes ?? '';
    _overallNotesController.text = h.overallNotes ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _wetWeightController.dispose();
    _dryWeightController.dispose();
    _dryingMethodController.dispose();
    _dryingTempController.dispose();
    _dryingHumidityController.dispose();
    _curingMethodController.dispose();
    _curingNotesController.dispose();
    _thcController.dispose();
    _cbdController.dispose();
    _terpeneController.dispose();
    _tasteController.dispose();
    _effectController.dispose();
    _overallNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveHarvest() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Bitte überprüfe deine Eingaben');
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      // Berechne Drying Days automatisch
      int? dryingDays;
      if (_dryingStartDate != null && _dryingEndDate != null) {
        dryingDays = _dryingEndDate!.difference(_dryingStartDate!).inDays;
      }
      
      // Berechne Curing Days automatisch
      int? curingDays;
      if (_curingStartDate != null && _curingEndDate != null) {
        curingDays = _curingEndDate!.difference(_curingStartDate!).inDays;
      }

      final updatedHarvest = widget.harvest.copyWith(
        harvestDate: _harvestDate,
        wetWeight: _parseDouble(_wetWeightController.text),
        dryWeight: _parseDouble(_dryWeightController.text),
        dryingStartDate: _dryingStartDate,
        dryingEndDate: _dryingEndDate,
        dryingDays: dryingDays,
        dryingMethod: _parseString(_dryingMethodController.text),
        dryingTemperature: _parseDouble(_dryingTempController.text),
        dryingHumidity: _parseDouble(_dryingHumidityController.text),
        curingStartDate: _curingStartDate,
        curingEndDate: _curingEndDate,
        curingDays: curingDays,
        curingMethod: _parseString(_curingMethodController.text),
        curingNotes: _parseString(_curingNotesController.text),
        thcPercentage: _parseDouble(_thcController.text),
        cbdPercentage: _parseDouble(_cbdController.text),
        terpeneProfile: _parseString(_terpeneController.text),
        rating: _rating,
        tasteNotes: _parseString(_tasteController.text),
        effectNotes: _parseString(_effectController.text),
        overallNotes: _parseString(_overallNotesController.text),
        updatedAt: DateTime.now(),
      );

      await _harvestRepo.updateHarvest(updatedHarvest);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.showSuccess(context, _t['edit_harvest_updated']); // ✅ i18n
      }
    } catch (e) {
      AppLogger.error('EditHarvestScreen', 'Error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showErrorSnackBar('Fehler beim Speichern: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    AppMessages.showError(context, message);
  }

  double? _parseDouble(String text) {
    return text.isNotEmpty ? double.tryParse(text) : null;
  }

  String? _parseString(String text) {
    return text.isNotEmpty ? text : null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop && !_isSaving) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t['edit_harvest_title']), // ✅ i18n
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveHarvest,
                tooltip: _t['edit_harvest_save_tooltip'], // ✅ i18n
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            tabs: [
              Tab(
                icon: const Icon(Icons.grass, color: Colors.white),
                child: Text(_t['edit_harvest_tab_basic'], style: const TextStyle(color: Colors.white)), // ✅ i18n
              ),
              Tab(
                icon: const Icon(Icons.dry_cleaning, color: Colors.white),
                child: Text(_t['edit_harvest_tab_drying'], style: const TextStyle(color: Colors.white)), // ✅ i18n
              ),
              Tab(
                icon: const Icon(Icons.inventory_2, color: Colors.white),
                child: Text(_t['edit_harvest_tab_curing'], style: const TextStyle(color: Colors.white)), // ✅ i18n
              ),
              Tab(
                icon: const Icon(Icons.science, color: Colors.white),
                child: Text(_t['edit_harvest_tab_quality'], style: const TextStyle(color: Colors.white)), // ✅ i18n
              ),
              Tab(
                icon: const Icon(Icons.star, color: Colors.white),
                child: Text(_t['edit_harvest_tab_rating'], style: const TextStyle(color: Colors.white)), // ✅ i18n
              ),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicTab(),
              _buildDryingTab(),
              _buildCuringTab(),
              _buildQualityTab(),
              _buildRatingTab(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Dunkel für Theme,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : () async {
                  if (await _showDiscardDialog() && mounted) {
                    Navigator.of(context).pop(false);
                  }
                },
                icon: const Icon(Icons.close),
                label: Text(_t['cancel']), // ✅ i18n
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveHarvest,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? _t['edit_harvest_saving'] : _t['save']), // ✅ i18n
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDiscardDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t['edit_harvest_discard_title']), // ✅ i18n
        content: Text(_t['edit_harvest_discard_message']), // ✅ i18n
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t['edit_harvest_continue_editing']), // ✅ i18n
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t['edit_harvest_discard']), // ✅ i18n
          ),
        ],
      ),
    ) ?? false;
  }

  // =============================================
  // TAB 1: BASIC DATA
  // =============================================
  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _t['edit_harvest_basic_header'], // ✅ i18n
            _t['edit_harvest_basic_description'], // ✅ i18n
            Icons.grass,
            Colors.green,
          ),
          const SizedBox(height: 20),

          // Harvest Date
          _buildDateField(
            label: _t['edit_harvest_date_label'], // ✅ i18n
            icon: Icons.calendar_today,
            color: Colors.green,
            currentDate: _harvestDate,
            onDateSelected: (date) => setState(() => _harvestDate = date),
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
          ),
          const SizedBox(height: 20),

          // Wet Weight
          _buildNumberField(
            controller: _wetWeightController,
            label: _t['edit_harvest_wet_weight_label'], // ✅ i18n
            hint: _t['edit_harvest_wet_weight_hint'], // ✅ i18n
            suffix: _t['edit_harvest_wet_weight_suffix'], // ✅ i18n
            icon: Icons.water_drop,
            color: Colors.blue,
            helperText: _t['edit_harvest_wet_weight_helper'], // ✅ i18n
            allowDecimals: true,
          ),
          const SizedBox(height: 16),

          // Dry Weight
          _buildNumberField(
            controller: _dryWeightController,
            label: _t['edit_harvest_dry_weight_label'], // ✅ i18n
            hint: _t['edit_harvest_dry_weight_hint'], // ✅ i18n
            suffix: _t['edit_harvest_wet_weight_suffix'], // ✅ i18n (reusing 'g')
            icon: Icons.scale,
            color: Colors.green,
            helperText: _t['edit_harvest_dry_weight_helper'], // ✅ i18n
            allowDecimals: true,
            isBold: true,
          ),
          const SizedBox(height: 20),
          
          // Weight Loss Info
          if (_wetWeightController.text.isNotEmpty && _dryWeightController.text.isNotEmpty)
            _buildWeightLossInfo(),
        ],
      ),
    );
  }

  Widget _buildWeightLossInfo() {
    final wet = double.tryParse(_wetWeightController.text);
    final dry = double.tryParse(_dryWeightController.text);
    
    if (wet == null || dry == null || wet == 0) return const SizedBox.shrink();
    
    final loss = ((wet - dry) / wet) * 100;
    final lossGrams = wet - dry;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFB3E5FC), // Helles Blau
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1), // Mittelblau
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_down, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t['edit_harvest_weight_loss'], // ✅ i18n
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF01579B), // Dunkelblau
                      ),
                    ),
                    Text(
                      _t['edit_harvest_water_evaporated'], // ✅ i18n
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0277BD),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  '${loss.toStringAsFixed(1)}%',
                  'Prozentual',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  '${lossGrams.toStringAsFixed(1)}g',
                  'Absolut',
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  // TAB 2: DRYING DATA
  // =============================================
  Widget _buildDryingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _t['edit_harvest_drying_header'], // ✅ i18n
            _t['edit_harvest_drying_description'], // ✅ i18n
            Icons.dry_cleaning,
            Colors.orange,
          ),
          const SizedBox(height: 20),

          // Date Range
          _buildDateRangeSection(
            startDate: _dryingStartDate,
            endDate: _dryingEndDate,
            onStartDateSelected: (date) => setState(() => _dryingStartDate = date),
            onEndDateSelected: (date) => setState(() => _dryingEndDate = date),
            onClearStart: () => setState(() => _dryingStartDate = null),
            onClearEnd: () => setState(() => _dryingEndDate = null),
            minStartDate: _harvestDate,
            color: Colors.orange,
          ),
          const SizedBox(height: 20),

          // Method
          _buildTextField(
            controller: _dryingMethodController,
            label: _t['edit_harvest_drying_method_label'], // ✅ i18n
            hint: _t['edit_harvest_drying_method_hint'], // ✅ i18n
            icon: Icons.dry_cleaning,
            color: Colors.orange,
            suggestions: ['Hängend', 'Netz', 'Box', 'Rack'],
          ),
          const SizedBox(height: 16),

          // Environment Conditions
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _dryingTempController,
                  label: _t['temperature_celsius'], // ✅ i18n (reused)
                  hint: _t['edit_harvest_drying_temp_range'], // ✅ i18n
                  suffix: '°C',
                  icon: Icons.thermostat,
                  color: Colors.orange,
                  allowDecimals: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNumberField(
                  controller: _dryingHumidityController,
                  label: _t['humidity_percent'], // ✅ i18n (reused)
                  hint: _t['edit_harvest_drying_humidity_range'], // ✅ i18n
                  suffix: '%',
                  icon: Icons.water_drop,
                  color: Colors.blue,
                  allowDecimals: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Actions
          _buildQuickActionButtons(
            onStart: () => setState(() => _dryingStartDate ??= DateTime.now()),
            onEnd: () => setState(() => _dryingEndDate ??= DateTime.now()),
            startLabel: _t['edit_harvest_start_today'], // ✅ i18n
            endLabel: _t['edit_harvest_end_today'], // ✅ i18n
            startColor: Colors.orange,
            endColor: Colors.green,
          ),
          
          const SizedBox(height: 20),
          _buildTipsCard(
            _t['edit_harvest_drying_tips'], // ✅ i18n
            [
              _t['edit_harvest_drying_duration_typical'], // ✅ i18n
              'Ideale Temperatur: ${_t['edit_harvest_drying_temp_range']}°C', // ✅ i18n
              'Luftfeuchtigkeit: ${_t['edit_harvest_drying_humidity_range']}%', // ✅ i18n
              _t['edit_harvest_drying_darkness'], // ✅ i18n
              _t['edit_harvest_drying_airflow'], // ✅ i18n
            ],
            Icons.lightbulb_outline,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  // =============================================
  // TAB 3: CURING DATA
  // =============================================
  Widget _buildCuringTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _t['edit_harvest_curing_header'], // ✅ i18n
            _t['edit_harvest_curing_description'], // ✅ i18n
            Icons.inventory_2,
            Colors.purple,
          ),
          const SizedBox(height: 20),
          
          // Date Range
          _buildDateRangeSection(
            startDate: _curingStartDate,
            endDate: _curingEndDate,
            onStartDateSelected: (date) => setState(() => _curingStartDate = date),
            onEndDateSelected: (date) => setState(() => _curingEndDate = date),
            onClearStart: () => setState(() => _curingStartDate = null),
            onClearEnd: () => setState(() => _curingEndDate = null),
            minStartDate: _dryingEndDate ?? _harvestDate,
            color: Colors.purple,
          ),
          const SizedBox(height: 20),
          
          // Method
          _buildTextField(
            controller: _curingMethodController,
            label: _t['edit_harvest_curing_method_label'], // ✅ i18n
            hint: _t['edit_harvest_curing_method_hint'], // ✅ i18n
            icon: Icons.inventory_2,
            color: Colors.purple,
            suggestions: ['Glass Jars', 'Grove Bags', 'CVault', 'Vacuum Sealed'],
          ),
          const SizedBox(height: 16),

          // Notes
          _buildTextField(
            controller: _curingNotesController,
            label: _t['edit_harvest_curing_notes_label'], // ✅ i18n
            hint: _t['edit_harvest_curing_notes_hint'], // ✅ i18n
            icon: Icons.note,
            color: Colors.purple,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          
          // Quick Actions
          _buildQuickActionButtons(
            onStart: () => setState(() => _curingStartDate ??= DateTime.now()),
            onEnd: () => setState(() => _curingEndDate ??= DateTime.now()),
            startLabel: _t['edit_harvest_start_today'], // ✅ i18n
            endLabel: _t['edit_harvest_end_today'], // ✅ i18n
            startColor: Colors.purple,
            endColor: Colors.green,
          ),
          
          const SizedBox(height: 20),
          _buildTipsCard(
            _t['edit_harvest_curing_tips'], // ✅ i18n
            [
              _t['edit_harvest_curing_storage'], // ✅ i18n
              _t['edit_harvest_curing_patience'], // ✅ i18n
            ],
            Icons.lightbulb_outline,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  // =============================================
  // TAB 4: QUALITY DATA
  // =============================================
  Widget _buildQualityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _t['edit_harvest_quality_header'], // ✅ i18n
            _t['edit_harvest_cannabinoid_profile'], // ✅ i18n
            Icons.science,
            Colors.blue,
          ),
          const SizedBox(height: 20),
          
          // THC
          _buildNumberField(
            controller: _thcController,
            label: 'THC-Gehalt',
            hint: 'z.B. 22.5',
            suffix: '%',
            icon: Icons.science,
            color: Colors.red,
            helperText: _t['edit_harvest_thc_helper'], // ✅ i18n
            allowDecimals: true,
          ),
          const SizedBox(height: 16),

          // CBD
          _buildNumberField(
            controller: _cbdController,
            label: 'CBD-Gehalt',
            hint: 'z.B. 0.5',
            suffix: '%',
            icon: Icons.science,
            color: Colors.green,
            helperText: _t['edit_harvest_cbd_helper'], // ✅ i18n
            allowDecimals: true,
          ),
          const SizedBox(height: 16),
          
          // Terpene Profile
          _buildTextField(
            controller: _terpeneController,
            label: _t['edit_harvest_terpene_label'], // ✅ i18n
            hint: _t['edit_harvest_terpene_hint'], // ✅ i18n
            icon: Icons.format_list_bulleted,
            color: Colors.purple,
            maxLines: 3,
            suggestions: [
              'Myrcene',
              'Limonene',
              'Caryophyllene',
              'Pinene',
              'Linalool',
              'Humulene',
            ],
          ),
          const SizedBox(height: 20),
          
          // Cannabinoid Preview
          if (_thcController.text.isNotEmpty || _cbdController.text.isNotEmpty)
            _buildCannabinoidPreview(),
          
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200] ?? Colors.blue),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _t['edit_harvest_quality_info'], // ✅ i18n
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[900],
                    ),
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
          colors: [Colors.purple[50] ?? Colors.purple, Colors.blue[50] ?? Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200] ?? Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t['edit_harvest_cannabinoid_profile'], // ✅ i18n
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 12),
          if (thc != null) _buildCannabinoidBar('THC', thc, Colors.red),
          if (cbd != null) ...[
            const SizedBox(height: 12),
            _buildCannabinoidBar('CBD', cbd, Colors.green),
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
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
            value: (percentage / 30).clamp(0.0, 1.0), // Max 30% for visual
            minHeight: 10,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // =============================================
  // TAB 5: RATING & NOTES
  // =============================================
  Widget _buildRatingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            _t['edit_harvest_rating_header'], // ✅ i18n
            _t['edit_harvest_rating_description'], // ✅ i18n
            Icons.star,
            Colors.amber,
          ),
          const SizedBox(height: 20),
          
          // Star Rating
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _t['edit_harvest_overall_rating'], // ✅ i18n
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          (_rating ?? 0) > index ? Icons.star : Icons.star_border,
                          size: 40,
                        ),
                        color: Colors.amber,
                        onPressed: () {
                          setState(() => _rating = index + 1);
                        },
                      );
                    }),
                  ),
                  if (_rating != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _t['edit_harvest_rating_stars'].replaceAll('{rating}', '$_rating'), // ✅ i18n
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_rating == null)
                    Text(
                      _t['edit_harvest_not_set'], // ✅ i18n
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Taste Notes
          _buildTextField(
            controller: _tasteController,
            label: _t['edit_harvest_taste_label'], // ✅ i18n
            hint: _t['edit_harvest_taste_hint'], // ✅ i18n
            icon: Icons.restaurant,
            color: Colors.orange,
            maxLines: 3,
            suggestions: [
              'Fruchtig',
              'Erdig',
              'Zitrusartig',
              'Süß',
              'Würzig',
              'Blumig',
              'Diesel',
              'Kiefer',
            ],
          ),
          const SizedBox(height: 16),

          // Effect Notes
          _buildTextField(
            controller: _effectController,
            label: _t['edit_harvest_effect_label'], // ✅ i18n
            hint: _t['edit_harvest_effect_hint'], // ✅ i18n
            icon: Icons.psychology,
            color: Colors.purple,
            maxLines: 3,
            suggestions: [
              'Entspannend',
              'Euphorisch',
              'Kreativ',
              'Energetisch',
              'Fokussiert',
              'Schläfrig',
              'Gesellig',
              'Appetitanregend',
            ],
          ),
          const SizedBox(height: 16),
          
          // Overall Notes
          _buildTextField(
            controller: _overallNotesController,
            label: _t['notes'], // ✅ i18n (reused)
            hint: _t['edit_harvest_notes_hint'], // ✅ i18n
            icon: Icons.note,
            color: Colors.blue,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  // =============================================
  // REUSABLE WIDGETS
  // =============================================
  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required IconData icon,
    required Color color,
    required DateTime currentDate,
    required Function(DateTime) onDateSelected,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: currentDate,
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (date != null) onDateSelected(date);
      },
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
                    DateFormat('dd.MM.yyyy').format(currentDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSection({
    required DateTime? startDate,
    required DateTime? endDate,
    required Function(DateTime) onStartDateSelected,
    required Function(DateTime) onEndDateSelected,
    required VoidCallback onClearStart,
    required VoidCallback onClearEnd,
    required DateTime minStartDate,
    required Color color,
  }) {
    final duration = startDate != null && endDate != null
        ? endDate.difference(startDate).inDays
        : null;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateButton(
                label: 'Start-Datum',
                date: startDate,
                icon: Icons.play_arrow,
                color: color,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: minStartDate,
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (date != null) onStartDateSelected(date);
                },
                onClear: startDate != null ? onClearStart : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDateButton(
                label: 'End-Datum',
                date: endDate,
                icon: Icons.stop,
                color: Colors.green,
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: endDate ?? DateTime.now(),
                    firstDate: startDate ?? minStartDate,
                    lastDate: DateTime.now().add(const Duration(days: 120)),
                  );
                  if (date != null) onEndDateSelected(date);
                },
                onClear: endDate != null ? onClearEnd : null,
              ),
            ),
          ],
        ),
        if (duration != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Dauer: $duration Tage',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateButton({
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300] ?? Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                if (onClear != null)
                  InkWell(
                    onTap: onClear,
                    child: Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              date != null ? DateFormat('dd.MM.yyyy').format(date) : _t['edit_harvest_not_set'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                color: date != null ? Colors.black : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String suffix,
    required IconData icon,
    required Color color,
    String? helperText,
    bool allowDecimals = false,
    bool isBold = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
        hintText: hint,
        suffixText: suffix,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        helperText: helperText,
        helperMaxLines: 2,
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          if (double.tryParse(value) == null) {
            return _t['error_invalid_number'];
          }
        }
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    int maxLines = 1,
    List<String>? suggestions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: color),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: color, width: 2),
            ),
          ),
          maxLines: maxLines,
        ),
        if (suggestions != null && suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((suggestion) {
              return InkWell(
                onTap: () {
                  final current = controller.text;
                  if (current.isEmpty) {
                    controller.text = suggestion;
                  } else if (!current.contains(suggestion)) {
                    controller.text = '$current, $suggestion';
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickActionButtons({
    required VoidCallback onStart,
    required VoidCallback onEnd,
    required String startLabel,
    required String endLabel,
    required Color startColor,
    required Color endColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text(startLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: startColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEnd,
            icon: const Icon(Icons.stop),
            label: Text(endLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: endColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard(String title, List<String> tips, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
