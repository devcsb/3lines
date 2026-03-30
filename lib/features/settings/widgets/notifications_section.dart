import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';

class NotificationsSection extends ConsumerWidget {
  const NotificationsSection({
    super.key,
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timeStr =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('알림',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const Divider(),
        Semantics(
          label: enabled ? '매일 리마인더 켜짐' : '매일 리마인더 꺼짐',
          child: SwitchListTile(
            title: const Text('매일 리마인더'),
            value: enabled,
            onChanged: (v) async {
              final success = await ref
                  .read(settingsControllerProvider.notifier)
                  .setReminderEnabled(v);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('알림 설정에 실패했어요')),
                );
              }
            },
          ),
        ),
        Semantics(
          label: '리마인더 시간: ${hour.toString().padLeft(2, '0')}시 ${minute.toString().padLeft(2, '0')}분',
          child: ListTile(
            title: const Text('리마인더 시간'),
            trailing: Text(timeStr, style: theme.textTheme.bodyLarge),
            enabled: enabled,
            onTap: enabled
                ? () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: hour, minute: minute),
                    );
                    if (time != null && context.mounted) {
                      final success = await ref
                          .read(settingsControllerProvider.notifier)
                          .setReminderTime(time.hour, time.minute);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('알림 시간 변경에 실패했어요')),
                        );
                      }
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
