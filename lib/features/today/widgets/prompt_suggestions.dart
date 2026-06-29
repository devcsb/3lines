import 'package:flutter/material.dart';

/// Tappable suggestion chips displayed below each prompt card
/// to reduce blank-page friction.
class PromptSuggestions extends StatelessWidget {
  final int promptIndex;
  final ValueChanged<String> onTap;

  const PromptSuggestions({
    super.key,
    required this.promptIndex,
    required this.onTap,
  });

  static const _suggestions = <int, List<String>>{
    // Gratitude (감사)
    0: [
      '맑은 날씨',
      '따뜻한 커피 한잔',
      '가족의 응원',
      '좋은 음악',
      '편안한 잠자리',
      '건강한 하루',
    ],
    // Acceptance (수용)
    1: [
      '긴장했지만 괜찮았다',
      '완벽하지 않아도 충분했다',
      '실수해도 배울 수 있었다',
      '지쳤지만 쉬어도 된다',
      '불안했지만 해냈다',
      '속상했지만 인정한다',
    ],
    // Intention (의도)
    2: [
      '침착한 사람',
      '작은 것에 감사하는 사람',
      '경청하는 사람',
      '여유 있는 사람',
      '건강을 챙기는 사람',
      '웃는 사람',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = _suggestions[promptIndex] ?? [];
    if (chips.isEmpty) return const SizedBox.shrink();

    // 최소 48dp 탭 타깃 확보: 시각 칩은 compact 유지하고 투명 외곽으로 히트영역 확장.
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return Semantics(
            button: true,
            label: chips[index],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(chips[index]),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    chips[index],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
