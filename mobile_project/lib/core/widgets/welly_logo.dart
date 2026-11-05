import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Logo WELLY : maison sombre, W ivoire (tracé du composant web WellyLogo.vue).
class WellyLogo extends StatelessWidget {
  const WellyLogo({super.key, this.size = 28, this.wordmark = false});

  final double size;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(size < 28 ? 3.6 : 2.6)),
    );
    if (!wordmark) return Semantics(label: 'WELLY', child: mark);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.35),
        Text(
          'WELLY',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: size * 0.6,
            letterSpacing: size * 0.12,
            color: WellyColors.ink,
          ),
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.strokeWidth);
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    final house = Path()
      ..moveTo(24, 3)
      ..lineTo(45, 20)
      ..lineTo(45, 41)
      ..arcToPoint(const Offset(41, 45), radius: const Radius.circular(4))
      ..lineTo(7, 45)
      ..arcToPoint(const Offset(3, 41), radius: const Radius.circular(4))
      ..lineTo(3, 20)
      ..close();
    canvas.drawPath(house, Paint()..color = WellyColors.ink);
    final w = Path()
      ..moveTo(12, 22)
      ..lineTo(17, 37)
      ..lineTo(24, 28)
      ..lineTo(31, 37)
      ..lineTo(36, 22);
    canvas.drawPath(
      w,
      Paint()
        ..color = WellyColors.ivoire
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.strokeWidth != strokeWidth;
}
