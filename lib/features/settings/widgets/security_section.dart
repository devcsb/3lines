import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings_controller.dart';

class SecuritySection extends ConsumerWidget {
  const SecuritySection({
    super.key,
    required this.biometricLockEnabled,
  });

  final bool biometricLockEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('보안',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const Divider(),
        Semantics(
          label: biometricLockEnabled ? '앱 잠금 켜짐' : '앱 잠금 꺼짐',
          child: SwitchListTile(
            title: const Text('앱 잠금'),
            subtitle: const Text('생체인증으로 앱을 보호합니다'),
            value: biometricLockEnabled,
            onChanged: (v) async {
              final success = await ref
                  .read(settingsControllerProvider.notifier)
                  .setBiometricLockEnabled(v);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('생체인증을 사용할 수 없어요')),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
