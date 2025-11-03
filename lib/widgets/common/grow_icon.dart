import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 🎨 Custom Growing Icons
/// 
/// SVG Icons für Cannabis Growing App
class GrowIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const GrowIcon({
    super.key,
    required this.name,
    this.size = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Theme.of(context).iconTheme.color ?? Colors.grey;
    
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}

/// Available Icons:
/// - cannabis
/// - grow_light
/// - grow_tent
/// - nutrients
/// - scissors
class GrowIcons {
  static const String cannabis = 'cannabis';
  static const String growLight = 'grow_light';
  static const String growTent = 'grow_tent';
  static const String nutrients = 'nutrients';
  static const String scissors = 'scissors';
}
