import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final value = index + 1;
        final isSelected = widget.selectedEmotion == value;
        final isAnimating = _animatingIndex == value;

        return GestureDetector(
          onTap: widget.enabled
              ? () {
                  setState(() => _animatingIndex = value);
                  widget.onSelected(value);
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (mounted) setState(() => _animatingIndex = null);
                  });
                }
              : null,
          child: Semantics(
            label: '감정 선택: 5단계 중 $value (${AppColors.emotionLabels[value]})',
            selected: isSelected,
            child: AnimatedScale(
              scale: isAnimating ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.emotionColors[value]!.withValues(alpha: 0.2)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.emotionColors[value]!
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        AppColors.emotionEmojis[value]!,
                        style: TextStyle(
                          fontSize: 28,
                          color: isSelected ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppColors.emotionLabels[value]!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? AppColors.emotionColors[value]
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
