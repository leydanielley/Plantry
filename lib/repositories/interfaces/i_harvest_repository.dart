// =============================================
// GROWLOG - HarvestRepository Interface
// =============================================

import 'package:growlog_app/models/harvest.dart';

abstract class IHarvestRepository {
  Future<int> createHarvest(Harvest harvest);
  Future<int> updateHarvest(Harvest harvest);
  Future<int> deleteHarvest(int id);
  Future<Harvest?> getHarvestById(int id);
  Future<Harvest?> getHarvestByPlantId(int plantId);
  Future<List<Harvest>> getAllHarvests();
  Future<List<Harvest>> getHarvestsByGrowId(int growId);
  Future<List<Harvest>> getDryingHarvests();
  Future<List<Harvest>> getCuringHarvests();
  Future<List<Harvest>> getCompletedHarvests();
  Future<double> getTotalYield();
  Future<double> getAverageYield();
  Future<int> getHarvestCount();
  Future<Map<String, dynamic>?> getHarvestWithPlant(int harvestId);
  Future<List<Map<String, dynamic>>> getAllHarvestsWithPlants();
}
