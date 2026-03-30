import 'package:flutter/material.dart';

/// Streak badge with a subtle breathing glow animation.
/// The glow intensity increases with longer streaks.
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
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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

    return AnimatedBuilder(
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
    );
  }
}
