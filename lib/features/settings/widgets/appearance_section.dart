import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../data/repositories/settings_repository.dart';
import '../settings_controller.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key, required this.themeMode});

  final String themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentAccent =
        ref.watch(accentThemeProvider).value ?? 'sage';
    final unlockedAsync = ref.watch(_unlockedMilestonesProvider);
    final unlocked = unlockedAsync.value ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('외관',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Semantics(
            label:
                '테마 선택: ${themeMode == 'system' ? '시스템 기본' : themeMode == 'light' ? '라이트' : '다크'}',
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'system', label: Text('시스템')),
                ButtonSegment(value: 'light', label: Text('라이트')),
                ButtonSegment(value: 'dark', label: Text('다크')),
              ],
              selected: {themeMode},
              onSelectionChanged: (selection) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '액센트 테마',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppTheme.accentSeeds.keys.map((accent) {
              final isUnlocked = accent == 'sage' ||
                  (AppTheme.accentRequiredStreak[accent] != null &&
                      unlocked.contains(
                          AppTheme.accentRequiredStreak[accent]));
              final isSelected = currentAccent == accent;
              final seed = AppTheme.accentSeeds[accent]!;
              final label = AppTheme.accentLabels[accent] ?? accent;

              return _AccentChip(
                accent: accent,
                label: label,
                seed: seed,
                isSelected: isSelected,
                isUnlocked: isUnlocked,
                onTap: isUnlocked
                    ? () => ref
                        .read(accentThemeProvider.notifier)
                        .setAccent(accent)
                    : null,
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

final _unlockedMilestonesProvider = FutureProvider<Set<int>>((ref) {
  return ref.watch(settingsRepositoryProvider).getUnlockedMilestones();
});

class _AccentChip extends StatelessWidget {
  final String accent;
  final String label;
  final Color seed;
  final bool isSelected;
  final bool isUnlocked;
  final VoidCallback? onTap;

  const _AccentChip({
    required this.accent,
    required this.label,
    required this.seed,
    required this.isSelected,
    required this.isUnlocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opacity = isUnlocked ? 1.0 : 0.35;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? seed.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? seed
                : theme.colorScheme.outlineVariant
                    .withValues(alpha: isUnlocked ? 0.6 : 0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: seed.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isUnlocked
                    ? theme.colorScheme.onSurface.withValues(
                        alpha: isSelected ? 0.9 : 0.65,
                      )
                    : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (!isUnlocked) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
