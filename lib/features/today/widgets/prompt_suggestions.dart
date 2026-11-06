import 'package:flutter/material.dart';
import '../../../core/constants/default_prompts.dart';
import 'prompt_help.dart';

/// Examples appear only on request and never replace an existing answer.
class PromptSuggestions extends StatefulWidget {
  final int promptIndex;
  final String? question;
  final ValueChanged<String> onTap;

  const PromptSuggestions({
    super.key,
    required this.promptIndex,
    this.question,
    required this.onTap,
  });

  @override
  State<PromptSuggestions> createState() => _PromptSuggestionsState();
}

class _PromptSuggestionsState extends State<PromptSuggestions> {
  bool _expanded = false;

  static const _suggestions = <int, List<String>>{
    0: ['사실 오늘은', '누군가에게 말하고 싶었던 건', '어디서부터 말해야 할지 모르겠지만'],
    1: ['지금은 지쳐 있다', '여러 마음이 함께 든다', '어떤 마음인지 아직 모르겠다'],
    2: ['잠깐 쉬고 싶다', '누군가 내 이야기를 들어주면 좋겠다', '지금은 정하지 않아도 된다'],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final examples =
        widget.question == null ||
            isBuiltInPrompt(widget.promptIndex, widget.question!)
        ? _suggestions[widget.promptIndex] ?? []
        : examplesByQuestion[widget.question] ?? [];
    if (examples.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _expanded,
          child: TextButton.icon(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            label: Text(_expanded ? '예시 접기' : '시작이 어렵다면 예시 보기'),
          ),
        ),
        if (_expanded)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: examples
                .map(
                  (example) => TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      backgroundColor: theme.colorScheme.surfaceContainerLow,
                      textStyle: theme.textTheme.bodyMedium,
                    ),
                    onPressed: () => widget.onTap(example),
                    child: Text(example, semanticsLabel: "답변에 '$example' 추가"),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
