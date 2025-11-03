import 'package:flutter/material.dart';

/// 🎯 Bouncy Button Widget
/// 
/// Animated button with bouncy scale effect on tap
/// Perfect for CTAs and interactive elements
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double scaleFactor;
  final Duration duration;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final BorderSide? border;
  final List<BoxShadow>? boxShadow;

  const BouncyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 12,
    this.padding,
    this.width,
    this.height,
    this.border,
    this.boxShadow,
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultBackgroundColor = widget.backgroundColor ?? theme.primaryColor;
    final defaultForegroundColor = widget.foregroundColor ?? Colors.white;

    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: widget.onPressed != null ? _onTapCancel : null,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: widget.onPressed == null
                ? defaultBackgroundColor.withValues(alpha: 0.5)
                : defaultBackgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border != null ? Border.fromBorderSide(widget.border!) : null,
            boxShadow: widget.onPressed == null ? null : (widget.boxShadow ?? [
              BoxShadow(
                color: defaultBackgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: defaultForegroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// 🎯 Bouncy Icon Button
class BouncyIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final double scaleFactor;
  final Duration duration;

  const BouncyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 24,
    this.color,
    this.backgroundColor,
    this.scaleFactor = 0.9,
    this.duration = const Duration(milliseconds: 100),
  });

  @override
  State<BouncyIconButton> createState() => _BouncyIconButtonState();
}

class _BouncyIconButtonState extends State<BouncyIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: widget.onPressed != null ? _onTapCancel : null,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: widget.backgroundColor != null
              ? BoxDecoration(
                  color: widget.backgroundColor,
                  shape: BoxShape.circle,
                )
              : null,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color ?? Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }
}
