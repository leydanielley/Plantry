import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:growlog_app/theme/design_tokens.dart';

/// 1. Premium Glass Card (Bitget Style)
class PlantryPremiumCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double radius;
  final bool hasGlow;
  final Color? accentColor;

  const PlantryPremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.radius = DT.radiusCard,
    this.hasGlow = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: hasGlow && accentColor != null 
              ? DT.glowShadow(accentColor!) 
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                color: DT.glassBackground,
                border: Border.all(
                  color: DT.glassBorder,
                  width: 0.5,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 2. Technical Data Row (Precision Look)
class PlantryDataRow extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? color;

  const PlantryDataRow({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: DT.textTertiary),
            const SizedBox(width: 8),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: DT.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: DT.mono(
              size: 16,
              color: color ?? DT.textPrimary,
              weight: FontWeight.bold,
            ),
          ),
          if (unit != null) ...[
            const SizedBox(width: 4),
            Text(
              unit!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: (color ?? DT.textPrimary).withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 3. Glow Action Button
class PlantryGlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;

  const PlantryGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
  });

  @override
  State<PlantryGlowButton> createState() => _PlantryGlowButtonState();
}

class _PlantryGlowButtonState extends State<PlantryGlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isPrimary ? DT.accent : DT.elevated;
    final textColor = widget.isPrimary ? DT.onAccent : DT.textPrimary;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onPressed(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(DT.radiusButton),
            boxShadow: widget.isPrimary ? DT.glowShadow(DT.accent) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: textColor),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4. HUD Ticker Item
class PlantryHudItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const PlantryHudItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4, height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: DT.glowShadow(color)),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: DT.textSecondary, letterSpacing: 0.5),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: DT.mono(size: 11, color: DT.textPrimary, weight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// 5. Quick Action Bubble
class QuickActionBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const QuickActionBubble({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = DT.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: DT.glassBackground,
          shape: BoxShape.circle,
          border: Border.all(color: DT.glassBorder, width: 0.5),
        ),
        child: Icon(icon, size: 20, color: color.withValues(alpha: 0.8)),
      ),
    );
  }
}
