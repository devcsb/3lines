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
        Text(
          '질문 설정',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
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
              onTap: () => _showPromptEditor(context, index, prompts[index]),
            ),
          );
        }),
        Semantics(
          label: '모든 질문을 기본값으로 초기화',
          child: ListTile(
            title: const Text('기본값으로 초기화'),
            leading: const Icon(Icons.restore),
            onTap: () => _confirmReset(context),
          ),
        ),
      ],
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _PromptResetDialog(),
    );
  }

  void _showPromptEditor(BuildContext context, int index, String current) {
    showDialog<void>(
      context: context,
      builder: (_) => _PromptEditorDialog(index: index, current: current),
    );
  }
}

class _PromptEditorDialog extends ConsumerStatefulWidget {
  const _PromptEditorDialog({required this.index, required this.current});

  final int index;
  final String current;

  @override
  ConsumerState<_PromptEditorDialog> createState() =>
      _PromptEditorDialogState();
}

class _PromptEditorDialogState extends ConsumerState<_PromptEditorDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = '질문을 한 글자 이상 입력해주세요.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(settingsControllerProvider.notifier)
          .updatePrompt(widget.index, text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '저장하지 못했어요. 입력을 유지했으니 다시 저장해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsControllerProvider);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text('질문 ${widget.index + 1} 수정'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              enabled: !_saving,
              maxLength: 100,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '질문',
                border: const OutlineInputBorder(),
                errorText: _error,
                errorMaxLines: 4,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            const Text('변경한 질문은 다음 새 초안부터 사용해요. 작성 중인 초안은 그대로 유지해요.'),
            if (_saving) ...[const SizedBox(height: 8), const Text('질문 저장 중…')],
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : _save,
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _PromptResetDialog extends ConsumerStatefulWidget {
  const _PromptResetDialog();

  @override
  ConsumerState<_PromptResetDialog> createState() => _PromptResetDialogState();
}

class _PromptResetDialogState extends ConsumerState<_PromptResetDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _reset() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(settingsControllerProvider.notifier).resetPrompts();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '초기화하지 못했어요. 질문은 그대로 유지했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsControllerProvider);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: const Text('질문 초기화'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '모든 질문을 기본값으로 되돌릴까요? 다음 새 초안부터 사용하고 작성 중인 초안은 그대로 유지해요.',
            ),
            if (_saving) ...[
              const SizedBox(height: 8),
              const Text('질문 초기화 중…'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(_error!)),
            ],
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: _saving ? null : _reset,
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}
