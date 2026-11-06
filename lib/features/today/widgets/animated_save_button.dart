import 'package:flutter/material.dart';

/// A steady save action: one answer is a complete entry, not a partial target.
class AnimatedSaveButton extends StatelessWidget {
  final int filledCount;
  final bool canSave;
  final bool isSaving;
  final bool isCancelling;
  final bool emotionSelected;
  final String guidanceMessage;
  final VoidCallback? onPressed;

  const AnimatedSaveButton({
    super.key,
    required this.filledCount,
    required this.canSave,
    required this.isSaving,
    this.isCancelling = false,
    required this.guidanceMessage,
    this.emotionSelected = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWorking = isSaving || isCancelling;
    final label = isSaving
        ? '오늘의 기록 저장 중'
        : isCancelling
        ? '수정 취소 중'
        : canSave
        ? (filledCount == 0
              ? '마음만 남기기, 선택한 감정 저장'
              : '이만큼 저장하기, 답변 $filledCount개 작성됨')
        : emotionSelected
        ? '답변을 하나 적으면 저장할 수 있어요'
        : '감정 선택 필요';

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              guidanceMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            enabled: canSave && !isWorking,
            liveRegion: isWorking,
            label: label,
            onTap: canSave && !isWorking ? () => onPressed?.call() : null,
            excludeSemantics: true,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: canSave && !isWorking ? () => onPressed?.call() : null,
              child: isWorking
                  ? Text(isSaving ? '저장하고 있어요' : '수정을 취소하고 있어요')
                  : Text(filledCount == 0 ? '마음만 남기기' : '이만큼 저장하기'),
            ),
          ),
        ],
      ),
    );
  }
}
