import 'package:flutter/material.dart';

import '../constants/design_feature_art.dart';

class DesignFeatureDrawing extends StatelessWidget {
  const DesignFeatureDrawing({super.key, required this.feature, this.color});

  final String feature;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(80, 60),
    painter: _DesignPainter(
      feature,
      color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}

class _DesignPainter extends CustomPainter {
  const _DesignPainter(this.feature, this.color);

  final String feature;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 80, size.height / 60);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in designFeatureStrokes(feature)) {
      final path = Path()..moveTo(stroke.first.$1, stroke.first.$2);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.$1, point.$2);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DesignPainter oldDelegate) =>
      oldDelegate.feature != feature || oldDelegate.color != color;
}
