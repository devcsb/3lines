import 'package:flutter/material.dart';

class CompletionAnimation extends StatefulWidget {
  final VoidCallback? onComplete;

  const CompletionAnimation({super.key, this.onComplete});

  @override
  State<CompletionAnimation> createState() => _CompletionAnimationState();
}

class _CompletionAnimationState extends State<CompletionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _drawAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _drawAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) widget.onComplete?.call();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: AnimatedBuilder(
        animation: _drawAnimation,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(80, 80),
            painter: _CheckmarkPainter(
              progress: _drawAnimation.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circle background
    final circlePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    // Draw circle border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw checkmark with progress
    if (progress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      // Checkmark points relative to center
      final start = Offset(size.width * 0.28, size.height * 0.52);
      final mid = Offset(size.width * 0.44, size.height * 0.66);
      final end = Offset(size.width * 0.72, size.height * 0.36);

      path.moveTo(start.dx, start.dy);

      // First stroke (down-right): 0.0 - 0.4 of progress
      if (progress <= 0.4) {
        final t = progress / 0.4;
        final x = start.dx + (mid.dx - start.dx) * t;
        final y = start.dy + (mid.dy - start.dy) * t;
        path.lineTo(x, y);
      } else {
        // First stroke complete, draw second stroke
        path.lineTo(mid.dx, mid.dy);
        final t = (progress - 0.4) / 0.6;
        final x = mid.dx + (end.dx - mid.dx) * t;
        final y = mid.dy + (end.dy - mid.dy) * t;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
