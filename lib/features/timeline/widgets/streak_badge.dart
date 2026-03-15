import 'package:flutter/material.dart';

class StreakBadge extends StatefulWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakBadge({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _streakAnimation;
  late Animation<int> _longestAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    _streakAnimation = IntTween(
      begin: 0,
      end: widget.currentStreak,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ));
    _longestAnimation = IntTween(
      begin: 0,
      end: widget.longestStreak,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.decelerate,
    ));
  }

  @override
  void didUpdateWidget(StreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStreak != widget.currentStreak ||
        oldWidget.longestStreak != widget.longestStreak) {
      _setupAnimations();
      _controller.forward(from: 0);
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

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_streakAnimation.value}일',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '현재 연속',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '최장 ${_longestAnimation.value}일',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
