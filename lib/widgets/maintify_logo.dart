import 'package:flutter/material.dart';

/// The Maintify brand logo — a geometric "M" (two towers + V-dip) with a
/// gold accent bar at the base. Renders cleanly at any size via CustomPainter.
///
/// Usage:
///   MaintifyLogo(size: 80)                   // white M on transparent
///   MaintifyLogo(size: 80, showBackground: true)  // with dark gradient bg
class MaintifyLogo extends StatelessWidget {
  final double size;

  /// When true, draws a rounded-square dark-navy gradient background
  /// (suitable for use as an app icon preview or stand-alone badge).
  final bool showBackground;

  const MaintifyLogo({
    super.key,
    this.size = 80,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(showBackground: showBackground)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool showBackground;
  const _LogoPainter({required this.showBackground});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background ────────────────────────────────────────────────────────────
    if (showBackground) {
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141E30), Color(0xFF243B55)],
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, w, h),
          Radius.circular(w * 0.22),
        ),
        bgPaint,
      );
    }

    // ── M shape ───────────────────────────────────────────────────────────────
    // Two vertical towers (left & right) connected at the top by a V-notch.
    // strokeWidth ≈ 11 % of size so it stays proportional.
    final mPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.114
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final mPath = Path()
      ..moveTo(w * 0.13, h * 0.82) // bottom-left
      ..lineTo(w * 0.13, h * 0.17) // top-left tower
      ..lineTo(w * 0.50, h * 0.54) // centre dip (V-notch)
      ..lineTo(w * 0.87, h * 0.17) // top-right tower
      ..lineTo(w * 0.87, h * 0.82); // bottom-right

    canvas.drawPath(mPath, mPaint);

    // ── Gold accent bar ───────────────────────────────────────────────────────
    // Sits just below the base of the M, spanning the full width of the towers.
    final accentPaint = Paint()
      ..color = const Color(0xFFFECB6E)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.13, h * 0.875, w * 0.74, h * 0.058),
        Radius.circular(h * 0.029),
      ),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.showBackground != showBackground;
}
