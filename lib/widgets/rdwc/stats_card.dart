// =============================================
// GROWLOG - RDWC Stats Card Widget
// =============================================

import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

class StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend; // 'up', 'down', 'stable', null
  final String? subtitle;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DT.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trend != null) _buildTrendIndicator(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  color: DT.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    IconData trendIcon;
    Color trendColor;

    switch (trend) {
      case 'up':
        trendIcon = Icons.trending_up;
        trendColor = DT.success;
        break;
      case 'down':
        trendIcon = Icons.trending_down;
        trendColor = DT.error;
        break;
      case 'stable':
        trendIcon = Icons.trending_flat;
        trendColor = DT.secondary;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(trendIcon, color: trendColor, size: 20);
  }
}
