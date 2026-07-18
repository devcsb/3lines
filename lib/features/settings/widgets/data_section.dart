import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../settings_controller.dart';

class DataSection extends ConsumerWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('데이터',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const Divider(),
        Semantics(
          label: '데이터를 JSON 파일로 내보내기',
          child: ListTile(
            title: const Text('데이터 내보내기 (JSON)'),
            leading: const Icon(Icons.file_download),
            onTap: () => _exportData(context, ref),
          ),
        ),
        Semantics(
          label: 'JSON 파일에서 데이터 가져오기',
          child: ListTile(
            title: const Text('데이터 가져오기 (JSON)'),
            leading: const Icon(Icons.file_upload),
            onTap: () => _importData(context, ref),
          ),
        ),
        Semantics(
          label: '모든 기록 데이터 삭제',
          child: ListTile(
            title: Text('모든 데이터 삭제',
                style: TextStyle(color: theme.colorScheme.error)),
            leading:
                Icon(Icons.delete_forever, color: theme.colorScheme.error),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('내보내기에 실패했어요')),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;

      final fileBytes = result.files.single.bytes;
      if (fileBytes == null) return;

      final jsonStr = utf8.decode(fileBytes);

      if (!context.mounted) return;

      final importResult = await ref
          .read(settingsControllerProvider.notifier)
          .importData(jsonStr);

      if (context.mounted) {
        final message = importResult.skipped > 0
            ? '${importResult.imported}개 가져옴 (${importResult.skipped}개 건너뜀)'
            : '${importResult.imported}개의 기록을 가져왔어요';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } on FormatException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('잘못된 파일 형식이에요: ${e.message}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가져오기에 실패했어요')),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정말 삭제하시겠어요?'),
        content: const Text(
            '모든 기록이 영구적으로 삭제됩니다.\n확인하려면 "삭제"를 입력하세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('다음',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
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
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => _DeleteInputDialog(
        controller: controller,
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
                content: Text(success
                    ? '모든 데이터가 삭제되었어요'
                    : '데이터 삭제에 실패했어요'),
              ),
            );
          }
        },
      ),
    ).then((_) => controller.dispose());
  }
}

/// Stateful dialog that enables the delete button only when "삭제" is typed.
class _DeleteInputDialog extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onDelete;

  const _DeleteInputDialog({
    required this.controller,
    required this.onDelete,
  });

  @override
  State<_DeleteInputDialog> createState() => _DeleteInputDialogState();
}

class _DeleteInputDialogState extends State<_DeleteInputDialog> {
  bool _canDelete = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final matches = widget.controller.text == '삭제';
    if (matches != _canDelete) {
      setState(() => _canDelete = matches);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
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
        controller: widget.controller,
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
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}
