import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('설정을 불러올 수 없어요'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(settingsControllerProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (state) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 16),
                Text('설정', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),

                // Section: Questions
                Text('질문 설정',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    )),
                const Divider(),
                ...List.generate(3, (index) {
                  return ListTile(
                    title: Text('질문 ${index + 1}'),
                    subtitle: Text(
                      state.prompts[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _showPromptEditor(
                        context, ref, index, state.prompts[index]),
                  );
                }),
                ListTile(
                  title: const Text('기본값으로 초기화'),
                  leading: const Icon(Icons.restore),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('질문 초기화'),
                        content:
                            const Text('모든 질문을 기본값으로 되돌릴까요?'),
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
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .resetPrompts();
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Section: Notifications
                Text('알림',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    )),
                const Divider(),
                SwitchListTile(
                  title: const Text('매일 리마인더'),
                  value: state.reminderEnabled,
                  onChanged: (v) async {
                    final success = await ref
                        .read(settingsControllerProvider.notifier)
                        .setReminderEnabled(v);
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('알림 설정에 실패했어요')),
                      );
                    }
                  },
                ),
                ListTile(
                  title: const Text('리마인더 시간'),
                  trailing: Text(
                    '${state.reminderHour.toString().padLeft(2, '0')}:${state.reminderMinute.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyLarge,
                  ),
                  enabled: state.reminderEnabled,
                  onTap: state.reminderEnabled
                      ? () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(
                              hour: state.reminderHour,
                              minute: state.reminderMinute,
                            ),
                          );
                          if (time != null) {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setReminderTime(time.hour, time.minute);
                          }
                        }
                      : null,
                ),

                const SizedBox(height: 16),

                // Section: Appearance
                Text('외관',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    )),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'system',
                        label: Text('시스템 기본'),
                      ),
                      ButtonSegment(
                        value: 'light',
                        label: Text('라이트'),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text('다크'),
                      ),
                    ],
                    selected: {state.themeMode},
                    onSelectionChanged: (selection) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setThemeMode(selection.first);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Section: Data
                Text('데이터',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    )),
                const Divider(),
                ListTile(
                  title: const Text('데이터 내보내기 (JSON)'),
                  leading: const Icon(Icons.file_download),
                  onTap: () async {
                    try {
                      final json = await ref
                          .read(settingsControllerProvider.notifier)
                          .exportData();
                      final dir = await getTemporaryDirectory();
                      final file = File(
                          '${dir.path}/3lines_export_${DateTime.now().millisecondsSinceEpoch}.json');
                      await file.writeAsString(json);
                      if (context.mounted) {
                        await Share.shareXFiles([XFile(file.path)]);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('내보내기에 실패했어요')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  title: Text('모든 데이터 삭제',
                      style: TextStyle(
                          color: theme.colorScheme.error)),
                  leading: Icon(Icons.delete_forever,
                      color: theme.colorScheme.error),
                  onTap: () => _showDeleteConfirmation(context, ref),
                ),

                const SizedBox(height: 16),

                // Section: Info
                Text('정보',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    )),
                const Divider(),
                ListTile(
                  title: const Text('앱 버전'),
                  trailing: Text(state.appVersion),
                ),
                ListTile(
                  title: const Text('오픈소스 라이선스'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: '3Lines',
                    applicationVersion: state.appVersion,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
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
    );
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteInput(context, ref);
            },
            child: Text('다음',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showDeleteInput(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제 확인'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '"삭제"를 입력하세요',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text == '삭제') {
                await ref
                    .read(settingsControllerProvider.notifier)
                    .deleteAllData();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('모든 데이터가 삭제되었어요')),
                  );
                }
              }
            },
            child: Text('삭제',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
