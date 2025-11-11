// =============================================
// GROWLOG - HardwareRepository Interface
// =============================================

import 'package:growlog_app/models/hardware.dart';

abstract class IHardwareRepository {
  Future<List<Hardware>> findByRoom(int roomId);
  Future<List<Hardware>> findActiveByRoom(int roomId);
  Future<Hardware?> findById(int id);
  Future<List<Hardware>> findAll();
  Future<Hardware> save(Hardware hardware);
  Future<int> delete(int id);
  Future<int> deactivate(int id);
  Future<int> activate(int id);
  Future<int> countByRoom(int roomId);
  Future<int> getTotalWattageByRoom(int roomId);
}
