// =============================================
// GROWLOG - RdwcRepository Interface
// =============================================

import 'package:growlog_app/models/rdwc_system.dart';
import 'package:growlog_app/models/rdwc_log.dart';
import 'package:growlog_app/models/rdwc_log_fertilizer.dart';
import 'package:growlog_app/models/rdwc_recipe.dart';

abstract class IRdwcRepository {
  // RDWC Systems
  Future<List<RdwcSystem>> getAllSystems({bool includeArchived = false});
  Future<List<RdwcSystem>> getSystemsByRoom(int roomId, {bool includeArchived = false});
  Future<List<RdwcSystem>> getSystemsByGrow(int growId, {bool includeArchived = false});
  Future<RdwcSystem?> getSystemById(int id);
  Future<int> createSystem(RdwcSystem system);
  Future<int> updateSystem(RdwcSystem system);
  Future<void> updateSystemLevel(int systemId, double newLevel);
  Future<void> archiveSystem(int systemId, bool archived);
  Future<int> deleteSystem(int systemId);

  // RDWC Logs
  Future<List<RdwcLog>> getLogsBySystem(int systemId, {int? limit});
  Future<List<RdwcLog>> getRecentLogs(int systemId, {int limit = 10});
  Future<RdwcLog?> getLatestLog(int systemId);
  Future<int> createLog(RdwcLog log);
  Future<int> updateLog(RdwcLog log);
  Future<int> deleteLog(int logId);
  Future<double?> getAverageDailyConsumption(int systemId, {int days = 7});
  Future<double> getTotalWaterAdded(int systemId, {DateTime? startDate, DateTime? endDate});

  // RDWC Log Fertilizers
  Future<int> addFertilizerToLog(RdwcLogFertilizer fertilizer);
  Future<int> removeFertilizerFromLog(int fertilizerId);
  Future<List<RdwcLogFertilizer>> getLogFertilizers(int rdwcLogId);
  Future<RdwcLog?> getLogWithFertilizers(int logId);
  Future<List<RdwcLog>> getRecentLogsWithFertilizers(int systemId, {int limit = 10});

  // RDWC Recipes
  Future<List<RdwcRecipe>> getAllRecipes();
  Future<RdwcRecipe?> getRecipeById(int id);
  Future<List<RecipeFertilizer>> getRecipeFertilizers(int recipeId);
  Future<int> createRecipeFertilizer(RecipeFertilizer recipeFertilizer);
  Future<int> deleteRecipeFertilizer(int id);
  Future<int> createRecipe(RdwcRecipe recipe);
  Future<int> updateRecipe(RdwcRecipe recipe);
  Future<int> deleteRecipe(int recipeId);

  // Consumption Tracking
  Future<Map<String, double>> getDailyConsumption(int systemId, {int days = 7});
  Future<Map<String, dynamic>> getConsumptionStats(int systemId, {int days = 7});

  // Drift Analysis
  Future<Map<String, dynamic>> getEcDriftAnalysis(int systemId, {int days = 7});
  Future<Map<String, dynamic>> getPhDriftAnalysis(int systemId, {int days = 7});
}
