// =============================================
// GROWLOG - Edit Grow Screen
// =============================================

import 'package:flutter/material.dart';
import '../models/grow.dart';
import '../models/room.dart';
import '../repositories/interfaces/i_grow_repository.dart';
import '../repositories/interfaces/i_room_repository.dart';
import '../utils/validators.dart';
import '../utils/app_messages.dart';
import '../utils/mounted_state_mixin.dart'; // ✅ FIX: Added for safe setState
import '../di/service_locator.dart';

class EditGrowScreen extends StatefulWidget {
  final Grow grow;

  const EditGrowScreen({super.key, required this.grow});

  @override
  State<EditGrowScreen> createState() => _EditGrowScreenState();
}

// ✅ FIX: Added MountedStateMixin to prevent setState after dispose
class _EditGrowScreenState extends State<EditGrowScreen> with MountedStateMixin {
  final _formKey = GlobalKey<FormState>();
  final IGrowRepository _growRepo = getIt<IGrowRepository>();
  final IRoomRepository _roomRepo = getIt<IRoomRepository>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  late DateTime _startDate;
  int? _selectedRoomId;
  List<Room> _rooms = [];
  bool _isLoading = false;
  bool _loadingRooms = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.grow.name);
    _descriptionController = TextEditingController(text: widget.grow.description ?? '');
    _startDate = widget.grow.startDate;
    _selectedRoomId = widget.grow.roomId;
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
      if (mounted) {
        setState(() => _loadingRooms = false);
        AppMessages.loadingError(context, 'Räume', onRetry: _loadRooms);
      }
    }
  }

  Future<void> _saveGrow() async {
    if (!_formKey.currentState!.validate()) return;

    safeSetState(() => _isLoading = true);

    try {
      final updatedGrow = widget.grow.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        startDate: _startDate,
        roomId: _selectedRoomId,
      );

      await _growRepo.update(updatedGrow);

      if (mounted) {
        Navigator.of(context).pop(true);
        AppMessages.showSuccess(context, 'Grow aktualisiert! 🌱');
      }
    } catch (e) {
      if (mounted) {
        AppMessages.savingError(context, e.toString());
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grow bearbeiten'),
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
          ),
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
          ),
          maxLines: 3,
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

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _saveGrow,
      icon: const Icon(Icons.save),
      label: const Text('Änderungen speichern'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
