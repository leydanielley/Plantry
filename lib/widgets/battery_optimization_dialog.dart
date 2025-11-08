// =============================================
// GROWLOG - Battery Optimization Dialog
// Shows recommendations for device-specific settings
// =============================================

import 'package:flutter/material.dart';
import '../utils/device_info_helper.dart';

class BatteryOptimizationDialog extends StatelessWidget {
  final int crashCount;

  const BatteryOptimizationDialog({
    super.key,
    required this.crashCount,
  });

  @override
  Widget build(BuildContext context) {
    final recommendations = DeviceInfoHelper.getDeviceSpecificRecommendations();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('App-Stabilität verbessern'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Die App wurde $crashCount mal unerwartet beendet.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dies kann durch aggressive Akku-Optimierung verursacht werden.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Empfohlene Einstellungen:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
          child: const Text('Verstanden'),
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
