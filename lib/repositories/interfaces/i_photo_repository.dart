// =============================================
// GROWLOG - PhotoRepository Interface
// =============================================

import 'package:growlog_app/models/photo.dart';

abstract class IPhotoRepository {
  Future<int> save(Photo photo);
  Future<List<Photo>> getPhotosByLogId(int logId);
  Future<Map<int, List<Photo>>> getPhotosByLogIds(List<int> logIds);
  Future<Photo?> getById(int id);
  Future<int> delete(int id);
  Future<int> deletePhoto(int id);
  Future<List<Photo>> getPhotosByPlantId(
    int plantId, {
    int? limit,
    int? offset,
  });
  Future<void> deleteByLogId(int logId);
}
