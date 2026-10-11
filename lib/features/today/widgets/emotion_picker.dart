import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';

class EmotionPicker extends StatefulWidget {
  final int? selectedEmotion;
  final ValueChanged<int> onSelected;
  final bool enabled;

  const EmotionPicker({
    super.key,
    this.selectedEmotion,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  State<EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<EmotionPicker> {
  int? _animatingIndex;

  static const _icons = <int, IconData>{
    1: Icons.sentiment_very_dissatisfied_rounded,
    2: Icons.sentiment_dissatisfied_rounded,
    3: Icons.sentiment_neutral_rounded,
    4: Icons.sentiment_satisfied_alt_rounded,
    5: Icons.sentiment_very_satisfied_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final microDuration = AppMotion.durationFor(context, AppMotion.micro);
    final standardDuration = AppMotion.durationFor(context, AppMotion.standard);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘의 감정',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(12) > 20;
            final columns = largeText && constraints.maxWidth < 480
                ? 3
                : (constraints.maxWidth / 56).floor().clamp(1, 5);
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(5, (index) {
                final value = index + 1;
                final isSelected = widget.selectedEmotion == value;
                final isAnimating = _animatingIndex == value;
                final color = AppColors.emotionColors[value]!;
                final icon = _icons[value]!;
                final selectedForeground = color.computeLuminance() > .179
                    ? Colors.black
                    : Colors.white;

                return SizedBox(
                  width: width,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Semantics(
                      button: true,
                      enabled: widget.enabled,
                      label:
                          '감정 선택: 5단계 중 $value (${AppColors.emotionLabels[value]})',
                      selected: isSelected,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 76),
                            padding: EdgeInsets.zero,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            animationDuration: microDuration,
                          ),
                          onPressed: widget.enabled
                              ? () {
                                  HapticService.selection();
                                  final reduceMotion = AppMotion.reduceMotion(
                                    context,
                                  );
                                  setState(
                                    () => _animatingIndex = reduceMotion
                                        ? null
                                        : value,
                                  );
                                  widget.onSelected(value);
                                  if (reduceMotion) return;
                                  Future.delayed(
                                    const Duration(milliseconds: 250),
                                    () {
                                      // 250ms 안에 다른 감정을 다시 탭하면 그 탭이
                                      // _animatingIndex 를 바꾸므로, 이 콜백은 자기
                                      // value 가 아직 애니메이션 중일 때만 리셋한다.
                                      if (mounted && _animatingIndex == value) {
                                        setState(() => _animatingIndex = null);
                                      }
                                    },
                                  );
                                }
                              : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 76),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: AnimatedOpacity(
                                opacity: widget.enabled ? 1.0 : 0.55,
                                duration: microDuration,
                                child: AnimatedScale(
                                  scale: isAnimating ? 1.12 : 1.0,
                                  duration: microDuration,
                                  curve: AppMotion.standardCurve,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          AnimatedContainer(
                                            duration: standardDuration,
                                            curve: AppMotion.standardCurve,
                                            width: isSelected ? 48 : 40,
                                            height: isSelected ? 48 : 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? color
                                                  : color.withValues(
                                                      alpha: 0.12,
                                                    ),
                                              border: Border.all(
                                                color: isSelected
                                                    ? color
                                                    : color.withValues(
                                                        alpha: 0.3,
                                                      ),
                                                width: isSelected ? 2.0 : 1.5,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: color.withValues(
                                                          alpha: 0.35,
                                                        ),
                                                        blurRadius: 10,
                                                        spreadRadius: 1,
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Center(
                                              child: Icon(
                                                icon,
                                                size: isSelected ? 26 : 21,
                                                color: isSelected
                                                    ? selectedForeground
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              right: -4,
                                              bottom: -4,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color:
                                                      theme.colorScheme.surface,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: ExcludeSemantics(
                                                  child: Icon(
                                                    Icons.check_rounded,
                                                    size: 18,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedDefaultTextStyle(
                                        duration: microDuration,
                                        style: theme.textTheme.labelSmall!
                                            .copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.normal,
                                            ),
                                        child: Text(
                                          AppColors.emotionLabels[value]!,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
