// =============================================
// GROWLOG - Grow Detail Screen (MIT MASSEN-LOG)
// =============================================

import 'package:flutter/material.dart';

import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../models/grow.dart';
import '../models/plant.dart';
import '../models/enums.dart';
import '../repositories/interfaces/i_plant_repository.dart';
import 'plant_detail_screen.dart';
import 'add_log_screen.dart';
import 'add_plant_screen.dart';
import '../di/service_locator.dart';

class GrowDetailScreen extends StatefulWidget {
  final Grow grow;

  const GrowDetailScreen({super.key, required this.grow});

  @override
  State<GrowDetailScreen> createState() => _GrowDetailScreenState();
}

class _GrowDetailScreenState extends State<GrowDetailScreen> {
  final IPlantRepository _plantRepo = getIt<IPlantRepository>();
  List<Plant> _plants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    // ✅ FIX: Add mounted check before setState
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final allPlants = await _plantRepo.findAll();
      AppLogger.debug('GrowDetailScreen', 'Total plants in DB: ${allPlants.length}');
      AppLogger.debug('GrowDetailScreen', 'Looking for plants with growId: ${widget.grow.id}');

      for (var plant in allPlants) {
        AppLogger.debug('GrowDetailScreen', 'Plant "${plant.name}" has growId: ${plant.growId}');
      }

      final growPlants = allPlants.where((p) => p.growId == widget.grow.id).toList();
      AppLogger.info('GrowDetailScreen', 'Found ${growPlants.length} plants for this grow');

      if (mounted) {
        setState(() {
          _plants = growPlants;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('GrowDetailScreen', 'Error loading plants: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddPlantOptions() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pflanze hinzufügen'),
        content: const Text('Möchtest du eine neue Pflanze erstellen oder eine vorhandene Pflanze diesem Grow zuweisen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('existing'),
            child: const Text('Vorhandene zuweisen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('new'),
            child: const Text('Neue erstellen'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == 'new' && mounted) {
      // Neue Pflanze erstellen
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddPlantScreen(
            preselectedGrowId: widget.grow.id,
          ),
        ),
      );
      if (result == true && mounted) _loadPlants();
    } else if (choice == 'existing' && mounted) {
      // Vorhandene Pflanze zuweisen
      await _showAssignExistingPlant();
    }
  }

  Future<void> _showAssignExistingPlant() async {
    // Lade alle Pflanzen die NICHT in diesem Grow sind
    final allPlants = await _plantRepo.findAll();
    final availablePlants = allPlants.where((p) => p.growId != widget.grow.id).toList();

    if (availablePlants.isEmpty) {
      if (mounted) {
        AppMessages.showSuccess(context, 'Keine vorhandenen Pflanzen verfügbar. Erstelle erst eine neue Pflanze!');
      }
      return;
    }

    if (!mounted) return;

    final selectedPlant = await showDialog<Plant>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: const Text('Pflanze auswählen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availablePlants.length,
              itemBuilder: (context, index) {
                final plant = availablePlants[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getPhaseEmoji(plant.phase),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  title: Text(plant.name),
                  subtitle: Text('${plant.strain ?? 'Unknown'} • Tag ${plant.totalDays}'),
                  onTap: () => Navigator.of(context).pop(plant),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ],
        );
      },
    );

    if (selectedPlant == null) return;

    // Pflanze diesem Grow zuweisen
    try {
      final updatedPlant = selectedPlant.copyWith(growId: widget.grow.id);
      await _plantRepo.save(updatedPlant);
      _loadPlants();
      
      if (mounted) {
        AppMessages.showSuccess(context, '${selectedPlant.name} wurde dem Grow hinzugefügt! 🌱');
      }
    } catch (e) {
      AppLogger.error('GrowDetailScreen', 'Error assigning plant: $e');
      if (mounted) {
        AppMessages.showError(context, 'Fehler: $e');
      }
    }
  }

  Future<void> _bulkLog() async {
    if (_plants.isEmpty) {
      AppMessages.showSuccess(context, 'Keine Pflanzen in diesem Grow! Füge erst Pflanzen hinzu.');
      return;
    }

    // Navigation zum AddLogScreen mit erster Pflanze
    // Der Screen wird angepasst um ALLE Pflanzen gleichzeitig zu loggen
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddLogScreen(
          plant: _plants.first,
          bulkMode: true,
          bulkPlantIds: _plants.map((p) => p.id!).toList(),
        ),
      ),
    );

    if (result == true) {
      _loadPlants();
      if (mounted) {
        AppMessages.showSuccess(context, '${_plants.length} Pflanzen geloggt! 📝');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.grow.name),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: _plants.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _showAddPlantOptions,
              backgroundColor: Colors.green[700],
              icon: const Icon(Icons.add),
              label: const Text('Pflanze hinzufügen'),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'add_plant',
                  onPressed: _showAddPlantOptions,
                  backgroundColor: Colors.green[700],
                  icon: const Icon(Icons.add),
                  label: const Text('Pflanze'),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'mass_log',
                  onPressed: _bulkLog,
                  backgroundColor: Colors.blue[700],
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Massen-Log'),
                ),
              ],
            ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Grow Info Card
        _buildGrowInfoCard(),
        
        // Pflanzen Liste
        Expanded(
          child: _plants.isEmpty
              ? _buildEmptyState()
              : _buildPlantList(),
        ),
      ],
    );
  }

  Widget _buildGrowInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            children: [
            Icon(Icons.eco, size: 24, color: Colors.green[700]),
            const SizedBox(width: 12),
            Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
                widget.grow.name,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                ),
              Text(
                widget.grow.status,
              style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            ),
            ],
            ),
            ),
            ],
            ),
            if (widget.grow.description != null && widget.grow.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.grow.description!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(Icons.calendar_today, 'Tag ${widget.grow.totalDays}'),
                _buildInfoItem(Icons.spa, '${_plants.length} Pflanze${_plants.length == 1 ? '' : 'n'}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.spa,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Keine Pflanzen in diesem Grow',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge Pflanzen zu diesem Grow hinzu!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tipp: Beim Erstellen einer Pflanze kannst\ndu sie einem Grow zuweisen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantList() {
    return ListView.builder(
      itemCount: _plants.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final plant = _plants[index];
        return _buildPlantCard(plant);
      },
    );
  }

  Widget _buildPlantCard(Plant plant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // ✅ PERFORMANCE: RepaintBoundary isoliert jede Card für flüssigeres Scrolling
    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _getPhaseEmoji(plant.phase),
            style: const TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          plant.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${plant.strain ?? 'Unknown'} • Tag ${plant.totalDays}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PlantDetailScreen(plant: plant),
            ),
          );
          if (result == true) _loadPlants();
        },
      ),
      ),
    );
  }

  String _getPhaseEmoji(PlantPhase phase) {
    switch (phase) {
      case PlantPhase.seedling:
        return '🌱';
      case PlantPhase.veg:
        return '🌿';
      case PlantPhase.bloom:
        return '🌸';
      case PlantPhase.harvest:
        return '✂️';
      case PlantPhase.archived:
        return '📦';
    }
  }
}
