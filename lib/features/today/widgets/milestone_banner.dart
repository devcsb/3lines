import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';

/// Animated celebration banner shown when a milestone is reached.
class MilestoneBanner extends StatefulWidget {
  final int milestone;
  final VoidCallback? onDismiss;

  const MilestoneBanner({
    super.key,
    required this.milestone,
    this.onDismiss,
  });

  @override
  State<MilestoneBanner> createState() => _MilestoneBannerState();
}

class _MilestoneBannerState extends State<MilestoneBanner> {
  @override
  void initState() {
    super.initState();
    HapticService.heavy();
  }

  int get milestone => widget.milestone;
  VoidCallback? get onDismiss => widget.onDismiss;

  String get _message => switch (milestone) {
        7 => '7일 연속 기록 달성!',
        30 => '30일 기록 달성!',
        100 => '100일 기록을 축하해요!',
        365 => '1년, 365일의 기록!',
        _ => '$milestone일 기록 달성!',
      };

  String get _subtitle => switch (milestone) {
        7 => '꾸준함의 시작이에요',
        30 => '한 달의 습관이 되었어요',
        100 => '대단한 여정이에요',
        365 => '당신의 1년이 여기 담겨 있어요',
        _ => '멋진 기록이에요',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onDismiss,
              child: Text(
                '확인',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
