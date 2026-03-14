import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

/// Ein einheitlicher Button für das Plantry Design System.
/// Unterstützt Primary (Accent) und Secondary (Elevated) Styles.
class PlantryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool fullWidth;
  final IconData? icon;
  final bool isLoading;

  const PlantryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.fullWidth = false,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<PlantryButton> createState() => _PlantryButtonState();
}

class _PlantryButtonState extends State<PlantryButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.onPressed == null || widget.isLoading;

    final Widget content = Container(
      width: widget.fullWidth ? double.infinity : null,
      height: 54,
      decoration: BoxDecoration(
        color: widget.isPrimary
            ? (isDisabled ? DT.accent.withValues(alpha: 0.5) : DT.accent)
            : (isDisabled ? DT.elevated.withValues(alpha: 0.5) : DT.elevated),
        borderRadius: BorderRadius.circular(DT.radiusButton),
        boxShadow: widget.isPrimary && !isDisabled
            ? [
                BoxShadow(
                  color: DT.accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
        border: !widget.isPrimary
            ? Border.all(color: DT.border)
            : null,
      ),
      child: Center(
        child: widget.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(DT.textPrimary),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: widget.isPrimary ? DT.onAccent : DT.textPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.isPrimary ? DT.onAccent : DT.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );

    if (isDisabled) return content;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: content,
      ),
    );
  }
}
