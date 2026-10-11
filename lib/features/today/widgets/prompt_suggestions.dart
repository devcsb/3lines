import 'package:flutter/material.dart';
import 'prompt_help.dart';

/// Tappable suggestion chips displayed below each prompt card
/// to reduce blank-page friction.
class PromptSuggestions extends StatelessWidget {
  final int promptIndex;
  final String question;
  final ValueChanged<String> onTap;

  const PromptSuggestions({
    super.key,
    required this.promptIndex,
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chips = examplesByQuestion[question] ?? const <String>[];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final example in chips)
            Semantics(
              button: true,
              label: "답변에 '$example' 추가",
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  foregroundColor: theme.colorScheme.onSurface,
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                ),
                onPressed: () => onTap(example),
                child: ExcludeSemantics(child: Text(example)),
              ),
            ),
        ],
      ),
    );
  }
}
