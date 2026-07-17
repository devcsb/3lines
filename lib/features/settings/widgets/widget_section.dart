import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

class WidgetSection extends StatelessWidget {
  const WidgetSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _installSteps();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '홈 화면 위젯',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.widgets_outlined,
            color: theme.colorScheme.primary,
          ),
          title: const Text('오늘 질문 · 스트릭 · 빠른 감정'),
          subtitle: Text(
            '홈 화면에 위젯을 추가하면 앱을 열지 않고도 '
            '오늘 기록 상태와 질문을 볼 수 있어요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
        const SizedBox(height: 4),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final text = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        Text(
          '감정 칩을 누르면 앱의 오늘 화면이 열리고 감정이 미리 선택됩니다. '
          '저장은 앱에서 한 줄 이상 작성한 뒤 완료하세요.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  List<String> _installSteps() {
    if (kIsWeb) {
      return const ['모바일 앱에서 홈 화면 위젯을 사용할 수 있어요.'];
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const [
          '홈 화면을 길게 누른 뒤 왼쪽 위 + 를 탭하세요.',
          '검색에서 3Lines 또는 Three Lines를 찾으세요.',
          '작은/중간 위젯을 골라 추가하세요.',
        ];
      case TargetPlatform.android:
        return const [
          '홈 화면을 길게 누르고 위젯을 선택하세요.',
          '3Lines 위젯을 찾아 홈 화면에 놓으세요.',
          '중간 크기에서 감정 빠른 선택이 보입니다.',
        ];
      default:
        return const [
          'iOS 또는 Android 기기에서 홈 화면 위젯을 추가할 수 있어요.',
        ];
    }
  }
}
