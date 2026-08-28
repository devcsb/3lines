import 'package:flutter/material.dart';

import '../../../core/constants/default_prompts.dart';
import '../../../core/theme/app_motion.dart';

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
  final _focusNode = FocusNode();
  bool _isFocused = false;

  // Accent colors per category (감사, 수용, 의도)
  static const _accentColors = [
    Color(0xFF5B8A6A), // sage green – gratitude
    Color(0xFFC49A6A), // warm sand – acceptance
    Color(0xFF6B8A8A), // muted teal – intention
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.answer);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(PromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.answer != widget.answer &&
        _controller.text != widget.answer) {
      _controller.text = widget.answer;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final standardDuration = AppMotion.durationFor(context, AppMotion.standard);
    final category = widget.index < promptCategories.length
        ? promptCategories[widget.index]
        : null;
    final label = category?.label ?? '';
    final accent = _accentColors[widget.index.clamp(0, 2)];

    return AnimatedContainer(
      duration: standardDuration,
      curve: AppMotion.standardCurve,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFocused
              ? accent.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left accent bar — widens on focus
          AnimatedContainer(
            duration: standardDuration,
            curve: AppMotion.standardCurve,
            width: _isFocused ? 5 : 4,
            constraints: const BoxConstraints(minHeight: 100),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _isFocused ? 1.0 : 0.7),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label.isNotEmpty)
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    widget.question,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.85,
                      ),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: standardDuration,
                    switchInCurve: AppMotion.standardCurve,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0, 0.06),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    child: widget.readOnly
                        ? Padding(
                            key: const ValueKey('read'),
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.answer.isEmpty ? '—' : widget.answer,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: widget.answer.isEmpty ? 0.3 : 0.7,
                                ),
                              ),
                            ),
                          )
                        : Semantics(
                            key: const ValueKey('edit'),
                            label: '${widget.question} 답변 입력',
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              minLines: 2,
                              maxLines: 4,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                              scrollPadding: const EdgeInsets.only(bottom: 120),
                              // 마지막 프롬프트는 done, 나머지는 next로 다음 필드 이동
                              textInputAction: widget.index < 2
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              decoration: InputDecoration(
                                hintText: '여기에 적어주세요...',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                // 포커스 시에만 글자 수 카운터 표시
                                counterText: _isFocused ? null : '',
                                counterStyle: theme.textTheme.bodySmall
                                    ?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.3),
                                    ),
                              ),
                              onChanged: widget.onChanged,
                              onSubmitted: (_) {
                                if (widget.index < 2) {
                                  // 다음 프롬프트 카드의 TextField로 포커스 이동
                                  FocusScope.of(context).nextFocus();
                                } else {
                                  // 마지막 프롬프트: 키보드 닫기
                                  FocusScope.of(context).unfocus();
                                }
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
