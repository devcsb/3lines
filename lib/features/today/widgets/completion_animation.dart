import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';

/// Full-screen celebration shown after first save of the day.
/// Includes: particle burst, checkmark, motivational message, streak info.
class CompletionAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final int streak;
  final int emotion;

  const CompletionAnimation({
    super.key,
    this.onComplete,
    this.streak = 0,
    this.emotion = 3,
  });

  @override
  State<CompletionAnimation> createState() => _CompletionAnimationState();
}

class _CompletionAnimationState extends State<CompletionAnimation>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _particleController;
  late AnimationController _textController;

  late Animation<double> _checkDraw;
  late Animation<double> _checkScale;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  final _random = Random();
  late List<_Particle> _particles;

  static const _messagesByEmotion = <int, List<String>>{
    1: [
      '힘든 날도 기록하는 당신, 대단해요',
      '오늘의 감정을 솔직하게 마주했어요',
      '어려운 하루를 버텨낸 것만으로 충분해요',
    ],
    2: [
      '불안한 마음을 꺼내놓은 것, 용기 있는 일이에요',
      '글로 쓰면 조금 가벼워져요',
      '오늘의 감정을 기록한 당신, 괜찮아요',
    ],
    3: [
      '오늘도 나를 기록했어요',
      '작은 기록이 큰 변화를 만들어요',
      '하루를 마무리하는 가장 좋은 방법',
    ],
    4: [
      '평온한 하루를 잘 담아냈어요',
      '오늘의 나에게 한 걸음 더 가까이',
      '기록하는 당신, 충분히 멋져요',
    ],
    5: [
      '감사한 마음이 하루를 빛나게 해요',
      '오늘의 감사를 내일로 이어가요',
      '감사를 기록하는 사람이 행복해진대요',
    ],
  };

  late String _message;

  @override
  void initState() {
    super.initState();
    final messages =
        _messagesByEmotion[widget.emotion] ?? _messagesByEmotion[3]!;
    _message = messages[_random.nextInt(messages.length)];

    // Generate particles
    _particles = List.generate(20, (_) => _Particle.random(_random));

    // Checkmark animation (0 → 800ms)
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _checkDraw = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Particle animation (0 → 1200ms)
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Text fade-in (delayed 400ms, duration 500ms)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Fire haptic + particles + checkmark simultaneously
    HapticService.medium();
    unawaited(_checkController.forward());
    unawaited(_particleController.forward());

    // Text appears after checkmark settles
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    unawaited(_textController.forward());

    // Second haptic tick when text appears
    HapticService.light();

    // Hold the celebration for a moment, then dismiss
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) widget.onComplete?.call();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        AppColors.emotionColors[widget.emotion] ?? theme.colorScheme.primary;

    return GestureDetector(
      onTap: widget.onComplete,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Particle burst
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) => CustomPaint(
                size: const Size(280, 280),
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                  color: color,
                ),
              ),
            ),

            // Checkmark + text column
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Checkmark
                ScaleTransition(
                  scale: _checkScale,
                  child: AnimatedBuilder(
                    animation: _checkDraw,
                    builder: (context, _) => CustomPaint(
                      size: const Size(72, 72),
                      painter: _CheckmarkPainter(
                        progress: _checkDraw.value,
                        color: color,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Motivational message
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          _message,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.streak > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.streak}일 연속 기록 중',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          '탭하여 닫기',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Particle system ──────────────────────────────────────────────

class _Particle {
  final double angle; // radians
  final double speed; // 0.5 – 1.0
  final double size; // 3 – 7
  final double opacity; // 0.4 – 0.9

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.opacity,
  });

  factory _Particle.random(Random r) {
    return _Particle(
      angle: r.nextDouble() * 2 * pi,
      speed: 0.5 + r.nextDouble() * 0.5,
      size: 3 + r.nextDouble() * 4,
      opacity: 0.4 + r.nextDouble() * 0.5,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (final p in particles) {
      // Ease out: fast start, slow end
      final t = Curves.easeOut.transform(progress);
      final radius = maxRadius * t * p.speed;

      // Fade out in the second half
      final fadeOut = progress > 0.5
          ? 1.0 - ((progress - 0.5) / 0.5)
          : 1.0;

      final x = center.dx + cos(p.angle) * radius;
      final y = center.dy + sin(p.angle) * radius;

      final paint = Paint()
        ..color = color.withValues(alpha: p.opacity * fadeOut)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => progress != old.progress;
}

// ── Checkmark painter ────────────────────────────────────────────

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Circle background
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Circle border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Checkmark
    if (progress > 0) {
      final checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      final start = Offset(size.width * 0.28, size.height * 0.52);
      final mid = Offset(size.width * 0.44, size.height * 0.66);
      final end = Offset(size.width * 0.72, size.height * 0.36);

      path.moveTo(start.dx, start.dy);

      if (progress <= 0.4) {
        final t = progress / 0.4;
        path.lineTo(
          start.dx + (mid.dx - start.dx) * t,
          start.dy + (mid.dy - start.dy) * t,
        );
      } else {
        path.lineTo(mid.dx, mid.dy);
        final t = (progress - 0.4) / 0.6;
        path.lineTo(
          mid.dx + (end.dx - mid.dx) * t,
          mid.dy + (end.dy - mid.dy) * t,
        );
      }

      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      progress != old.progress || color != old.color;
}
