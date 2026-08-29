import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Locked view with animated progress ring and fade-in entrance.
class InsightsLockedView extends StatefulWidget {
  final int totalCount;
  final int requiredCount;
  final VoidCallback? onGoToToday;

  const InsightsLockedView({
    super.key,
    required this.totalCount,
    required this.requiredCount,
    this.onGoToToday,
  });

  @override
  State<InsightsLockedView> createState() => _InsightsLockedViewState();
}

class _InsightsLockedViewState extends State<InsightsLockedView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.entrance,
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: AppMotion.standardCurve),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: AppMotion.standardCurve),
      ),
    );
    final progress = (widget.totalCount / widget.requiredCount).clamp(0.0, 1.0);
    _progressAnimation = Tween<double>(begin: 0, end: progress).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: AppMotion.standardCurve),
      ),
    );
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: Transform.scale(scale: _scaleAnimation.value, child: child),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated progress ring with icon
              SizedBox(
                width: 96,
                height: 96,
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ProgressRingPainter(
                        progress: _progressAnimation.value,
                        color: theme.colorScheme.primary,
                        trackColor: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.4),
                      ),
                      child: child,
                    );
                  },
                  child: Center(
                    child: Icon(
                      Icons.auto_graph_rounded,
                      size: 36,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${widget.requiredCount}일 이상 기록하면\n인사이트가 열려요',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // Count label
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, _) {
                  final animatedCount =
                      (widget.totalCount *
                              _progressAnimation.value /
                              (widget.totalCount / widget.requiredCount).clamp(
                                0.01,
                                1.0,
                              ))
                          .clamp(0, widget.totalCount)
                          .round();
                  return Text(
                    '$animatedCount / ${widget.requiredCount}일',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              if (widget.onGoToToday != null) ...[
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: widget.onGoToToday,
                  child: const Text('오늘의 기록 쓰러 가기'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    const strokeWidth = 6.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      const startAngle = -1.5708; // -90 degrees (top)
      final sweepAngle = 2 * 3.14159 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
