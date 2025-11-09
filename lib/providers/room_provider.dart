// =============================================
// GROWLOG - Room Provider (State Management)
// =============================================

import 'package:flutter/foundation.dart';
import '../models/room.dart';
import '../repositories/interfaces/i_room_repository.dart';
import '../utils/app_logger.dart';
import '../utils/async_value.dart';

/// Provider for managing room state across the app
///
/// Usage:
/// ```dart
/// // In main.dart, add to MultiProvider:
/// ChangeNotifierProvider(
///   create: (_) => RoomProvider(getIt<RoomRepository>()),
///   child: MaterialApp(...),
/// )
///
/// // In screens:
/// final provider = context.watch<RoomProvider>();
/// final rooms = provider.rooms;
///
/// // Or with Consumer:
/// Consumer<RoomProvider>(
///   builder: (context, provider, child) {
///     return switch (provider.rooms) {
///       Loading() => CircularProgressIndicator(),
///       Success(:final data) => RoomList(data),
///       Error(:final message) => ErrorView(message),
///     };
///   },
/// )
/// ```
class RoomProvider with ChangeNotifier {
  final IRoomRepository _repository;

  RoomProvider(this._repository);

  // ═══════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════

  /// List of all rooms
  AsyncValue<List<Room>> _rooms = const Loading();

  /// Currently selected/viewed room
  AsyncValue<Room> _currentRoom = const Loading();

  // ═══════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════

  AsyncValue<List<Room>> get rooms => _rooms;
  AsyncValue<Room> get currentRoom => _currentRoom;

  // ═══════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════

  /// Load all rooms
  Future<void> loadRooms() async {
    AppLogger.debug('RoomProvider', 'Loading rooms');

    _rooms = const Loading();
    notifyListeners();

    try {
      final roomList = await _repository.findAll();
      _rooms = Success(roomList);
      AppLogger.info('RoomProvider', 'Loaded ${roomList.length} rooms');
    } catch (e, stack) {
      _rooms = Error('Failed to load rooms', e, stack);
      AppLogger.error('RoomProvider', 'Failed to load rooms', e, stack);
    }

    notifyListeners();
  }

  /// Load a single room by ID
  Future<void> loadRoom(int id) async {
    AppLogger.debug('RoomProvider', 'Loading room', id);

    _currentRoom = const Loading();
    notifyListeners();

    try {
      final room = await _repository.findById(id);
      if (room == null) {
        _currentRoom = Error('Room not found with ID: $id');
      } else {
        _currentRoom = Success(room);
        AppLogger.info('RoomProvider', 'Loaded room', room.name);
      }
    } catch (e, stack) {
      _currentRoom = Error('Failed to load room', e, stack);
      AppLogger.error('RoomProvider', 'Failed to load room', e, stack);
    }

    notifyListeners();
  }

  /// Save a room (create or update)
  Future<bool> saveRoom(Room room) async {
    AppLogger.debug('RoomProvider', 'Saving room', room.name);

    try {
      final savedRoom = await _repository.save(room);

      // Update current room if it's the same one
      if (_currentRoom case Success(:final data)) {
        if (data.id == savedRoom.id) {
          _currentRoom = Success(savedRoom);
        }
      }

      // Reload rooms list to reflect changes
      await loadRooms();

      AppLogger.info('RoomProvider', '✅ Room saved', savedRoom.name);
      return true;
    } catch (e, stack) {
      AppLogger.error('RoomProvider', 'Failed to save room', e, stack);
      return false;
    }
  }

  /// Delete a room
  Future<bool> deleteRoom(int id) async {
    AppLogger.debug('RoomProvider', 'Deleting room', id);

    try {
      await _repository.delete(id);

      // Clear current room if it was deleted
      if (_currentRoom case Success(:final data)) {
        if (data.id == id) {
          _currentRoom = const Loading();
        }
      }

      // Reload rooms list
      await loadRooms();

      AppLogger.info('RoomProvider', '✅ Room deleted', id);
      return true;
    } catch (e, stack) {
      AppLogger.error('RoomProvider', 'Failed to delete room', e, stack);
      return false;
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    AppLogger.debug('RoomProvider', 'Refreshing all room data');
    await loadRooms();
  }

  /// Clear current room selection
  void clearCurrentRoom() {
    _currentRoom = const Loading();
    notifyListeners();
  }

  /// Get room count
  Future<int> getRoomCount() async {
    try {
      return await _repository.count();
    } catch (e) {
      AppLogger.error('RoomProvider', 'Failed to get room count', e);
      return 0;
    }
  }
}
