// =============================================
// GROWLOG - Settings Screen (with Theme Switcher)
// =============================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/app_messages.dart';
import '../utils/app_logger.dart';
import '../main.dart';
import '../models/app_settings.dart';
import '../repositories/settings_repository.dart';
import '../utils/translations.dart';
import '../database/database_helper.dart';
import '../services/backup_service.dart';
import '../utils/app_version.dart';
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
    if (mounted) {
      setState(() {
        _settings = settings;
        _t = AppTranslations(_settings.language);
        _isLoading = false;
      });
    }
  }

  Future<void> _changeLanguage(String newLanguage) async {
    final newSettings = _settings.copyWith(language: newLanguage);
    await _settingsRepo.saveSettings(newSettings);

    if (!mounted) return;

    setState(() {
      _settings = newSettings;
      _t = AppTranslations(newLanguage);
    });

    // Update app theme
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);

    AppMessages.showSuccess(context, _t['saved_success']);
  }

  Future<void> _toggleDarkMode(bool value) async {
    final newSettings = _settings.copyWith(isDarkMode: value);
    await _settingsRepo.saveSettings(newSettings);

    if (!mounted) return;

    setState(() => _settings = newSettings);

    // Update app theme immediately
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);

    AppMessages.showSuccess(context,
          value ? _t['dark_mode_enabled'] : _t['light_mode_enabled'],
        );
  }

  Future<void> _toggleExpertMode(bool value) async {
    // Show warning when enabling Expert Mode
    if (value == true) {
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 12),
              const Text('Expert-Modus'),
            ],
          ),
          content: const Text(
            'Der Expert-Modus ist experimentell und kann noch Fehler enthalten.\n\n'
            'Er bietet erweiterte Funktionen wie:\n'
            '• RDWC System Management\n'
            '• Detaillierte Nährstoff-Tracking\n'
            '• EC/pH Drift-Analyse\n\n'
            'Möchten Sie den Expert-Modus aktivieren?\n\n'
            'Falls Sie unsicher sind, bleiben Sie im Normal-Modus.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Normal-Modus behalten'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Expert-Modus aktivieren'),
            ),
          ],
        ),
      );

      if (confirm != true) return; // User cancelled or chose to stay in normal mode
    }

    final newSettings = _settings.copyWith(isExpertMode: value);
    await _settingsRepo.saveSettings(newSettings);

    if (!mounted) return;

    setState(() => _settings = newSettings);

    // Update app settings
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);

    AppMessages.showSuccess(context,
          value ? _t['expert_mode_enabled'] : _t['expert_mode_disabled'],
        );
  }

  Future<void> _changeNutrientUnit(NutrientUnit unit) async {
    final newSettings = _settings.copyWith(nutrientUnit: unit);
    await _settingsRepo.saveSettings(newSettings);
    if (!mounted) return;
    setState(() => _settings = newSettings);
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);
  }

  Future<void> _changePpmScale(PpmScale scale) async {
    final newSettings = _settings.copyWith(ppmScale: scale);
    await _settingsRepo.saveSettings(newSettings);
    if (!mounted) return;
    setState(() => _settings = newSettings);
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);
  }

  Future<void> _changeTemperatureUnit(TemperatureUnit unit) async {
    final newSettings = _settings.copyWith(temperatureUnit: unit);
    await _settingsRepo.saveSettings(newSettings);
    if (!mounted) return;
    setState(() => _settings = newSettings);
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);
  }

  Future<void> _changeLengthUnit(LengthUnit unit) async {
    final newSettings = _settings.copyWith(lengthUnit: unit);
    await _settingsRepo.saveSettings(newSettings);
    if (!mounted) return;
    setState(() => _settings = newSettings);
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);
  }

  Future<void> _changeVolumeUnit(VolumeUnit unit) async {
    final newSettings = _settings.copyWith(volumeUnit: unit);
    await _settingsRepo.saveSettings(newSettings);
    if (!mounted) return;
    setState(() => _settings = newSettings);
    GrowLogApp.of(context)?.updateSettings(newSettings);
    widget.onSettingsChanged?.call(newSettings);
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

          // Expert Mode Section
          _buildSectionHeader(_t['expert_mode'], isDark),
          Card(
            child: SwitchListTile(
              title: Text(_t['expert_mode']),
              subtitle: Text(_t['expert_mode_desc']),
              value: _settings.isExpertMode,
              onChanged: _toggleExpertMode,
              secondary: Icon(
                _settings.isExpertMode ? Icons.engineering : Icons.person,
                color: Colors.orange[700],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Measurement Units Section
          _buildSectionHeader(_t['measurement_units'], isDark),
          Card(
            child: Column(
              children: [
                // Nutrient Unit (EC/PPM)
                ListTile(
                  leading: Icon(Icons.science, color: Colors.blue[700]),
                  title: Text(_t['nutrient_unit']),
                  trailing: SegmentedButton<NutrientUnit>(
                    segments: [
                      ButtonSegment(
                        value: NutrientUnit.ec,
                        label: Text('EC'),
                      ),
                      ButtonSegment(
                        value: NutrientUnit.ppm,
                        label: Text('PPM'),
                      ),
                    ],
                    selected: {_settings.nutrientUnit},
                    onSelectionChanged: (Set<NutrientUnit> selected) {
                      _changeNutrientUnit(selected.first);
                    },
                  ),
                ),
                const Divider(height: 1),

                // PPM Scale (nur sichtbar wenn PPM gewählt)
                if (_settings.nutrientUnit == NutrientUnit.ppm) ...[
                  ListTile(
                    leading: Icon(Icons.analytics, color: Colors.purple[700]),
                    title: Text(_t['ppm_scale']),
                    subtitle: Text(_t['ppm_scale_help']),
                    trailing: SegmentedButton<PpmScale>(
                      segments: [
                        ButtonSegment(
                          value: PpmScale.scale500,
                          label: Text('500'),
                        ),
                        ButtonSegment(
                          value: PpmScale.scale700,
                          label: Text('700'),
                        ),
                        ButtonSegment(
                          value: PpmScale.scale640,
                          label: Text('640'),
                        ),
                      ],
                      selected: {_settings.ppmScale},
                      onSelectionChanged: (Set<PpmScale> selected) {
                        _changePpmScale(selected.first);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                ],

                // Temperature Unit (C/F)
                ListTile(
                  leading: Icon(Icons.thermostat, color: Colors.orange[700]),
                  title: Text(_t['temperature_unit']),
                  trailing: SegmentedButton<TemperatureUnit>(
                    segments: [
                      ButtonSegment(
                        value: TemperatureUnit.celsius,
                        label: Text('°C'),
                      ),
                      ButtonSegment(
                        value: TemperatureUnit.fahrenheit,
                        label: Text('°F'),
                      ),
                    ],
                    selected: {_settings.temperatureUnit},
                    onSelectionChanged: (Set<TemperatureUnit> selected) {
                      _changeTemperatureUnit(selected.first);
                    },
                  ),
                ),
                const Divider(height: 1),

                // Length Unit (cm/inch)
                ListTile(
                  leading: Icon(Icons.straighten, color: Colors.green[700]),
                  title: Text(_t['length_unit']),
                  trailing: SegmentedButton<LengthUnit>(
                    segments: [
                      ButtonSegment(
                        value: LengthUnit.cm,
                        label: Text('cm'),
                      ),
                      ButtonSegment(
                        value: LengthUnit.inch,
                        label: Text('inch'),
                      ),
                    ],
                    selected: {_settings.lengthUnit},
                    onSelectionChanged: (Set<LengthUnit> selected) {
                      _changeLengthUnit(selected.first);
                    },
                  ),
                ),
                const Divider(height: 1),

                // Volume Unit (L/Gal)
                ListTile(
                  leading: Icon(Icons.water_drop, color: Colors.cyan[700]),
                  title: Text(_t['volume_unit']),
                  trailing: SegmentedButton<VolumeUnit>(
                    segments: [
                      ButtonSegment(
                        value: VolumeUnit.liter,
                        label: Text('L'),
                      ),
                      ButtonSegment(
                        value: VolumeUnit.gallon,
                        label: Text('gal'),
                      ),
                    ],
                    selected: {_settings.volumeUnit},
                    onSelectionChanged: (Set<VolumeUnit> selected) {
                      _changeVolumeUnit(selected.first);
                    },
                  ),
                ),
              ],
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
                  subtitle: Text('Version ${AppVersion.versionWithoutBuild}'),
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
              subtitle: Text('Theme: ${isDark ? "Dark" : "Light"}\nExpert Mode: ${_settings.isExpertMode ? "Enabled" : "Disabled"}'),
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
      await _backupService.exportData();

      if (mounted && _showingDialog) {
        Navigator.of(context).pop(); // Close loading dialog
        _showingDialog = false;

        // Show success message
        await showDialog(
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
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: Text(_t['ok']),
              ),
            ],
          ),
        );
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
