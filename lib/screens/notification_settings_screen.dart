// =============================================
// GROWLOG - Notification Settings Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/models/notification_settings.dart';
import 'package:growlog_app/repositories/interfaces/i_notification_repository.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/services/interfaces/i_notification_service.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/utils/app_logger.dart';
import 'package:growlog_app/di/service_locator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final INotificationRepository _repo = getIt<INotificationRepository>();
  final INotificationService _notificationService = getIt<INotificationService>();
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();

  late AppTranslations _t = AppTranslations('de');
  NotificationSettings? _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTranslations();
    _loadSettings();
  }

  Future<void> _initTranslations() async {
    final settings = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _t = AppTranslations(settings.language);
      });
    }
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _repo.getSettings();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('NotificationSettingsScreen', 'Failed to load settings', e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings(NotificationSettings settings) async {
    try {
      await _repo.saveSettings(settings);
      if (mounted) {
        setState(() => _settings = settings);
        AppMessages.showSuccess(context, _t['settings_saved']);
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, _t['error_saving_settings']);
      }
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      // Request permission first
      await _notificationService.initialize();
      final granted = await _notificationService.requestPermissions();

      if (!granted) {
        if (mounted) {
          AppMessages.showError(context, _t['notification_permission_denied']);
        }
        return;
      }
    }

    _saveSettings(_settings!.copyWith(enabled: value));
  }

  Future<void> _sendTestNotification() async {
    try {
      await _notificationService.initialize();
      await _notificationService.showTestNotification();

      if (mounted) {
        AppMessages.showSuccess(context, _t['notification_test_sent']);
      }
    } catch (e) {
      if (mounted) {
        AppMessages.showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _settings == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_t['notifications']),
          backgroundColor: const Color(0xFF004225),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_t['notifications']),
        backgroundColor: const Color(0xFF004225),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable
          Card(
            child: SwitchListTile(
              title: Text(
                _t['notifications'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_t['notifications_desc']),
              value: _settings!.enabled,
              onChanged: _toggleEnabled,
              secondary: Icon(
                _settings!.enabled ? Icons.notifications_active : Icons.notifications_off,
                color: _settings!.enabled ? Colors.green : Colors.grey,
              ),
            ),
          ),

          if (_settings!.enabled) ...[
            const SizedBox(height: 16),

            // Reminder Types
            _buildSection(
              title: 'Erinnerungs-Typen',
              children: [
                SwitchListTile(
                  title: Text(_t['watering_reminders']),
                  subtitle: Text('${_t['notification_interval']}: ${_settings!.wateringIntervalDays} ${_t['days']}'),
                  value: _settings!.wateringReminders,
                  onChanged: (v) => _saveSettings(_settings!.copyWith(wateringReminders: v)),
                  secondary: const Icon(Icons.water_drop, color: Colors.blue),
                ),
                if (_settings!.wateringReminders)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildIntervalSlider(
                      label: _t['watering_interval'],
                      value: _settings!.wateringIntervalDays,
                      min: 1,
                      max: 7,
                      onChanged: (v) => _saveSettings(_settings!.copyWith(wateringIntervalDays: v.toInt())),
                    ),
                  ),

                const Divider(),

                SwitchListTile(
                  title: Text(_t['fertilizing_reminders']),
                  subtitle: Text('${_t['notification_interval']}: ${_settings!.fertilizingIntervalDays} ${_t['days']}'),
                  value: _settings!.fertilizingReminders,
                  onChanged: (v) => _saveSettings(_settings!.copyWith(fertilizingReminders: v)),
                  secondary: const Icon(Icons.eco, color: Colors.green),
                ),
                if (_settings!.fertilizingReminders)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildIntervalSlider(
                      label: _t['fertilizing_interval'],
                      value: _settings!.fertilizingIntervalDays,
                      min: 3,
                      max: 14,
                      onChanged: (v) => _saveSettings(_settings!.copyWith(fertilizingIntervalDays: v.toInt())),
                    ),
                  ),

                const Divider(),

                SwitchListTile(
                  title: Text(_t['photo_reminders']),
                  subtitle: Text('${_t['notification_interval']}: ${_settings!.photoIntervalDays} ${_t['days']}'),
                  value: _settings!.photoReminders,
                  onChanged: (v) => _saveSettings(_settings!.copyWith(photoReminders: v)),
                  secondary: const Icon(Icons.camera_alt, color: Colors.orange),
                ),
                if (_settings!.photoReminders)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildIntervalSlider(
                      label: _t['photo_interval'],
                      value: _settings!.photoIntervalDays,
                      min: 1,
                      max: 14,
                      onChanged: (v) => _saveSettings(_settings!.copyWith(photoIntervalDays: v.toInt())),
                    ),
                  ),

                const Divider(),

                SwitchListTile(
                  title: Text(_t['harvest_reminders']),
                  subtitle: Text(_t['harvest_reminder_subtitle']),
                  value: _settings!.harvestReminders,
                  onChanged: (v) => _saveSettings(_settings!.copyWith(harvestReminders: v)),
                  secondary: const Icon(Icons.agriculture, color: Colors.brown),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notification Time
            _buildSection(
              title: _t['notification_time'],
              children: [
                ListTile(
                  leading: const Icon(Icons.access_time, color: Color(0xFF004225)),
                  title: Text(_t['notification_time']),
                  subtitle: Text(_settings!.notificationTime),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _selectNotificationTime,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Test Notification
            ElevatedButton.icon(
              onPressed: _sendTestNotification,
              icon: const Icon(Icons.send),
              label: Text(_t['notification_test']),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004225),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200] ?? Colors.blue),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Benachrichtigungen werden basierend auf deinen letzten Log-Einträgen automatisch geplant. Die App funktioniert komplett offline!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004225),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildIntervalSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '$label: $value ${_t['days']}',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value ${_t['days']}',
          onChanged: onChanged,
          activeColor: const Color(0xFF004225),
        ),
      ],
    );
  }

  Future<void> _selectNotificationTime() async {
    final timeParts = _settings!.notificationTime.split(':');
    // ✅ CRITICAL FIX: Use tryParse to prevent crash on invalid input
    final initialTime = TimeOfDay(
      hour: int.tryParse(timeParts[0]) ?? 10,
      minute: int.tryParse(timeParts[1]) ?? 0,
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final timeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      _saveSettings(_settings!.copyWith(notificationTime: timeString));
    }
  }
}
