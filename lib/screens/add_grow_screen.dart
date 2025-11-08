// =============================================
// GROWLOG - Add Grow Screen (✅ MIT VALIDATORS!)
// =============================================

import 'package:flutter/material.dart';
import '../models/grow.dart';
import '../models/room.dart';
import '../repositories/grow_repository.dart';
import '../repositories/room_repository.dart';
import '../utils/validators.dart';
import '../utils/app_messages.dart';

class AddGrowScreen extends StatefulWidget {
  const AddGrowScreen({super.key});

  @override
  State<AddGrowScreen> createState() => _AddGrowScreenState();
}

class _AddGrowScreenState extends State<AddGrowScreen> {
  final _formKey = GlobalKey<FormState>();
  final GrowRepository _growRepo = GrowRepository();
  final RoomRepository _roomRepo = RoomRepository();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  DateTime _startDate = DateTime.now();
  int? _selectedRoomId;
  List<Room> _rooms = [];
  bool _isLoading = false;
  bool _loadingRooms = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: 'Grow ${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}',
    );
    _descriptionController = TextEditingController();
    _loadRooms();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _roomRepo.findAll();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loadingRooms = false;
        });
      }
    } catch (e) {
      // Error loading rooms: $e
      if (mounted) {
        setState(() => _loadingRooms = false);
        AppMessages.loadingError(context, 'Räume', onRetry: _loadRooms);
      }
    }
  }

  Future<void> _saveGrow() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final grow = Grow(
        name: _nameController.text.trim(),  // ✅ Trim hinzugefügt
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        startDate: _startDate,
        roomId: _selectedRoomId,
      );

      await _growRepo.create(grow);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.growCreated(context);
      }
    } catch (e) {
      // Error: $e
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Neuer Grow'),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBasicInfo(),
                  const SizedBox(height: 24),
                  _buildRoomSelection(),
                  const SizedBox(height: 24),
                  _buildDatePicker(),
                  const SizedBox(height: 24),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grow Informationen',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Name *',
            prefixIcon: Icon(Icons.eco, color: Colors.green[700]),
            border: const OutlineInputBorder(),
            helperText: 'z.B. "Grow 2025-10" oder "Winter Grow"',
          ),
          // ✅ FIX BUG #3: Validator hinzugefügt!
          validator: (value) => Validators.validateNotEmpty(value, fieldName: 'Name'),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Beschreibung (optional)',
            prefixIcon: Icon(Icons.description, color: Colors.grey[600]),
            border: const OutlineInputBorder(),
            helperText: 'z.B. "5x Wedding Cake + 3x Northern Lights"',
          ),
          maxLines: 3,
          // Beschreibung ist optional, kein Validator nötig
        ),
      ],
    );
  }

  Widget _buildRoomSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Raum',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingRooms)
          const Center(child: CircularProgressIndicator())
        else
          DropdownButtonFormField<int?>(
            initialValue: _selectedRoomId,
            decoration: InputDecoration(
              labelText: 'Raum (optional)',
              prefixIcon: Icon(Icons.home, color: Colors.grey[700]),
              border: const OutlineInputBorder(),
              helperText: 'In welchem Raum findet dieser Grow statt?',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Kein Raum')),
              ..._rooms.map((room) {
                return DropdownMenuItem(
                  value: room.id,
                  child: Text(room.name),
                );
              }),
            ],
            onChanged: (value) => setState(() => _selectedRoomId = value),
          ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Start-Datum',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.calendar_today, color: Colors.green[700]),
          title: Text(
            '${_startDate.day}.${_startDate.month}.${_startDate.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          subtitle: const Text('Wann hast du mit diesem Grow begonnen?'),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _startDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _startDate = date);
            }
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Was ist ein Grow?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ein Grow ist eine Gruppierung für mehrere Pflanzen. '
              'Du kannst mehrere Pflanzen einem Grow zuordnen, um sie gemeinsam zu verwalten und zu tracken.',
              style: TextStyle(color: Colors.grey[800]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saveGrow,
      icon: const Icon(Icons.add),
      label: const Text('Grow erstellen'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
