import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/models/entry_import.dart';
import '../settings_controller.dart';
import 'import_preview_dialog.dart';

class DataSection extends ConsumerStatefulWidget {
  const DataSection({super.key, this.pickImportBytes});

  final Future<Uint8List?> Function()? pickImportBytes;

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<DataSection> {
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '데이터',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const Divider(),
        Semantics(
          label: '텍스트 기록 내보내기 (JSON), 사진 파일은 백업에 포함되지 않아요',
          child: ListTile(
            title: const Text('텍스트 기록 내보내기 (JSON)'),
            subtitle: const Text('사진 파일은 백업에 포함되지 않아요'),
            leading: const Icon(Icons.file_download),
            onTap: () => _exportData(context, ref),
          ),
        ),
        Semantics(
          label: 'JSON 파일에서 데이터 가져오기',
          child: ListTile(
            title: const Text('텍스트 기록 가져오기 (JSON)'),
            leading: const ExcludeSemantics(child: Icon(Icons.file_upload)),
            enabled: !_importing,
            trailing: _importing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  )
                : null,
            onTap: _importing ? null : _importData,
          ),
        ),
        Semantics(
          label: '모든 기록 데이터 삭제',
          child: ListTile(
            title: Text(
              '모든 데이터 삭제',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            onTap: () => _showDeleteConfirmation(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref
          .read(settingsControllerProvider.notifier)
          .exportData();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final fileName =
          '3lines_export_${DateTime.now().millisecondsSinceEpoch}.json';
      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                name: fileName,
                mimeType: 'application/json',
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('내보내기에 실패했어요')));
      }
    }
  }

  Future<Uint8List?> _pickBytes() async {
    if (widget.pickImportBytes != null) return widget.pickImportBytes!();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) throw const FormatException('파일 읽기 오류');
    return bytes;
  }

  Future<void> _importData() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final bytes = await _pickBytes();
      if (!mounted || bytes == null) return;
      final controller = ref.read(settingsControllerProvider.notifier);
      final preview = await controller.previewImport(utf8.decode(bytes));
      if (!mounted) return;
      final result = await showDialog<ImportResult>(
        context: context,
        builder: (_) => ImportPreviewDialog(
          preview: preview,
          onApply: (policy) {
            if (!mounted) throw StateError('가져오기 화면 종료');
            return controller.applyImport(preview, policy: policy);
          },
        ),
      );
      if (!mounted || result == null) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('가져오기 결과'),
          scrollable: true,
          content: Text(
            '신규 ${result.inserted}개\n교체 ${result.replaced}개\n'
            '충돌 보존 ${result.conflictSkipped}개\n변경 후 보존 ${result.changedSincePreview}개\n'
            '유효하지 않음 ${result.invalid}개\n중복 ${result.duplicate}개'
            '${result.changedSincePreview > 0 ? '\n확인 뒤 바뀐 기록은 보존했어요. 새 미리보기로 확인해 주세요' : ''}',
          ),
          actions: [
            TextButton(
              style: const ButtonStyle(
                minimumSize: WidgetStatePropertyAll(Size(48, 48)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('잘못된 파일 형식이에요')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가져오기에 실패했어요. 다시 시도해 주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정말 삭제하시겠어요?'),
        scrollable: true,
        content: const Text(
          '기록을 삭제하면 앱에서 되돌릴 수 없어요.\n'
          '사용 중이거나 안전하게 삭제할 수 없는 사진 파일은 남을 수 있어요.\n'
          '확인하려면 "삭제"를 입력하세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '다음',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        _showDeleteInput(context, ref);
      }
    });
  }

  void _showDeleteInput(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _DeleteInputDialog(
        onDelete: () async {
          final success = await ref
              .read(settingsControllerProvider.notifier)
              .deleteAllData();
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success ? '기록을 삭제했어요. 일부 사진 파일은 남을 수 있어요.' : '데이터 삭제에 실패했어요',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Stateful dialog that enables the delete button only when "삭제" is typed.
class _DeleteInputDialog extends StatefulWidget {
  final VoidCallback onDelete;

  const _DeleteInputDialog({required this.onDelete});

  @override
  State<_DeleteInputDialog> createState() => _DeleteInputDialogState();
}

class _DeleteInputDialogState extends State<_DeleteInputDialog> {
  late final TextEditingController _controller;
  bool _canDelete = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final matches = _controller.text == '삭제';
    if (matches != _canDelete) {
      setState(() => _canDelete = matches);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleDelete() {
    if (_deleting) return;
    setState(() => _deleting = true);
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('삭제 확인'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '"삭제"를 입력하세요',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _canDelete && !_deleting ? _handleDelete : null,
          child: Text(
            '삭제',
            style: TextStyle(
              color: _canDelete && !_deleting
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}
