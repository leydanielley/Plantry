// =============================================
// GROWLOG - RoomRepository Interface
// =============================================

import '../../models/room.dart';

abstract class IRoomRepository {
  Future<List<Room>> findAll();
  Future<Room?> findById(int id);
  Future<Room> save(Room room);
  Future<int> delete(int id);
  Future<int> count();
}
