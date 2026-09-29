import 'package:flutter/material.dart';

import '../../../data/models/entry_import.dart';

class ImportPreviewDialog extends StatefulWidget {
  const ImportPreviewDialog({
    super.key,
    required this.preview,
    required this.onApply,
  });

  final ImportPreview preview;
  final Future<ImportResult> Function(ConflictPolicy) onApply;

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog> {
  bool _applying = false;
  bool _completed = false;
  bool _replace = false;
  String? _error;

  Future<void> _apply() async {
    if (_applying || _completed) return;
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final result = await widget.onApply(
        _replace ? ConflictPolicy.replacePreviewed : ConflictPolicy.preserve,
      );
      _completed = true;
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted)
        setState(() {
          _applying = false;
          _error = '가져오기에 실패했어요. 다시 시도해 주세요';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;
    const buttonStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(48, 48)),
    );
    return PopScope(
      canPop: !_applying,
      child: AlertDialog(
        title: const Text('가져오기 미리보기'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '신규 ${preview.newCount}개\n충돌 ${preview.conflictCount}개\n유효하지 않음 ${preview.parsed.invalid}개\n중복 ${preview.parsed.duplicate}개',
              ),
              const SizedBox(height: 16),
              const Text('사진 파일은 포함되지 않아요'),
              if (preview.conflictCount > 0) ...[
                const SizedBox(height: 16),
                const Text('충돌 날짜'),
                for (final date in preview.conflicts.keys) Text(date),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('미리보기 충돌 기록의 텍스트를 교체해요. 기존 사진은 유지돼요'),
                  value: _replace,
                  onChanged: _applying
                      ? null
                      : (value) => setState(() => _replace = value ?? false),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (_applying) ...[
                const SizedBox(height: 16),
                Semantics(liveRegion: true, child: const Text('가져오는 중이에요')),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            style: buttonStyle,
            onPressed: _applying ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            style: buttonStyle,
            onPressed: _applying || _completed ? null : _apply,
            child: Text(_error == null ? '가져오기' : '다시 시도'),
          ),
        ],
      ),
    );
  }
}
