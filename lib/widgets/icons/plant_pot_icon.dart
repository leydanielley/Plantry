// =============================================
// GROWLOG - Custom Plant Pot Icon Widget
// =============================================

import 'package:flutter/material.dart';

class PlantPotIcon extends StatelessWidget {
  final double size;
  final Color? leavesColor;
  final Color? stemColor;
  final Color? potColor;
  final Color? soilColor;

  const PlantPotIcon({
    super.key,
    this.size = 80,
    this.leavesColor,
    this.stemColor,
    this.potColor,
    this.soilColor,
  });

  @override
  Widget build(BuildContext context) {
    final leaves = leavesColor ?? const Color(0xFF4CAF50);
    final stem = stemColor ?? const Color(0xFF6D4C41);
    final pot = potColor ?? const Color(0xFF78909C);
    final soil = soilColor ?? const Color(0xFF5D4037);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PlantPotPainter(
          leavesColor: leaves,
          stemColor: stem,
          potColor: pot,
          soilColor: soil,
        ),
      ),
    );
  }
}

class _PlantPotPainter extends CustomPainter {
  final Color leavesColor;
  final Color stemColor;
  final Color potColor;
  final Color soilColor;

  _PlantPotPainter({
    required this.leavesColor,
    required this.stemColor,
    required this.potColor,
    required this.soilColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Pot
    final potPaint = Paint()
      ..color = potColor
      ..style = PaintingStyle.fill;

    final potPath = Path();
    potPath.moveTo(width * 0.25, height * 0.55);
    potPath.lineTo(width * 0.2, height * 0.9);
    potPath.quadraticBezierTo(
      width * 0.2,
      height * 0.95,
      width * 0.25,
      height * 0.95,
    );
    potPath.lineTo(width * 0.75, height * 0.95);
    potPath.quadraticBezierTo(
      width * 0.8,
      height * 0.95,
      width * 0.8,
      height * 0.9,
    );
    potPath.lineTo(width * 0.75, height * 0.55);
    potPath.close();
    canvas.drawPath(potPath, potPaint);

    // Pot rim
    final rimPaint = Paint()
      ..color = potColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(width * 0.2, height * 0.52, width * 0.6, height * 0.06),
      rimPaint,
    );

    // Soil
    final soilPaint = Paint()
      ..color = soilColor
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(width * 0.24, height * 0.54, width * 0.52, height * 0.05),
      soilPaint,
    );

    // Stem
    final stemPaint = Paint()
      ..color = stemColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final stemPath = Path();
    stemPath.moveTo(width * 0.48, height * 0.56);
    stemPath.lineTo(width * 0.48, height * 0.25);
    stemPath.lineTo(width * 0.52, height * 0.25);
    stemPath.lineTo(width * 0.52, height * 0.56);
    stemPath.close();
    canvas.drawPath(stemPath, stemPaint);

    // Leaves - Bottom pair (left)
    _drawLeaf(
      canvas,
      width * 0.35,
      height * 0.48,
      -30,
      width * 0.15,
      leavesColor,
    );
    // Leaves - Bottom pair (right)
    _drawLeaf(
      canvas,
      width * 0.65,
      height * 0.48,
      30,
      width * 0.15,
      leavesColor,
    );

    // Leaves - Middle pair (left)
    _drawLeaf(
      canvas,
      width * 0.32,
      height * 0.38,
      -35,
      width * 0.16,
      leavesColor,
    );
    // Leaves - Middle pair (right)
    _drawLeaf(
      canvas,
      width * 0.68,
      height * 0.38,
      35,
      width * 0.16,
      leavesColor,
    );

    // Leaves - Top pair (left)
    _drawLeaf(
      canvas,
      width * 0.38,
      height * 0.28,
      -25,
      width * 0.14,
      leavesColor,
    );
    // Leaves - Top pair (right)
    _drawLeaf(
      canvas,
      width * 0.62,
      height * 0.28,
      25,
      width * 0.14,
      leavesColor,
    );

    // Top leaf (center)
    _drawLeaf(canvas, width * 0.5, height * 0.15, 0, width * 0.12, leavesColor);
  }

  void _drawLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double size,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle * 3.14159 / 180);

    // Leaf shape
    final leafPath = Path();
    leafPath.moveTo(0, -size * 0.5);
    leafPath.quadraticBezierTo(size * 0.4, -size * 0.3, size * 0.5, 0);
    leafPath.quadraticBezierTo(size * 0.4, size * 0.3, 0, size * 0.5);
    leafPath.quadraticBezierTo(-size * 0.4, size * 0.3, -size * 0.5, 0);
    leafPath.quadraticBezierTo(-size * 0.4, -size * 0.3, 0, -size * 0.5);
    leafPath.close();

    canvas.drawPath(leafPath, paint);

    // Center vein
    canvas.drawLine(Offset(0, -size * 0.4), Offset(0, size * 0.4), strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
