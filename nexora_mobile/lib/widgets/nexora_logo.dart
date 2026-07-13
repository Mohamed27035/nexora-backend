import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class NexoraLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final CrossAxisAlignment crossAxisAlignment;

  const NexoraLogo({
    super.key,
    this.size = 72,
    this.showWordmark = true,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _NexoraMarkPainter(),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 14),
          const Text(
            "Nexora",
            style: TextStyle(
              color: AppColors.text,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _NexoraMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.accent],
      ).createShader(rect);

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.22));
    canvas.drawRRect(rrect, bgPaint);

    final shield = Path()
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..lineTo(size.width * 0.76, size.height * 0.3)
      ..lineTo(size.width * 0.69, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.83,
        size.width * 0.31,
        size.height * 0.68,
      )
      ..lineTo(size.width * 0.24, size.height * 0.3)
      ..close();

    canvas.drawPath(
      shield,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.94)
        ..style = PaintingStyle.fill,
    );

    final nPath = Path()
      ..moveTo(size.width * 0.36, size.height * 0.66)
      ..lineTo(size.width * 0.36, size.height * 0.37)
      ..lineTo(size.width * 0.64, size.height * 0.66)
      ..lineTo(size.width * 0.64, size.height * 0.37);

    canvas.drawPath(
      nPath,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final chartPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final chart = Path()
      ..moveTo(size.width * 0.28, size.height * 0.76)
      ..lineTo(size.width * 0.43, size.height * 0.61)
      ..lineTo(size.width * 0.54, size.height * 0.69)
      ..lineTo(size.width * 0.75, size.height * 0.47);
    canvas.drawPath(chart, chartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
