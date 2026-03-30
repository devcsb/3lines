import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/settings_repository.dart';

class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final mode = await ref.watch(settingsRepositoryProvider).getThemeMode();
    return _parseMode(mode);
  }

  Future<void> setThemeMode(String mode) async {
    await ref.read(settingsRepositoryProvider).setSetting('theme_mode', mode);
    state = AsyncData(_parseMode(mode));
  }

  ThemeMode _parseMode(String mode) {
    return switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

final themeNotifierProvider =
    AsyncNotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

// ── Accent theme notifier ──────────────────────────────────────────

class AccentThemeNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return ref.watch(settingsRepositoryProvider).getAccentTheme();
  }

  Future<void> setAccent(String accent) async {
    await ref.read(settingsRepositoryProvider).setAccentTheme(accent);
    state = AsyncData(accent);
  }
}

final accentThemeProvider =
    AsyncNotifierProvider<AccentThemeNotifier, String>(
        AccentThemeNotifier.new);
