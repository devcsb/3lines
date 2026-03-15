import 'package:flutter/material.dart';

import '../../../core/constants/default_prompts.dart';

class PromptCard extends StatefulWidget {
  final int index;
  final String question;
  final String answer;
  final bool readOnly;
  final ValueChanged<String>? onChanged;

  const PromptCard({
    super.key,
    required this.index,
    required this.question,
    this.answer = '',
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<PromptCard> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.answer);
  }

  @override
  void didUpdateWidget(PromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update controller text if the answer changed externally
    // (e.g. switching to edit mode with existing data)
    // but not while user is actively typing
    if (oldWidget.answer != widget.answer &&
        _controller.text != widget.answer) {
      _controller.text = widget.answer;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = widget.index < promptCategories.length
        ? promptCategories[widget.index]
        : '';
    final label = promptCategoryLabels[category] ?? '';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label.isNotEmpty)
              Chip(
                label: Text(label),
                labelStyle: theme.textTheme.labelSmall,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            const SizedBox(height: 8),
            Text(
              widget.question,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.readOnly)
              Text(
                widget.answer.isEmpty ? '-' : widget.answer,
                style: theme.textTheme.bodyLarge,
              )
            else
              TextField(
                controller: _controller,
                maxLines: 2,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: '여기에 적어주세요...',
                  border: InputBorder.none,
                  counterStyle: theme.textTheme.bodySmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                onChanged: widget.onChanged,
              ),
          ],
        ),
      ),
    );
  }
}
