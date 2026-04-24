// =============================================
// GROWLOG - Plant Photo Gallery Screen
// ✅ OPTIMIERT: Pagination + Lazy Loading + Batch-Queries
// =============================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:intl/intl.dart';
import 'package:growlog_app/models/plant.dart';
import 'package:growlog_app/models/photo.dart';
import 'package:growlog_app/models/plant_log.dart';
import 'package:growlog_app/repositories/interfaces/i_photo_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_plant_log_repository.dart';
import 'package:growlog_app/helpers/image_cache_helper.dart';
import 'package:growlog_app/widgets/empty_state_widget.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class PlantPhotoGalleryScreen extends StatefulWidget {
  final Plant plant;

  const PlantPhotoGalleryScreen({super.key, required this.plant});

  @override
  State<PlantPhotoGalleryScreen> createState() =>
      _PlantPhotoGalleryScreenState();
}

class _PlantPhotoGalleryScreenState extends State<PlantPhotoGalleryScreen> {
  final IPhotoRepository _photoRepo = getIt<IPhotoRepository>();
  final IPlantLogRepository _logRepo = getIt<IPlantLogRepository>();
  final ImageCacheHelper _imageCache = ImageCacheHelper();

  late AppTranslations _t;
  final List<Photo> _photos = [];
  final Map<int, PlantLog> _logs = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // ✅ FIX: Pagination
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMore = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _t = AppTranslations(Localizations.localeOf(context).languageCode);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPhotos();
  }

  @override
  void dispose() {
    // ✅ FIX: Remove listener before disposing to prevent memory leak
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ FIX: Lazy Loading beim Scrollen
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMorePhotos();
      }
    }
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _photos.clear();
      _logs.clear();
      _hasMore = true;
    });

    await _loadMorePhotos();
  }

  // ✅ FIX: Pagination mit Batch-Log-Loading (kein N+1 Problem!)
  Future<void> _loadMorePhotos() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newPhotos = await _photoRepo.getPhotosByPlantId(
        widget.plant.id!,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      // ✅ FIX: Batch-Loading aller Logs auf einmal!
      final logIds = newPhotos.map((p) => p.logId).toSet().toList();
      final newLogs = await _logRepo.findByIds(logIds);

      final newLogsMap = {for (final log in newLogs) log.id!: log};

      if (!mounted) return;
      setState(() {
        _photos.addAll(newPhotos);
        _logs.addAll(newLogsMap);
        _currentPage++;
        _hasMore = newPhotos.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('PlantPhotoGalleryScreen', 'Error loading photos: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _showPhotoDetail(Photo photo) {
    final log = _logs[photo.logId];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors
            .transparent, // intentionally transparent for photo dialog overlay
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.file(File(photo.filePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DT.canvas.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (log != null) ...[
                      Text(
                        'Tag ${log.dayNumber} • ${log.actionType.displayName}',
                        style: const TextStyle(
                          color: DT.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(log.logDate),
                        style: const TextStyle(
                          color: DT.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: DT.textPrimary, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => _deletePhoto(photo),
                backgroundColor: DT.error,
                child: const Icon(Icons.delete),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePhoto(Photo photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppTranslations(
            Localizations.localeOf(context).languageCode,
          )['plant_detail_delete_photo_title'],
        ),
        content: Text(
          AppTranslations(
            Localizations.localeOf(context).languageCode,
          )['plant_detail_delete_photo_confirm'],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: DT.error),
            child: Text(
              AppTranslations(
                Localizations.localeOf(context).languageCode,
              )['delete'],
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ✅ CRITICAL FIX: Use repository's safe deletion that handles both file AND DB atomically
        // Don't manually delete file - repository handles it properly with error handling
        await _photoRepo.deletePhoto(photo.id!);

        if (mounted) {
          Navigator.of(context).pop();
        }

        _loadPhotos();

        if (mounted) {
          AppMessages.showSuccess(context, 'Foto gelöscht! 🗑️');
        }
      } catch (e) {
        AppLogger.error('PlantPhotoGalleryScreen', 'Error deleting photo: $e');
        if (mounted) {
          AppMessages.showError(context, 'Fehler beim Löschen: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlantryScaffold(
      title: '${widget.plant.name} - Foto-Galerie',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
          ? _buildEmptyState()
          : _buildPhotoGrid(),
    );
  }

  /// ✅ PHASE 4: Replaced with shared EmptyStateWidget
  Widget _buildEmptyState() {
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    return EmptyStateWidget(
      icon: Icons.photo_library_outlined,
      title: t['no_photos_yet'],
      subtitle: t['add_photos_to_logs'],
    );
  }

  Widget _buildPhotoGrid() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: DT.info.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.photo_library, color: DT.info),
              const SizedBox(width: 12),
              Text(
                '${_photos.length} Fotos',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DT.info,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            controller: _scrollController, // ✅ FIX: Scroll Controller attached
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount:
                _photos.length +
                (_hasMore ? 1 : 0), // ✅ FIX: +1 für Loading Indicator
            itemBuilder: (context, index) {
              // ✅ FIX: Loading Indicator am Ende
              if (index == _photos.length) {
                return const Center(child: CircularProgressIndicator());
              }

              final photo = _photos[index];
              final log = _logs[photo.logId];

              return GestureDetector(
                onTap: () => _showPhotoDetail(photo),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildThumbnailImage(
                        photo,
                      ), // ✅ FIX: Cached Thumbnail
                    ),
                    if (log != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                DT.canvas.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            'Tag ${log.dayNumber}',
                            style: const TextStyle(
                              color: DT.textPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ✅ FIX: Thumbnail mit Caching
  Widget _buildThumbnailImage(Photo photo) {
    return FutureBuilder<Uint8List?>(
      future: _imageCache.loadThumbnail(photo.filePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: DT.elevated,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }

        // Fallback: Original Bild laden
        return Image.file(
          File(photo.filePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: DT.elevated,
              child: const Icon(Icons.broken_image, color: DT.textTertiary),
            );
          },
        );
      },
    );
  }
}
