// =============================================
// GROWLOG - RoomRepository Interface
// =============================================

import '../../models/room.dart';

abstract class IRoomRepository {
  Future<List<Room>> findAll();
  Future<Room?> findById(int id);
  Future<Room> save(Room room);
  Future<bool> isInUse(int id);
  Future<Map<String, int>> getUsageDetails(int id);
  Future<int> delete(int id);
  Future<int> count();
}
