import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_motion.dart';

/// Save button with a circular progress ring showing writing completion (0/3 → 3/3).
class AnimatedSaveButton extends StatelessWidget {
  final int filledCount; // 0–3: how many prompts have answers
  final bool canSave;
  final bool isSaving;
  final bool isCancelling;
  final bool emotionSelected;
  final String guidanceMessage;
  final VoidCallback? onPressed;

  const AnimatedSaveButton({
    super.key,
    required this.filledCount,
    required this.canSave,
    required this.isSaving,
    this.isCancelling = false,
    required this.guidanceMessage,
    this.emotionSelected = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = filledCount / 3.0;
    final isWorking = isSaving || isCancelling;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            guidanceMessage,
            style: theme.textTheme.bodySmall?.copyWith(
              color: canSave
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Mini progress ring
              _ProgressRing(
                progress: progress,
                color: theme.colorScheme.primary,
                filledCount: filledCount,
              ),
              const SizedBox(width: 14),

              // Main button
              Expanded(
                child: Semantics(
                  button: true,
                  enabled: canSave && !isWorking,
                  liveRegion: isWorking,
                  label: isSaving
                      ? '오늘의 기록 저장 중'
                      : (isCancelling
                            ? '수정 취소 중'
                            : (canSave
                                  ? '오늘의 기록 저장하기, 저장 가능, 답변 $filledCount/3줄 작성됨'
                                  : (emotionSelected
                                        ? '답변 $filledCount/3줄 작성 중'
                                        : '감정 선택 필요'))),
                  child: ElevatedButton(
                    onPressed: canSave && !isWorking
                        ? () {
                            HapticService.medium();
                            onPressed?.call();
                          }
                        : null,
                    child: isWorking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            canSave
                                ? '기록 완료'
                                : (emotionSelected
                                      ? '답변을 작성해주세요'
                                      : '감정을 선택해주세요'),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color color;
  final int filledCount;

  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.filledCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressDuration = AppMotion.durationFor(context, AppMotion.standard);
    final countDuration = AppMotion.durationFor(context, AppMotion.micro);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: progressDuration,
            curve: AppMotion.standardCurve,
            builder: (context, value, _) => CustomPaint(
              size: const Size(44, 44),
              painter: _RingPainter(
                progress: value,
                activeColor: color,
                trackColor: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
            ),
          ),

          // Count text
          AnimatedSwitcher(
            duration: countDuration,
            child: Text(
              '$filledCount/3',
              key: ValueKey(filledCount),
              style: theme.textTheme.labelMedium?.copyWith(
                color: filledCount > 0
                    ? color
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Active arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -pi / 2, // start from top
        2 * pi * progress,
        false,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      progress != old.progress || activeColor != old.activeColor;
}
