// =============================================
// GROWLOG - Edit Harvest Quality Control Screen
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../models/harvest.dart';
import '../repositories/interfaces/i_harvest_repository.dart';
import '../di/service_locator.dart';

class EditHarvestQualityScreen extends StatefulWidget {
  final Harvest harvest;

  const EditHarvestQualityScreen({super.key, required this.harvest});

  @override
  State<EditHarvestQualityScreen> createState() => _EditHarvestQualityScreenState();
}

class _EditHarvestQualityScreenState extends State<EditHarvestQualityScreen> with SingleTickerProviderStateMixin {
  final IHarvestRepository _harvestRepo = getIt<IHarvestRepository>();
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
        terpeneProfile: _terpeneController.text.isNotEmpty ? _terpeneController.text : null,
        rating: _rating,
        tasteNotes: _tasteController.text.isNotEmpty ? _tasteController.text : null,
        effectNotes: _effectController.text.isNotEmpty ? _effectController.text : null,
        overallNotes: _overallNotesController.text.isNotEmpty ? _overallNotesController.text : null,
        updatedAt: DateTime.now(),
      );

      await _harvestRepo.updateHarvest(updated);

      if (mounted) {
        Navigator.pop(context, true);
        AppMessages.showSuccess(context, 'Quality-Daten aktualisiert! ✅');
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
        title: const Text('Quality Control bearbeiten'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.science, color: Colors.white),
              child: Text('Qualität', style: TextStyle(color: Colors.white)),
            ),
            Tab(
              icon: Icon(Icons.star, color: Colors.white),
              child: Text('Bewertung', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildQualityTab(),
            _buildRatingTab(),
          ],
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Speichert...' : 'Speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
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
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200] ?? Colors.blue),
            ),
            child: Row(
              children: [
                Icon(Icons.science, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Cannabinoid-Profil',
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
          
          // THC
          TextFormField(
            controller: _thcController,
            decoration: InputDecoration(
              labelText: 'THC-Gehalt',
              hintText: 'z.B. 22.5',
              suffixText: '%',
              prefixIcon: const Icon(Icons.science, color: Colors.red),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Tetrahydrocannabinol',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          
          // CBD
          TextFormField(
            controller: _cbdController,
            decoration: InputDecoration(
              labelText: 'CBD-Gehalt',
              hintText: 'z.B. 0.5',
              suffixText: '%',
              prefixIcon: const Icon(Icons.science, color: Colors.green),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Cannabidiol',
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
              labelText: 'Terpen-Profil',
              hintText: 'z.B. Myrcene, Limonene, Caryophyllene',
              prefixIcon: const Icon(Icons.format_list_bulleted, color: Colors.purple),
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
            children: [
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
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200] ?? Colors.blue),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Laboranalysen sind optional, können aber wertvolle Informationen über die Qualität deiner Ernte liefern.',
                    style: TextStyle(fontSize: 13),
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
            'Cannabinoid-Profil Vorschau',
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
            value: (percentage / 30).clamp(0.0, 1.0),
            minHeight: 10,
            backgroundColor: Colors.grey[300],
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
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200] ?? Colors.amber),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber[700]),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Bewertung & Notizen',
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
          
          // Star Rating
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'Gesamt-Bewertung',
                    style: TextStyle(
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
                      '$_rating / 5 Sterne',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (_rating == null)
                    Text(
                      'Tippe auf die Sterne zum Bewerten',
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
          TextFormField(
            controller: _tasteController,
            decoration: InputDecoration(
              labelText: 'Geschmack',
              hintText: 'z.B. fruchtig, erdig, zitrusartig...',
              prefixIcon: const Icon(Icons.restaurant, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
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
              labelText: 'Wirkung',
              hintText: 'z.B. entspannend, euphorisch, kreativ...',
              prefixIcon: const Icon(Icons.psychology, color: Colors.purple),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
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
              labelText: 'Allgemeine Notizen',
              hintText: 'Zusätzliche Beobachtungen, Besonderheiten...',
              prefixIcon: const Icon(Icons.note, color: Colors.blue),
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
