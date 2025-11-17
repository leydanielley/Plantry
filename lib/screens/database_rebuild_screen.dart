// =============================================
// GROWLOG - Database Rebuild Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/services/database_rebuild_service.dart';
import 'package:growlog_app/utils/app_logger.dart';

class DatabaseRebuildScreen extends StatefulWidget {
  const DatabaseRebuildScreen({super.key});

  @override
  State<DatabaseRebuildScreen> createState() => _DatabaseRebuildScreenState();
}

class _DatabaseRebuildScreenState extends State<DatabaseRebuildScreen> {
  final _rebuildService = DatabaseRebuildService();

  bool _isRebuilding = false;
  bool _isComplete = false;
  double _progress = 0.0;
  String _currentPhase = 'Ready to rebuild';
  RebuildResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Rebuild'),
        backgroundColor: Colors.red.shade700,
      ),
      body: SafeArea(
        child: _isComplete && _result != null
            ? _buildResultView()
            : _buildRebuildView(),
      ),
    );
  }

  Widget _buildRebuildView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning Card
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'CRITICAL OPERATION',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This will rebuild your database from scratch while preserving all your data. '
                    'This is a CRITICAL operation that should only be used if your database is corrupted.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // What This Does
          const Text(
            'What This Does:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildBulletPoint('Creates emergency backup of current database'),
          _buildBulletPoint('Extracts all your data (plants, logs, photos)'),
          _buildBulletPoint('Deletes and recreates database with clean schema'),
          _buildBulletPoint('Imports all data back with proper transformations'),
          _buildBulletPoint('Validates data integrity'),
          _buildBulletPoint('Keeps backup for 30 days'),

          const SizedBox(height: 24),

          // Duration Warning
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.amber.shade900),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This process may take 15-60 minutes depending on database size. '
                      'Do not close the app during this process.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Progress Section
          if (_isRebuilding) ...[
            const Text(
              'Rebuild Progress:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              _currentPhase,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
          ],

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isRebuilding ? null : _startRebuild,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRebuilding ? Colors.grey : Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              child: _isRebuilding
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Rebuilding Database...'),
                      ],
                    )
                  : const Text(
                      'START REBUILD',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result Header
          Card(
            color: result.success ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    result.success ? Icons.check_circle : Icons.error,
                    color: result.success
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    size: 48,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.success ? 'REBUILD SUCCESSFUL' : 'REBUILD FAILED',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: result.success
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Duration: ${result.duration.inSeconds}s',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Record Counts
          if (result.success) ...[
            const Text(
              'Records Migrated:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: result.newRecordCounts.entries
                      .map((entry) {
                        final oldCount = result.oldRecordCounts[entry.key] ?? 0;
                        final newCount = entry.value;
                        final match = oldCount == newCount;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                match ? Icons.check : Icons.warning,
                                color: match ? Colors.green : Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(entry.key),
                              ),
                              Text(
                                '$oldCount → $newCount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: match ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Errors
          if (result.errors.isNotEmpty) ...[
            const Text(
              'Errors:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.errors
                      .map((error) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(error)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Warnings
          if (result.warnings.isNotEmpty) ...[
            const Text(
              'Warnings:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.warnings
                      .take(10)
                      .map((warning) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Colors.orange,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(warning)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            if (result.warnings.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... and ${result.warnings.length - 10} more warnings',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],

          // Backup Location
          if (result.backupPath != null) ...[
            const Text(
              'Backup Location:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.backup, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.backupPath!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Done Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: result.success ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'DONE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _startRebuild() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Database Rebuild'),
        content: const Text(
          'Are you sure you want to rebuild the database? '
          'This process cannot be interrupted once started.\n\n'
          'A backup will be created before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('START REBUILD'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRebuilding = true;
      _progress = 0.0;
      _currentPhase = 'Starting rebuild...';
    });

    try {
      final result = await _rebuildService.rebuildDatabase(
        onProgress: (current, total, message) {
          setState(() {
            _progress = current / total;
            _currentPhase = message;
          });
        },
      );

      setState(() {
        _isRebuilding = false;
        _isComplete = true;
        _result = result;
      });

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Database rebuild completed successfully!'
                  : 'Database rebuild failed: ${result.message}',
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stack) {
      AppLogger.error('DatabaseRebuildScreen', 'Rebuild failed', e, stack);

      setState(() {
        _isRebuilding = false;
        _isComplete = true;
        _result = RebuildResult(
          success: false,
          message: 'Rebuild failed: $e',
          errors: [e.toString()],
          duration: const Duration(seconds: 0),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rebuild failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
