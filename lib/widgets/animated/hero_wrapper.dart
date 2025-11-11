import 'package:flutter/material.dart';

/// 🚀 Hero Animation Wrapper
///
/// Simplifies Hero animations between screens
/// Automatically handles tags and transitions
class HeroWrapper extends StatelessWidget {
  final String tag;
  final Widget child;
  final bool enabled;

  const HeroWrapper({
    super.key,
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Hero(
      tag: tag,
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// 🚀 Hero Card Wrapper
///
/// Hero animation for card transitions
class HeroCard extends StatelessWidget {
  final String tag;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const HeroCard({
    super.key,
    required this.tag,
    required this.child,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        elevation: 0,
        child: child,
      ),
    );
  }
}

/// 🚀 Hero Image Wrapper
///
/// Hero animation for images
class HeroImage extends StatelessWidget {
  final String tag;
  final ImageProvider image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const HeroImage({
    super.key,
    required this.tag,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        child: Image(image: image, width: width, height: height, fit: fit),
      ),
    );
  }
}

/// 🚀 Hero Page Route
///
/// Custom page route with hero-friendly transitions
class HeroPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration animationDuration;

  HeroPageRoute({
    required this.builder,
    this.animationDuration = const Duration(milliseconds: 300),
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => animationDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

/// 🚀 Scale Hero Page Route
///
/// Hero transition with scale effect
class ScaleHeroPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration animationDuration;

  ScaleHeroPageRoute({
    required this.builder,
    this.animationDuration = const Duration(milliseconds: 300),
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => animationDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.8,
        end: 1.0,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

/// 🚀 Slide Hero Page Route
///
/// Hero transition with slide effect
class SlideHeroPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration animationDuration;
  final Offset beginOffset;

  SlideHeroPageRoute({
    required this.builder,
    this.animationDuration = const Duration(milliseconds: 300),
    this.beginOffset = const Offset(1.0, 0.0),
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => animationDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    );
  }
}
