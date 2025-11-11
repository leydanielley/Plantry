import 'package:flutter/material.dart';

/// 🌈 Animated Gradient Background
/// 
/// Smooth animated gradient background
/// Perfect for app backgrounds, splash screens, hero sections
class AnimatedGradientBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final Duration duration;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;

  const AnimatedGradientBackground({
    super.key,
    required this.child,
    required this.colors,
    this.duration = const Duration(seconds: 3),
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  State<AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: widget.begin,
              end: widget.end,
              colors: widget.colors,
              stops: [
                0.0,
                _animation.value,
                1.0,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 🌈 Multi-Color Animated Gradient
/// 
/// Cycles through multiple gradient combinations
class MultiColorGradientBackground extends StatefulWidget {
  final Widget child;
  final List<List<Color>> gradients;
  final Duration duration;

  const MultiColorGradientBackground({
    super.key,
    required this.child,
    required this.gradients,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<MultiColorGradientBackground> createState() =>
      _MultiColorGradientBackgroundState();
}

class _MultiColorGradientBackgroundState
    extends State<MultiColorGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentGradientIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener(_handleAnimationStatus);
    _controller.forward();
  }

  /// ✅ CRITICAL FIX: Extract listener to enable proper cleanup
  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // ✅ CRITICAL FIX: Check mounted before setState
      if (mounted) {
        setState(() {
          _currentGradientIndex =
              (_currentGradientIndex + 1) % widget.gradients.length;
        });
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    // ✅ CRITICAL FIX: Remove listener before disposing to prevent setState after dispose
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextGradientIndex =
        (_currentGradientIndex + 1) % widget.gradients.length;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  widget.gradients[_currentGradientIndex][0],
                  widget.gradients[nextGradientIndex][0],
                  _controller.value,
                )!,
                Color.lerp(
                  widget.gradients[_currentGradientIndex][1],
                  widget.gradients[nextGradientIndex][1],
                  _controller.value,
                )!,
              ],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// 🌈 Shimmer Gradient Background
/// 
/// Animated shimmer effect moving across the background
class ShimmerGradientBackground extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerGradientBackground({
    super.key,
    required this.child,
    required this.baseColor,
    required this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShimmerGradientBackground> createState() =>
      _ShimmerGradientBackgroundState();
}

class _ShimmerGradientBackgroundState extends State<ShimmerGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, -1.0),
              end: Alignment(1.0 + _controller.value * 2, 1.0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}
