// =============================================
// GROWLOG - Settings Screen
// =============================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:growlog_app/utils/app_messages.dart';
import 'package:growlog_app/main.dart';
import 'package:growlog_app/models/app_settings.dart';
import 'package:growlog_app/utils/translations.dart';
import 'package:growlog_app/repositories/interfaces/i_settings_repository.dart';
import 'package:growlog_app/services/interfaces/i_backup_service.dart';
import 'package:growlog_app/database/database_helper.dart';
import 'package:growlog_app/utils/app_version.dart';
import 'package:growlog_app/screens/archive_screen.dart';
import 'package:growlog_app/screens/privacy_policy_screen.dart';
import 'package:growlog_app/di/service_locator.dart';
import 'package:growlog_app/widgets/plantry_scaffold.dart';
import 'package:growlog_app/widgets/plantry_card.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class SettingsScreen extends StatefulWidget {
  final Function(AppSettings)? onSettingsChanged;
  const SettingsScreen({super.key, this.onSettingsChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ISettingsRepository _settingsRepo = getIt<ISettingsRepository>();
  final IBackupService _backupService = getIt<IBackupService>();
  late AppSettings _settings;
  late AppTranslations _t;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await _settingsRepo.getSettings();
    if (mounted) {
      setState(() {
        _settings = s;
        _t = AppTranslations(s.language);
        _isLoading = false;
      });
    }
  }

  Future<void> _update(AppSettings ns) async {
    await _settingsRepo.saveSettings(ns);
    if (mounted) {
      setState(() { _settings = ns; _t = AppTranslations(ns.language); });
      GrowLogApp.of(context)?.updateSettings(ns);
      widget.onSettingsChanged?.call(ns);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(backgroundColor: DT.canvas, body: Center(child: CircularProgressIndicator(color: DT.accent)));

    return PlantryScaffold(
      title: _t['settings'],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Sprache
          _section(_t['language']),
          PlantryCard(
            child: Column(children: [
              _radioTile('Deutsch', 'de', '🇩🇪'),
              const Divider(height: 1, color: DT.border),
              _radioTile('English', 'en', '🇬🇧'),
            ]),
          ),
          const SizedBox(height: 24),

          // Design
          _section(_t['personalization']),
          PlantryCard(
            child: Column(children: [
              _switch(_t['dark_mode'], _settings.isDarkMode, (v) => _update(_settings.copyWith(isDarkMode: v))),
              const Divider(height: 1, color: DT.border),
              _switch('Experten Modus', _settings.isExpertMode, (v) => _update(_settings.copyWith(isExpertMode: v))),
            ]),
          ),
          const SizedBox(height: 24),

          // Einheiten
          _section(_t['units_section']),
          PlantryCard(
            child: Column(children: [
              _unitRow('Nährstoffe', _settings.nutrientUnit == NutrientUnit.ec ? 'EC' : 'PPM', () => _update(_settings.copyWith(nutrientUnit: _settings.nutrientUnit == NutrientUnit.ec ? NutrientUnit.ppm : NutrientUnit.ec))),
              if (_settings.nutrientUnit == NutrientUnit.ppm) ...[
                const Divider(height: 1, color: DT.border),
                _unitRow('PPM Skala', _settings.ppmScale.toString().split('.').last.replaceAll('scale', ''), _showPpmScaleDialog),
              ],
              const Divider(height: 1, color: DT.border),
              _unitRow('Temperatur', _settings.temperatureUnit == TemperatureUnit.celsius ? '°C' : '°F', () => _update(_settings.copyWith(temperatureUnit: _settings.temperatureUnit == TemperatureUnit.celsius ? TemperatureUnit.fahrenheit : TemperatureUnit.celsius))),
              const Divider(height: 1, color: DT.border),
              _unitRow('Volumen', _settings.volumeUnit == VolumeUnit.liter ? 'Liter' : 'Gallonen', () => _update(_settings.copyWith(volumeUnit: _settings.volumeUnit == VolumeUnit.liter ? VolumeUnit.gallon : VolumeUnit.liter))),
            ]),
          ),
          const SizedBox(height: 24),

          // Datensicherung
          _section(_t['backup_section']),
          PlantryCard(
            child: Column(children: [
              _actionTile('Daten exportieren', Icons.upload_file, DT.accent, _exportData),
              const Divider(height: 1, color: DT.border),
              _actionTile('Daten importieren', Icons.download, DT.secondary, _importData),
            ]),
          ),
          const SizedBox(height: 24),

          // Archiv & Reset
          _section(_t['data_section']),
          PlantryCard(
            child: Column(children: [
              _actionTile(_t['archive_section'], Icons.archive_outlined, DT.warning, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen()))),
              const Divider(height: 1, color: DT.border),
              _actionTile('Datenbank zurücksetzen', Icons.delete_forever, DT.error, _showResetConfirmation),
            ]),
          ),
          const SizedBox(height: 24),

          // Rechtliches
          _section(_t['information_section']),
          PlantryCard(
            child: Column(children: [
              _actionTile(_t['privacy_policy'], Icons.privacy_tip_outlined, DT.textSecondary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyPolicyScreen(language: _settings.language)))),
              const Divider(height: 1, color: DT.border),
              _actionTile('GitHub Repository', Icons.code, DT.textSecondary, () => _launch('https://github.com/leydanielley/Plantry')),
              const Divider(height: 1, color: DT.border),
              _actionTile(_t['support_donate'], Icons.favorite_outline, DT.error, () => _launch('https://paypal.me/papayaa74')),
            ]),
          ),
          const SizedBox(height: 32),

          Center(child: Text('Version ${AppVersion.versionWithoutBuild}', style: const TextStyle(color: DT.textTertiary, fontSize: 12))),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DT.textTertiary, letterSpacing: 1.5)));

  Widget _switch(String l, bool v, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(l, style: const TextStyle(color: DT.textPrimary, fontSize: 15)),
      value: v, onChanged: onChanged, activeThumbColor: DT.accent, contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _radioTile(String l, String code, String flag) {
    final sel = _settings.language == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 20)),
      title: Text(l, style: TextStyle(color: DT.textPrimary, fontSize: 15, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
      trailing: sel ? const Icon(Icons.check_circle, color: DT.accent, size: 20) : null,
      onTap: () => _update(_settings.copyWith(language: code)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _unitRow(String l, String v, VoidCallback onTap) {
    return ListTile(
      title: Text(l, style: const TextStyle(color: DT.textPrimary, fontSize: 15)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: DT.elevated, borderRadius: BorderRadius.circular(8)),
        child: Text(v, style: const TextStyle(color: DT.accent, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _actionTile(String l, IconData i, Color c, VoidCallback onTap) {
    return ListTile(
      leading: Icon(i, color: c, size: 20),
      title: Text(l, style: const TextStyle(color: DT.textPrimary, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, color: DT.textTertiary, size: 18),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  // PPM Scale Dialog
  void _showPpmScaleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DT.elevated,
        title: const Text('PPM Skala wählen', style: TextStyle(color: DT.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ppmItem(PpmScale.scale500, '500 (Hanna)'),
            _ppmItem(PpmScale.scale700, '700 (Truncheon)'),
            _ppmItem(PpmScale.scale640, '640 (Ewa)'),
          ],
        ),
      ),
    );
  }

  Widget _ppmItem(PpmScale s, String l) {
    return ListTile(
      title: Text(l, style: const TextStyle(color: DT.textPrimary)),
      onTap: () { _update(_settings.copyWith(ppmScale: s)); Navigator.pop(context); },
    );
  }

  // Backup & Reset Logic
  Future<void> _exportData() async {
    try {
      await _backupService.exportData();
      if (!mounted) return;
      AppMessages.showSuccess(context, 'Export erfolgreich!');
    } catch (e) {
      if (!mounted) return;
      AppMessages.showError(context, 'Fehler: $e');
    }
  }

  Future<void> _importData() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      if (res != null && res.files.single.path != null) {
        await _backupService.importData(res.files.single.path!);
        if (!mounted) return;
        AppMessages.showSuccess(context, 'Import erfolgreich!');
      }
    } catch (e) {
      if (!mounted) return;
      AppMessages.showError(context, 'Fehler: $e');
    }
  }

  Future<void> _showResetConfirmation() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: DT.elevated,
      title: Text(_t['delete_all_title'], style: const TextStyle(color: DT.error)),
      content: const Text('Dies löscht permanent alle Daten. Ein Backup wird automatisch erstellt.', style: TextStyle(color: DT.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t['cancel'], style: const TextStyle(color: DT.textSecondary))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t['delete_all_btn'], style: const TextStyle(color: DT.error))),
      ],
    ));
    if (ok == true) {
      await _backupService.exportData();
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        await txn.delete('plants'); await txn.delete('plant_logs'); await txn.delete('grows');
        await txn.delete('rooms'); await txn.delete('hardware'); await txn.delete('fertilizers');
      });
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
