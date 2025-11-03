// =============================================
// GROWLOG - Harvest Quality Control Screen (View Mode)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import '../models/harvest.dart';
import '../repositories/harvest_repository.dart';
import 'edit_harvest_quality_screen.dart';

class HarvestQualityScreen extends StatefulWidget {
  final int harvestId;

  const HarvestQualityScreen({super.key, required this.harvestId});

  @override
  State<HarvestQualityScreen> createState() => _HarvestQualityScreenState();
}

class _HarvestQualityScreenState extends State<HarvestQualityScreen> {
  final HarvestRepository _harvestRepo = HarvestRepository();
  Harvest? _harvest;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHarvest();
  }

  Future<void> _loadHarvest() async {
    setState(() => _isLoading = true);
    try {
      final harvest = await _harvestRepo.getHarvestById(widget.harvestId);
      setState(() {
        _harvest = harvest;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppMessages.showError(context, 
'Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quality Control'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_harvest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quality Control'),
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Ernte nicht gefunden')),
      );
    }

    final hasQualityData = _harvest!.thcPercentage != null || 
                           _harvest!.cbdPercentage != null ||
                           _harvest!.terpeneProfile != null;
    
    final hasRatingData = _harvest!.rating != null ||
                          _harvest!.tasteNotes != null ||
                          _harvest!.effectNotes != null ||
                          _harvest!.overallNotes != null;

    final isComplete = hasQualityData || hasRatingData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quality Control'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditHarvestQualityScreen(harvest: _harvest!),
                ),
              );
              if (result == true) _loadHarvest();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(isComplete),
            const SizedBox(height: 20),
            
            if (hasQualityData) ...[
              _buildQualityCard(),
              const SizedBox(height: 20),
            ],
            
            if (hasRatingData) ...[
              _buildRatingCard(),
              const SizedBox(height: 20),
            ],
            
            if (!isComplete)
              _buildAddDataButton(),
            
            if (_harvest!.isComplete) ...[
              const SizedBox(height: 20),
              _buildFinishButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isComplete) {
    Color color = isComplete ? Colors.green : Colors.grey;
    IconData icon = isComplete ? Icons.check_circle : Icons.pending;
    String status = isComplete ? 'Daten erfasst' : 'Offen';
    String subtitle = isComplete 
        ? 'Quality-Daten wurden erfasst'
        : 'Noch keine Daten erfasst';

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Cannabinoid-Profil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            
            if (_harvest!.thcPercentage != null) ...[
              _buildCannabinoidBar('THC', _harvest!.thcPercentage!, Colors.red),
              const SizedBox(height: 16),
            ],
            
            if (_harvest!.cbdPercentage != null) ...[
              _buildCannabinoidBar('CBD', _harvest!.cbdPercentage!, Colors.green),
              const SizedBox(height: 16),
            ],
            
            if (_harvest!.terpeneProfile != null) ...[
              const Text(
                'Terpen-Profil',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: Text(_harvest!.terpeneProfile!),
              ),
            ],
          ],
        ),
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
                fontSize: 16,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (percentage / 30).clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber[700]),
                const SizedBox(width: 8),
                const Text(
                  'Bewertung & Notizen',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            
            if (_harvest!.rating != null) ...[
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < _harvest!.rating! ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 28,
                    );
                  }),
                  const SizedBox(width: 12),
                  Text(
                    '${_harvest!.rating}/5',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            
            if (_harvest!.tasteNotes != null) ...[
              _buildNoteSection('Geschmack', _harvest!.tasteNotes!, Icons.restaurant, Colors.orange),
              const SizedBox(height: 12),
            ],
            
            if (_harvest!.effectNotes != null) ...[
              _buildNoteSection('Wirkung', _harvest!.effectNotes!, Icons.psychology, Colors.purple),
              const SizedBox(height: 12),
            ],
            
            if (_harvest!.overallNotes != null) ...[
              _buildNoteSection('Gesamt-Notizen', _harvest!.overallNotes!, Icons.note, Colors.blue),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoteSection(String label, String text, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          width: double.infinity,
          child: Text(text),
        ),
      ],
    );
  }

  Widget _buildAddDataButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditHarvestQualityScreen(harvest: _harvest!),
            ),
          );
          if (result == true) _loadHarvest();
        },
        icon: const Icon(Icons.add),
        label: const Text('Quality-Daten erfassen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.popUntil(context, (route) => route.isFirst);
        },
        icon: const Icon(Icons.check_circle),
        label: const Text('Ernte abschließen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
