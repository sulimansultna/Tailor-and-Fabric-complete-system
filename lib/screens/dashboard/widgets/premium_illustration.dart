import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small layered marks used on dashboard cards. Drawn in code so they stay
/// available offline and share one light direction.
enum PremiumMark {
  orders,
  ready,
  customers,
  suppliers,
  fabric,
  profit,
  payments,
  expenses,
  measurements,
  stitching,
  reports,
  delivery,
  shop,
}

class PremiumMarkIcon extends StatelessWidget {
  const PremiumMarkIcon({
    super.key,
    required this.mark,
    required this.accent,
    this.size = 48,
  });

  final PremiumMark mark;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _MarkPainter(mark: mark, accent: accent),
      child: const SizedBox.expand(),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.mark, required this.accent});

  final PremiumMark mark;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    _plate(canvas);
    _symbol(canvas);
    canvas.restore();
  }

  void _plate(Canvas canvas) {
    final shadow = Paint()
      ..color = accent.withValues(alpha: .32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2);
    canvas.drawOval(
      const Rect.fromLTWH(8, 38, 32, 8),
      shadow,
    );
    final depth = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 5, 38, 34),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      depth,
      Paint()..color = Color.lerp(accent, const Color(0xff0f172a), .28)!,
    );
    final face = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 3, 38, 34),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.white, .48)!,
            accent,
            Color.lerp(accent, const Color(0xff0f172a), .16)!,
          ],
        ).createShader(face.outerRect),
    );
    canvas.drawOval(
      const Rect.fromLTWH(10, 7, 14, 7),
      Paint()..color = Colors.white.withValues(alpha: .38),
    );
  }

  void _symbol(Canvas canvas) {
    switch (mark) {
      case PremiumMark.orders:
        _receipt(canvas);
      case PremiumMark.ready:
        _garment(canvas, checked: true);
      case PremiumMark.customers:
        _people(canvas);
      case PremiumMark.suppliers:
      case PremiumMark.shop:
        _storefront(canvas);
      case PremiumMark.fabric:
        _fabricRoll(canvas);
      case PremiumMark.profit:
        _bars(canvas, coin: true);
      case PremiumMark.payments:
        _coins(canvas);
      case PremiumMark.expenses:
        _wallet(canvas);
      case PremiumMark.measurements:
        _tape(canvas);
      case PremiumMark.stitching:
        _scissors(canvas);
      case PremiumMark.reports:
        _bars(canvas, coin: false);
      case PremiumMark.delivery:
        _calendar(canvas);
    }
  }

  void _receipt(Canvas canvas) {
    final paper = RRect.fromRectAndRadius(
      const Rect.fromLTWH(15, 9, 16, 20),
      const Radius.circular(2),
    );
    canvas.drawRRect(paper, Paint()..color = const Color(0xfff8fafc));
    final stitch = Paint()
      ..color = const Color(0xffb45309)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(18, 16), const Offset(28, 16), stitch);
    canvas.drawLine(const Offset(18, 20), const Offset(26, 20), stitch);
    canvas.drawLine(const Offset(18, 24), const Offset(27, 24), stitch);
    final thread = Path()
      ..moveTo(29, 12)
      ..quadraticBezierTo(36, 14, 33, 22);
    canvas.drawPath(
      thread,
      Paint()
        ..color = const Color(0xfffef3c7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  void _garment(Canvas canvas, {required bool checked}) {
    final cloth = Paint()..color = const Color(0xfff8fafc);
    final body = Path()
      ..moveTo(18, 14)
      ..lineTo(22, 12)
      ..lineTo(26, 14)
      ..lineTo(30, 18)
      ..lineTo(28, 28)
      ..lineTo(16, 28)
      ..lineTo(14, 18)
      ..close();
    canvas.drawPath(body, cloth);
    if (checked) {
      canvas.drawCircle(
        const Offset(32, 26),
        5.2,
        Paint()..color = const Color(0xff166534),
      );
      final check = Path()
        ..moveTo(29.4, 26)
        ..lineTo(31.2, 27.8)
        ..lineTo(34.6, 23.8);
      canvas.drawPath(
        check,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _people(Canvas canvas) {
    final back = Paint()..color = const Color(0xffe2e8f0);
    canvas.drawCircle(const Offset(20, 16), 4.2, back);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 21, 12, 9),
        const Radius.circular(5),
      ),
      back,
    );
    final front = Paint()..color = const Color(0xfff8fafc);
    canvas.drawCircle(const Offset(28, 15), 4.6, front);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 20.5, 13, 10),
        const Radius.circular(5),
      ),
      front,
    );
  }

  void _storefront(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 18, 22, 14),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xfff8fafc),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 13, 24, 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xfffef3c7),
    );
    canvas.drawRect(
      const Rect.fromLTWH(21, 22, 6, 10),
      Paint()..color = accent.withValues(alpha: .85),
    );
    canvas.drawRect(
      const Rect.fromLTWH(15, 22, 4, 5),
      Paint()..color = const Color(0xffbfdbfe),
    );
  }

  void _fabricRoll(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 16, 18, 12),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xfff8fafc),
    );
    canvas.drawOval(
      const Rect.fromLTWH(12, 14, 8, 16),
      Paint()..color = const Color(0xffe2e8f0),
    );
    canvas.drawOval(
      const Rect.fromLTWH(28, 14, 8, 16),
      Paint()..color = const Color(0xfffef3c7),
    );
    canvas.drawLine(
      const Offset(18, 20),
      const Offset(30, 20),
      Paint()
        ..color = accent.withValues(alpha: .55)
        ..strokeWidth = 1.2,
    );
  }

  void _bars(Canvas canvas, {required bool coin}) {
    final paint = Paint()..color = const Color(0xfff8fafc);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 22, 5, 10),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 17, 5, 15),
        const Radius.circular(1.5),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 12, 5, 20),
        const Radius.circular(1.5),
      ),
      paint,
    );
    if (coin) {
      canvas.drawCircle(
        const Offset(34, 14),
        4,
        Paint()..color = const Color(0xfffde68a),
      );
      canvas.drawCircle(
        const Offset(34, 14),
        2.1,
        Paint()
          ..color = const Color(0xffb45309)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _coins(Canvas canvas) {
    canvas.drawCircle(
      const Offset(20, 22),
      7,
      Paint()..color = const Color(0xfffde68a),
    );
    canvas.drawCircle(
      const Offset(28, 19),
      7,
      Paint()..color = const Color(0xfff8fafc),
    );
    canvas.drawCircle(
      const Offset(28, 19),
      3.4,
      Paint()
        ..color = const Color(0xffb45309)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _wallet(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 15, 22, 15),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xfff8fafc),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 15, 22, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xfffde68a),
    );
    canvas.drawCircle(
      const Offset(29, 24),
      2.2,
      Paint()..color = const Color(0xffb45309),
    );
  }

  void _tape(Canvas canvas) {
    final tape = Path()
      ..moveTo(14, 28)
      ..quadraticBezierTo(24, 8, 36, 18);
    canvas.drawPath(
      tape,
      Paint()
        ..color = const Color(0xfffef3c7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      tape,
      Paint()
        ..color = const Color(0xffb45309)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    for (final t in const [0.25, 0.5, 0.75]) {
      final point = _quad(const Offset(14, 28), const Offset(24, 8), const Offset(36, 18), t);
      canvas.drawCircle(point, 0.9, Paint()..color = const Color(0xff7c2d12));
    }
  }

  Offset _quad(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx,
      u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy,
    );
  }

  void _scissors(Canvas canvas) {
    canvas.save();
    canvas.translate(24, 20);
    canvas.rotate(-math.pi / 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -1.3, 16, 2.6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xfff8fafc),
    );
    canvas.drawCircle(const Offset(6, 0), 3.1, Paint()..color = const Color(0xfff8fafc));
    canvas.restore();
    canvas.save();
    canvas.translate(24, 22);
    canvas.rotate(math.pi / 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -1.3, 16, 2.6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xffe2e8f0),
    );
    canvas.drawCircle(const Offset(6, 0), 3.1, Paint()..color = const Color(0xffe2e8f0));
    canvas.restore();
    final thread = Path()
      ..moveTo(16, 14)
      ..quadraticBezierTo(22, 12, 30, 16);
    canvas.drawPath(
      thread,
      Paint()
        ..color = const Color(0xfffef3c7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _calendar(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 12, 20, 18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xfff8fafc),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 12, 20, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xfffde68a),
    );
    canvas.drawCircle(
      const Offset(24, 23),
      2.2,
      Paint()..color = accent.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.mark != mark || oldDelegate.accent != accent;
}
