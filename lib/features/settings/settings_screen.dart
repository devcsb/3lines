import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/staggered_fade_in.dart';
import 'settings_controller.dart';
import 'widgets/appearance_section.dart';
import 'widgets/data_section.dart';
import 'widgets/info_section.dart';
import 'widgets/notifications_section.dart';
import 'widgets/questions_section.dart';
import 'widgets/security_section.dart';

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
          final sections = <Widget>[
            QuestionsSection(prompts: state.prompts),
            NotificationsSection(
              enabled: state.reminderEnabled,
              hour: state.reminderHour,
              minute: state.reminderMinute,
            ),
            SecuritySection(
              biometricLockEnabled: state.biometricLockEnabled,
            ),
            AppearanceSection(themeMode: state.themeMode),
            const DataSection(),
            InfoSection(appVersion: state.appVersion),
          ];

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                const SizedBox(height: 8),
                Text('설정', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                ...List.generate(sections.length, (i) {
                  return StaggeredFadeIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: sections[i],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
