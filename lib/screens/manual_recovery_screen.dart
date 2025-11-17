// =============================================
// GROWLOG - Manual Recovery Screen
// Allows users to manually restore data from backups
// =============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/screens/dashboard_screen.dart';
import 'package:growlog_app/database/database_helper.dart';

class ManualRecoveryScreen extends StatefulWidget {
  final String? errorMessage;
  final bool allowSkip;

  const ManualRecoveryScreen({
    super.key,
    this.errorMessage,
    this.allowSkip = false,
  });

  @override
  State<ManualRecoveryScreen> createState() => _ManualRecoveryScreenState();
}

class _ManualRecoveryScreenState extends State<ManualRecoveryScreen> {
  List<BackupFileInfo> _availableBackups = [];
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _restoreStatus;

  @override
  void initState() {
    super.initState();
    _loadAvailableBackups();
  }

  Future<void> _loadAvailableBackups() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backups = await _findAllBackups();
      setState(() {
        _availableBackups = backups;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('ManualRecoveryScreen', 'Failed to load backups', e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<BackupFileInfo>> _findAllBackups() async {
    final List<BackupFileInfo> backups = [];

    try {
      // 1. Check app documents directory
      final documentsDir = await getApplicationDocumentsDirectory();
      final appBackupsDir = Directory(
        path.join(documentsDir.path, 'plantry_backups'),
      );

      if (await appBackupsDir.exists()) {
        await _scanBackupDirectory(appBackupsDir, backups, 'App Backups');
      }

      // 2. Check emergency backups directory
      final emergencyDir = Directory(
        path.join(documentsDir.path, 'growlog_emergency_backups'),
      );

      if (await emergencyDir.exists()) {
        await _scanBackupDirectory(
          emergencyDir,
          backups,
          'Emergency Backups',
        );
      }

      // 3. Check Download folder (common user backup location)
      try {
        final downloadDir = Directory('/storage/emulated/0/Download/Plantry Backups');
        if (await downloadDir.exists()) {
          await _scanBackupDirectory(downloadDir, backups, 'Download Folder');
        }
      } catch (e) {
        // Ignore permission errors
      }

      // Sort by modification time (newest first)
      backups.sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));
    } catch (e) {
      AppLogger.error('ManualRecoveryScreen', 'Error scanning backups', e);
    }

    return backups;
  }

  Future<void> _scanBackupDirectory(
    Directory dir,
    List<BackupFileInfo> backups,
    String source,
  ) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final fileName = path.basename(entity.path);
          if (fileName.endsWith('.zip') || fileName.endsWith('.json')) {
            final stats = await entity.stat();
            backups.add(BackupFileInfo(
              filePath: entity.path,
              fileName: fileName,
              fileSize: stats.size,
              modifiedDate: stats.modified,
              source: source,
            ));
          }
        }
      }
    } catch (e) {
      AppLogger.warning(
        'ManualRecoveryScreen',
        'Could not scan directory: ${dir.path}',
        e,
      );
    }
  }

  Future<void> _restoreFromBackup(BackupFileInfo backup) async {
    setState(() {
      _isRestoring = true;
      _restoreStatus = 'Bereite Wiederherstellung vor...';
    });

    try {
      final backupService = getIt<IBackupService>();

      setState(() {
        _restoreStatus = 'Importiere Backup: ${backup.fileName}';
      });

      // Import the backup
      await backupService.importData(backup.filePath);

      setState(() {
        _restoreStatus = 'Wiederherstellung erfolgreich! ✅';
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Navigate to dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'ManualRecoveryScreen',
        'Restore failed',
        e,
        stackTrace,
      );

      setState(() {
        _isRestoring = false;
        _restoreStatus = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wiederherstellung fehlgeschlagen: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _pickCustomBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        final stats = await file.stat();

        final backup = BackupFileInfo(
          filePath: filePath,
          fileName: path.basename(filePath),
          fileSize: stats.size,
          modifiedDate: stats.modified,
          source: 'Custom',
        );

        await _restoreFromBackup(backup);
      }
    } catch (e) {
      AppLogger.error('ManualRecoveryScreen', 'Failed to pick file', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Auswählen der Datei: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createFreshDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 12),
            Text('Warnung'),
          ],
        ),
        content: const Text(
          'Dies wird eine neue, leere Datenbank erstellen.\n\n'
          'ALLE AKTUELLEN DATEN GEHEN VERLOREN!\n\n'
          'Sind Sie sicher?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Neue DB erstellen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRestoring = true;
      _restoreStatus = 'Erstelle neue Datenbank...';
    });

    try {
      // Get database path first
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;
      final dbPath = db.path;

      // Close and reset database helper
      await dbHelper.close();

      // Delete database files
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Delete WAL and SHM files
      final walFile = File('$dbPath-wal');
      if (await walFile.exists()) {
        await walFile.delete();
      }
      final shmFile = File('$dbPath-shm');
      if (await shmFile.exists()) {
        await shmFile.delete();
      }

      setState(() {
        _restoreStatus = 'Neue Datenbank erstellt! ✅';
      });

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Navigate to dashboard (database will be recreated automatically)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'ManualRecoveryScreen',
        'Failed to create fresh database',
        e,
        stackTrace,
      );

      setState(() {
        _isRestoring = false;
        _restoreStatus = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Erstellen der Datenbank: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Heute ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Gestern ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return 'Vor ${diff.inDays} Tagen';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Datenwiederherstellung'),
        automaticallyImplyLeading: widget.allowSkip,
        actions: [
          if (widget.allowSkip)
            TextButton(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  (route) => false,
                );
              },
              child: const Text('Überspringen'),
            ),
        ],
      ),
      body: _isRestoring
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    _restoreStatus ?? 'Wird bearbeitet...',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Error info (if provided)
                if (widget.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.orange.shade100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'Datenbankfehler erkannt',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.errorMessage!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                // Instructions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wiederherstellungsoptionen',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Wählen Sie ein automatisch gefundenes Backup aus\n'
                            '2. Wählen Sie eine eigene Backup-Datei aus\n'
                            '3. Oder erstellen Sie eine neue, leere Datenbank',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickCustomBackup,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Eigene Datei wählen'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _createFreshDatabase,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Neue DB'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Available backups list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _availableBackups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.backup_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Keine automatischen Backups gefunden',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Wählen Sie eine eigene Backup-Datei',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _availableBackups.length,
                              itemBuilder: (context, index) {
                                final backup = _availableBackups[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(
                                      backup.fileName.endsWith('.json')
                                          ? Icons.code
                                          : Icons.archive,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    title: Text(backup.fileName),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          backup.source,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          '${_formatDate(backup.modifiedDate)} • ${_formatFileSize(backup.fileSize)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: FilledButton(
                                      onPressed: () =>
                                          _restoreFromBackup(backup),
                                      child: const Text('Wiederherstellen'),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

/// Information about a backup file
class BackupFileInfo {
  final String filePath;
  final String fileName;
  final int fileSize;
  final DateTime modifiedDate;
  final String source;

  BackupFileInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.modifiedDate,
    required this.source,
  });
}
