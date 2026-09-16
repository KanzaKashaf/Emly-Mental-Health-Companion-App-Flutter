import 'dart:math';
import 'package:flutter/material.dart';

class SplashLoader extends StatefulWidget {
  final Color backgroundColor;

  const SplashLoader({super.key, required this.backgroundColor});

  @override
  State<SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<SplashLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: const Size(64, 64),
        painter: _LoaderPainter(
          backgroundColor: widget.backgroundColor,
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final Color backgroundColor;

  _LoaderPainter({required this.backgroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    /// Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, bgPaint);

    /// Inner curved stroke
    final arcPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    /// Arc positioning 
    final innerRadius = radius * 0.5;

    /// Angle tuning to match image
    const startAngle = pi * 0.15;
    const sweepAngle = pi * 0.3;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
