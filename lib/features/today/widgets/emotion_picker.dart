import 'package:flutter/material.dart';

import '../../../core/services/haptic_service.dart';
import '../../../core/theme/app_colors.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘의 감정',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(5, (index) {
            final value = index + 1;
            final isSelected = widget.selectedEmotion == value;
            final isAnimating = _animatingIndex == value;
            final color = AppColors.emotionColors[value]!;
            final icon = _icons[value]!;

            return Expanded(
              child: GestureDetector(
                onTap: widget.enabled
                    ? () {
                        HapticService.selection();
                        setState(() => _animatingIndex = value);
                        widget.onSelected(value);
                        Future.delayed(const Duration(milliseconds: 250), () {
                          if (mounted) {
                            setState(() => _animatingIndex = null);
                          }
                        });
                      }
                    : null,
                child: Semantics(
                  label:
                      '감정 선택: 5단계 중 $value (${AppColors.emotionLabels[value]})',
                  selected: isSelected,
                  child: AnimatedScale(
                    scale: isAnimating ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          width: isSelected ? 48 : 38,
                          height: isSelected ? 48 : 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? color
                                : color.withValues(alpha: 0.12),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : color.withValues(alpha: 0.3),
                              width: isSelected ? 2.0 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              icon,
                              size: isSelected ? 26 : 20,
                              color: isSelected
                                  ? Colors.white
                                  : color.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: isSelected
                                ? color
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontSize: isSelected ? 11 : 10,
                          ),
                          child: Text(AppColors.emotionLabels[value]!),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
