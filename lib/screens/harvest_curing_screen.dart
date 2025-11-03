// =============================================
// GROWLOG - Harvest Curing Screen (View Mode)
// =============================================

import 'package:flutter/material.dart';
import '../utils/app_messages.dart';
import 'package:intl/intl.dart';
import '../models/harvest.dart';
import '../repositories/harvest_repository.dart';
import 'edit_harvest_curing_screen.dart';
import 'harvest_quality_screen.dart';

class HarvestCuringScreen extends StatefulWidget {
  final int harvestId;

  const HarvestCuringScreen({super.key, required this.harvestId});

  @override
  State<HarvestCuringScreen> createState() => _HarvestCuringScreenState();
}

class _HarvestCuringScreenState extends State<HarvestCuringScreen> {
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

  Future<void> _startCuring() async {
    if (_harvest == null) return;

    // ✅ Zeige Dialog zum Erfassen der Curing-Methode beim START
    final result = await _showStartCuringDialog();
    if (result == null) return; // User hat abgebrochen

    try {
      final updated = _harvest!.copyWith(
        curingStartDate: result['startDate'] as DateTime,
        curingMethod: result['method'] as String?,
        curingNotes: result['notes'] as String?,
        updatedAt: DateTime.now(),
      );
      await _harvestRepo.updateHarvest(updated);
      _loadHarvest();
      
      if (mounted) {
        AppMessages.showSuccess(context, 'Curing gestartet! 📦');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 
'Fehler: $e');
      }
    }
  }

  Future<Map<String, dynamic>?> _showStartCuringDialog() async {
    final TextEditingController methodController = TextEditingController(
      text: _harvest!.curingMethod ?? 'Glass Jars',
    );
    final TextEditingController notesController = TextEditingController(
      text: _harvest!.curingNotes ?? '',
    );
    DateTime selectedStartDate = DateTime.now();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.purple[700]),
                const SizedBox(width: 12),
                const Text('Curing starten'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Start Date Picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedStartDate,
                        firstDate: _harvest!.dryingEndDate ?? _harvest!.harvestDate,
                        lastDate: DateTime.now().add(const Duration(days: 7)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedStartDate = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Curing-Start',
                        prefixIcon: Icon(Icons.calendar_today, color: Colors.purple),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        DateFormat('dd.MM.yyyy').format(selectedStartDate),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Method
                  TextFormField(
                    controller: methodController,
                    decoration: InputDecoration(
                      labelText: 'Curing-Methode',
                      hintText: 'z.B. Glass Jars, Grove Bags',
                      prefixIcon: Icon(Icons.dashboard, color: Colors.purple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Method Suggestion Chips
                  Wrap(
                    spacing: 8,
                    children: ['Glass Jars', 'Grove Bags', 'CVault', 'Vacuum Sealed']
                        .map((method) => ActionChip(
                              label: Text(method, style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                methodController.text = method;
                                setDialogState(() {});
                              },
                              backgroundColor: methodController.text == method
                                  ? Colors.purple[100]
                                  : null,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notizen (optional)',
                      hintText: 'Burping Schedule, Besonderheiten...',
                      prefixIcon: Icon(Icons.note, color: Colors.purple),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, {
                    'startDate': selectedStartDate,
                    'method': methodController.text.isNotEmpty ? methodController.text : null,
                    'notes': notesController.text.isNotEmpty ? notesController.text : null,
                  });
                },
                icon: const Icon(Icons.check),
                label: const Text('Starten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _endCuring() async {
    if (_harvest == null) return;

    // ✅ Einfach mit heutigem Datum beenden, keine Abfrage
    try {
      final updated = _harvest!.copyWith(
        curingEndDate: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _harvestRepo.updateHarvest(updated);
      _loadHarvest();
      
      if (mounted) {
        AppMessages.showSuccess(context, 'Curing abgeschlossen! 🎉');
      }
    } catch (e) {
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
          title: const Text('Curing'),
          backgroundColor: Colors.purple[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_harvest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Curing'),
          backgroundColor: Colors.purple[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Ernte nicht gefunden')),
      );
    }

    final hasStarted = _harvest!.curingStartDate != null;
    final hasEnded = _harvest!.curingEndDate != null;
    final isActive = hasStarted && !hasEnded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Curing'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        actions: [
          if (hasStarted)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditHarvestCuringScreen(harvest: _harvest!),
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
            _buildStatusCard(hasStarted, hasEnded, isActive),
            const SizedBox(height: 20),
            
            if (hasStarted) ...[
              _buildDataCard(),
              const SizedBox(height: 20),
            ],
            
            if (!hasStarted)
              _buildStartButton()
            else if (isActive)
              _buildEndButton(),
            
            if (hasEnded) ...[
              const SizedBox(height: 20),
              _buildNextStepButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool hasStarted, bool hasEnded, bool isActive) {
    Color color;
    IconData icon;
    String status;
    String subtitle;

    if (hasEnded) {
      color = Colors.green;
      icon = Icons.check_circle;
      status = 'Abgeschlossen';
      subtitle = 'Curing erfolgreich beendet';
    } else if (isActive) {
      color = Colors.purple;
      icon = Icons.inventory_2;
      status = 'In Curing';
      subtitle = 'Laufender Fermentations-Prozess';
    } else {
      color = Colors.grey;
      icon = Icons.schedule;
      status = 'Nicht gestartet';
      subtitle = 'Bereit zum Start';
    }

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

  Widget _buildDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.purple[700]),
                const SizedBox(width: 8),
                const Text(
                  'Curing-Daten',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 20),
            
            if (_harvest!.curingStartDate != null)
              _buildInfoRow(
                'Start',
                DateFormat('dd.MM.yyyy').format(_harvest!.curingStartDate!),
                Icons.play_arrow,
                Colors.purple,
              ),
            
            if (_harvest!.curingEndDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Ende',
                DateFormat('dd.MM.yyyy').format(_harvest!.curingEndDate!),
                Icons.stop,
                Colors.green,
              ),
            ],
            
            if (_harvest!.calculatedCuringDays != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Dauer',
                '${_harvest!.calculatedCuringDays} Tage',
                Icons.timer,
                Colors.blue,
                highlight: true,
              ),
            ],
            
            if (_harvest!.curingMethod != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Methode',
                _harvest!.curingMethod!,
                Icons.dashboard,
                Colors.purple,
              ),
            ],
            
            if (_harvest!.curingNotes != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Notizen',
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
                child: Text(_harvest!.curingNotes!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, Color color, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            fontSize: highlight ? 18 : 16,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _startCuring,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Curing jetzt starten'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildEndButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _endCuring,
        icon: const Icon(Icons.stop),
        label: const Text('Curing beenden'),
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

  Widget _buildNextStepButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HarvestQualityScreen(harvestId: widget.harvestId),
            ),
          );
          _loadHarvest();
        },
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Weiter zur Quality Control'),
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
}
