import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';

class QuestionsSection extends ConsumerWidget {
  const QuestionsSection({super.key, required this.prompts});

  final List<String> prompts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('질문 설정',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const Divider(),
        ...List.generate(3, (index) {
          return Semantics(
            label: '질문 ${index + 1} 수정: ${prompts[index]}',
            child: ListTile(
              title: Text('질문 ${index + 1}'),
              subtitle: Text(
                prompts[index],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _showPromptEditor(context, ref, index, prompts[index]),
            ),
          );
        }),
        Semantics(
          label: '모든 질문을 기본값으로 초기화',
          child: ListTile(
            title: const Text('기본값으로 초기화'),
            leading: const Icon(Icons.restore),
            onTap: () => _confirmReset(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('질문 초기화'),
        content: const Text('모든 질문을 기본값으로 되돌릴까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(settingsControllerProvider.notifier).resetPrompts();
    }
  }

  void _showPromptEditor(
      BuildContext context, WidgetRef ref, int index, String current) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('질문 ${index + 1} 수정'),
        content: TextFormField(
          controller: controller,
          maxLength: 100,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(settingsControllerProvider.notifier)
                  .updatePrompt(index, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
}
