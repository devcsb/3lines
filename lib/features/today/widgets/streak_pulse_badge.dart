import 'package:flutter/material.dart';

import '../../../core/theme/app_motion.dart';

/// Streak badge with a subtle one-time glow emphasis.
/// The glow intensity increases with longer streaks without a continuous ticker.
class StreakPulseBadge extends StatefulWidget {
  final int streak;
  final bool usedGraceDay;

  const StreakPulseBadge({
    super.key,
    required this.streak,
    required this.usedGraceDay,
  });

  @override
  State<StreakPulseBadge> createState() => _StreakPulseBadgeState();
}

class _StreakPulseBadgeState extends State<StreakPulseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.celebration,
      vsync: this,
    );

    _glowAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: AppMotion.standardCurve),
        );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // reduce-motion(동작 줄이기) 설정이면 무한 펄스를 멈추고 정적으로 둔다.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0.0;
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      // 진입 시 한 번만 강조한다. 화면 체류 중 무한 ticker를 피해서 배터리와
      // 저사양 기기의 프레임 예산을 보존하고, reduced-motion에서는 위 분기로
      // 정적인 기본 상태를 유지한다.
      _controller.forward();
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
    final color = theme.colorScheme.primary;

    // Glow intensity scales with streak length
    final glowIntensity = (widget.streak / 30).clamp(0.15, 0.5);

    // RepaintBoundary: 배지의 매 프레임 glow repaint 가 Today 스크롤 콘텐츠
    // 전체로 번지지 않도록 페인트를 배지 레이어에 격리한다.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final glowAlpha = glowIntensity * _glowAnimation.value;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08 + glowAlpha * 0.12),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glowAlpha * 0.2),
                  blurRadius: 8 + glowAlpha * 8,
                  spreadRadius: glowAlpha * 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.streak}일 연속 기록 중',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.usedGraceDay) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: '유예일이 적용되었어요',
                child: Icon(
                  Icons.shield_rounded,
                  size: 14,
                  color: color.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
