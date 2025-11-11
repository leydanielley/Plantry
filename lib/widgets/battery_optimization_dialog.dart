// =============================================
// GROWLOG - Battery Optimization Dialog
// Shows recommendations for device-specific settings
// =============================================

import 'package:flutter/material.dart';
import '../utils/device_info_helper.dart';
import '../utils/translations.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  final int crashCount;

  const BatteryOptimizationDialog({
    super.key,
    required this.crashCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTranslations(Localizations.localeOf(context).languageCode);
    final recommendations = DeviceInfoHelper.getDeviceSpecificRecommendations();

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 8),
          Text(t.translate('battery_dialog_title')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate('battery_dialog_crashes').replaceAll('{count}', crashCount.toString()),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              t.translate('battery_dialog_reason'),
            ),
            const SizedBox(height: 16),
            Text(
              t.translate('battery_dialog_recommendations'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(rec),
            )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('battery_dialog_understood')),
        ),
      ],
    );
  }

  /// Show the dialog if needed
  static Future<void> showIfNeeded(BuildContext context, int crashCount) async {
    if (DeviceInfoHelper.shouldShowBatteryWarning(crashCount)) {
      await showDialog(
        context: context,
        builder: (context) => BatteryOptimizationDialog(crashCount: crashCount),
      );
    }
  }
}
