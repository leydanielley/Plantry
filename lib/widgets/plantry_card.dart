import 'package:flutter/material.dart';
import 'package:growlog_app/theme/design_tokens.dart';

/// Eine einheitliche Card-Komponente für das Plantry Design System.
/// Nutzt DT.cardDeco() für konsistente Hintergründe, Radien und Schatten.
class PlantryCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final double? radius;
  final bool isFlat;

  const PlantryCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.radius,
    this.isFlat = false,
  });

  @override
  State<PlantryCard> createState() => _PlantryCardState();
}

class _PlantryCardState extends State<PlantryCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
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
    final Widget content = Container(
      width: double.infinity,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: widget.isFlat
          ? DT.cardDecoFlat(radius: widget.radius ?? DT.radiusCard)
          : DT.cardDeco(radius: widget.radius ?? DT.radiusCard),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap?.call();
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

    return content;
  }
}
