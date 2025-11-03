// =============================================
// GROWLOG - Settings Screen (with Theme Switcher)
// =============================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../main.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../utils/translations.dart';
import '../database/database_helper.dart';
import '../services/backup_service.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(AppSettings)? onSettingsChanged;

  const SettingsScreen({
    super.key,
    this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();
  final BackupService _backupService = BackupService();
  late AppSettings _settings;
  late AppTranslations _t;
  bool _isLoading = true;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    setState(() {
      _settings = settings;
      _t = AppTranslations(_settings.language);
      _isLoading = false;
    });
  }

  Future<void> _changeLanguage(String newLanguage) async {
    final newSettings = _settings.copyWith(language: newLanguage);
    await _settingsRepo.saveSettings(newSettings);
    setState(() {
      _settings = newSettings;
      _t = AppTranslations(newLanguage);
    });

    if (!mounted) return;

    // Update app theme
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);

    AppMessages.showSuccess(context, _t['saved_success']);
  }

  Future<void> _toggleDarkMode(bool value) async {
    final newSettings = _settings.copyWith(isDarkMode: value);
    await _settingsRepo.saveSettings(newSettings);

    setState(() => _settings = newSettings);

    if (!mounted) return;

    // Update app theme immediately
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);

    AppMessages.showSuccess(context,
          value ? _t['dark_mode_enabled'] : _t['light_mode_enabled'],
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t['settings']),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language Section
          _buildSectionHeader(_t['language'], isDark),
          Card(
            child: Column(
              children: [
                _buildLanguageTile('de', _t['german'], '🇩🇪', isDark),
                const Divider(height: 1),
                _buildLanguageTile('en', _t['english'], '🇬🇧', isDark),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Backup & Restore Section
          _buildSectionHeader(_t['backup_restore'], isDark),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.upload_file, color: Colors.green[700]),
                  title: Text(_t['export_data']),
                  subtitle: Text(_t['export_data_desc']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _exportData,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.download, color: Colors.blue[700]),
                  title: Text(_t['import_data']),
                  subtitle: Text(_t['import_data_desc']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _importData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Theme Section
          _buildSectionHeader(_t['theme'], isDark),
          Card(
            child: SwitchListTile(
              title: Text(_t['dark_mode']),
              subtitle: Text(
                _settings.isDarkMode ? _t['dark_mode'] : _t['light_mode'],
              ),
              value: _settings.isDarkMode,
              onChanged: _toggleDarkMode,
              secondary: Icon(
                _settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Colors.green[700],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Legal & About Section
          _buildSectionHeader(_t['legal_about'], isDark),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip, color: Colors.green[700]),
                  title: Text(_t['privacy_policy']),
                  subtitle: Text(_t['privacy_policy_desc']),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PrivacyPolicyScreen(language: _settings.language),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.green[700]),
                  title: Text(_t['app_name']),
                  subtitle: const Text('Version 0.7.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.security, color: Colors.blue[700]),
                  title: Text(_t['offline_badge']),
                  subtitle: Text(_t['offline_badge_desc']),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data Management Section
          _buildSectionHeader(_t['data_management'], isDark),
          Card(
            color: Colors.red[50],
            child: ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red[700]),
              title: Text(
                _t['reset_database'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _t['reset_database_desc'],
                style: const TextStyle(fontSize: 12),
              ),
              onTap: _showResetConfirmation,
            ),
          ),

          const SizedBox(height: 24),

          // Debug Info
          Card(
            child: ListTile(
              leading: Icon(Icons.bug_report, color: Colors.orange[700]),
              title: const Text('Debug Info'),
              subtitle: Text('Theme: ${isDark ? "Dark" : "Light"}'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700]),
            const SizedBox(width: 12),
            Text(_t['reset_confirm_title']),
          ],
        ),
        content: Text(_t['reset_confirm_message']),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_t['cancel']),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text(_t['delete']),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _resetDatabase();
    }
  }

  Future<void> _exportData() async {
    _showingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          margin: EdgeInsets.all(24),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Creating backup...\nPlease wait!',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final zipPath = await _backupService.exportData();

      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;

        // Show success and share file
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 12),
                Text(_t['export_success']),
              ],
            ),
            content: Text(_t['export_success_desc']),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_t['close']),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: Text(_t['share']),
              ),
            ],
          ),
        );

        if (result == true) {
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(zipPath)], text: 'Plantry Backup');
        }
      }
    } catch (e) {
      AppLogger.error('SettingsScreen', 'Export error: $e');
      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;
      }
      if (mounted) {
        AppMessages.showError(context, '${_t['export_error']}: $e');
      }
    }
  }

  Future<void> _importData() async {
    try {
      // Pick backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (mounted) {
          AppMessages.showError(context, _t['import_error']);
        }
        return;
      }

      // Show backup info
      final info = await _backupService.getBackupInfo(filePath);

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 12),
              Text(_t['import_confirm']),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t['import_confirm_desc']),
              const SizedBox(height: 16),
              Text(
                '${_t['backup_info']}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('${_t['export_date']}: ${info['exportDate']}'),
              Text('${_t['plants']}: ${info['totalPlants']}'),
              Text('${_t['logs']}: ${info['totalLogs']}'),
              Text('${_t['photos']}: ${info['totalPhotos']}'),
              Text('${_t['rooms']}: ${info['totalRooms']}'),
              Text('${_t['grows']}: ${info['totalGrows']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_t['cancel']),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: Text(_t['import']),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // Show loading
      _showingDialog = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            margin: EdgeInsets.all(24),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Restoring backup...\nPlease wait!',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Import data
      await _backupService.importData(filePath);

      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;
      }

      if (mounted) {
        AppMessages.showSuccess(context, _t['import_success']);

        // Return to dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      AppLogger.error('SettingsScreen', 'Import error: $e');
      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;
      }
      if (mounted) {
        AppMessages.showError(context, '${_t['import_error']}: $e');
      }
    }
  }

  Future<void> _resetDatabase() async {
    _showingDialog = true;

    // Step 1: Show backup progress
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  _t['creating_backup'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Step 1: Create automatic backup
      final backupPath = await _backupService.exportData();
      AppLogger.info('SettingsScreen', 'Backup created at: $backupPath');

      if (!mounted) return;

      // Step 2: Delete all data
      final db = await DatabaseHelper.instance.database;

      // Delete all tables content (but keep structure)
      await db.transaction((txn) async {
        await txn.delete('log_fertilizers');
        await txn.delete('photos');
        await txn.delete('harvests');
        await txn.delete('plant_logs');
        await txn.delete('plants');
        await txn.delete('grows');
        await txn.delete('rooms');
        await txn.delete('hardware');
        await txn.delete('fertilizers');
      });

      AppLogger.info('SettingsScreen', 'All data deleted successfully');

      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;

        // Show success with backup info
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 12),
                Text(_t['reset_success']),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t['reset_success_desc']),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.backup, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            _t['backup_created'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        backupPath.split('/').last,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(_t['ok']),
              ),
            ],
          ),
        );

        // Return to dashboard
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('SettingsScreen', 'Error resetting database: $e', e, stackTrace);
      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;

        AppMessages.showError(context, '${_t['reset_error']}: $e');
      }
    }
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildLanguageTile(String code, String name, String flag, bool isDark) {
    final isSelected = _settings.language == code;
    
    return ListTile(
      leading: Text(
        flag,
        style: const TextStyle(fontSize: 28),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: Colors.green[700])
          : null,
      onTap: () => _changeLanguage(code),
    );
  }
}
