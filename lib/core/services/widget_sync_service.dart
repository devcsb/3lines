import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/models/daily_entry.dart';
import '../../data/repositories/entry_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../theme/app_colors.dart';
import '../time/app_clock.dart';

/// Shared storage / native names for the home screen widget.
class WidgetSyncConfig {
  static const appGroupId = 'group.com.threelines.threeLines';
  static const iOSWidgetName = 'ThreeLinesWidget';
  static const androidWidgetName = 'ThreeLinesWidgetProvider';
  static const scheme = 'threelines';

  static const keyDate = 'date';
  static const keyStreak = 'streak';
  static const keyIsCompleted = 'is_completed';
  static const keyPrompt = 'prompt';
  static const keyEmotion = 'emotion';
  static const keyStatusMessage = 'status_message';
  static const keyStreakLabel = 'streak_label';
}

/// Pure snapshot used by native widgets (and unit tests).
class WidgetSnapshot {
  final String date;
  final int streak;
  final bool isCompleted;
  final String prompt;
  final int? emotion;
  final String statusMessage;
  final String streakLabel;

  const WidgetSnapshot({
    required this.date,
    required this.streak,
    required this.isCompleted,
    required this.prompt,
    required this.emotion,
    required this.statusMessage,
    required this.streakLabel,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetSnapshot &&
          date == other.date &&
          streak == other.streak &&
          isCompleted == other.isCompleted &&
          prompt == other.prompt &&
          emotion == other.emotion &&
          statusMessage == other.statusMessage &&
          streakLabel == other.streakLabel;

  @override
  int get hashCode => Object.hash(
    date,
    streak,
    isCompleted,
    prompt,
    emotion,
    statusMessage,
    streakLabel,
  );

  static String buildStatusMessage({
    required bool isCompleted,
    required int streak,
    int? emotion,
  }) {
    if (isCompleted) {
      final label = emotion != null ? AppColors.emotionLabels[emotion] : null;
      if (label != null) {
        return '오늘 기록 완료 · $label';
      }
      return '오늘 기록 완료';
    }
    if (streak > 0) {
      return '오늘 아직이에요 · 스트릭 유지 중';
    }
    return '오늘 한 줄만 적어도 돼요';
  }

  static String buildStreakLabel(int streak) {
    if (streak <= 0) return '시작해볼까요';
    return '$streak일';
  }

  /// Parses `threelines://today?emotion=N`.
  static int? parseEmotionFromUri(Uri? uri) {
    if (uri == null) return null;
    if (uri.scheme != WidgetSyncConfig.scheme) return null;
    final isToday =
        uri.host == 'today' ||
        uri.path == 'today' ||
        uri.path == '/today' ||
        uri.pathSegments.contains('today');
    if (!isToday) return null;
    final raw = uri.queryParameters['emotion'];
    if (raw == null || raw.isEmpty) return null;
    final value = int.tryParse(raw);
    if (value == null || value < 1 || value > 5) return null;
    return value;
  }

  static Uri todayUri({int? emotion}) {
    return Uri(
      scheme: WidgetSyncConfig.scheme,
      host: 'today',
      queryParameters: emotion == null ? null : {'emotion': '$emotion'},
    );
  }
}

/// Thin platform bridge so tests can stub I/O.
abstract class HomeWidgetBridge {
  Future<void> setAppGroupId(String groupId);
  Future<void> saveString(String key, String? value);
  Future<void> updateWidget({
    required String iOSName,
    required String androidName,
  });
  Future<Uri?> initiallyLaunchedFromHomeWidget();
  Stream<Uri?> get widgetClicked;
}

class LiveHomeWidgetBridge implements HomeWidgetBridge {
  @override
  Future<void> setAppGroupId(String groupId) =>
      HomeWidget.setAppGroupId(groupId);

  @override
  Future<void> saveString(String key, String? value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> updateWidget({
    required String iOSName,
    required String androidName,
  }) => HomeWidget.updateWidget(iOSName: iOSName, androidName: androidName);

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> get widgetClicked => HomeWidget.widgetClicked;
}

abstract interface class WidgetSync {
  Future<void> sync();
  Future<Uri?> initiallyLaunchedUri();
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri);
}

class WidgetSyncService implements WidgetSync {
  WidgetSyncService({
    required EntryRepository entryRepository,
    required SettingsRepository settingsRepository,
    required AppClock clock,
    HomeWidgetBridge? bridge,
  }) : _entryRepository = entryRepository,
       _settingsRepository = settingsRepository,
       _clock = clock,
       _bridge = bridge ?? LiveHomeWidgetBridge();

  final EntryRepository _entryRepository;
  final SettingsRepository _settingsRepository;
  final AppClock _clock;
  final HomeWidgetBridge _bridge;

  bool _configured = false;
  Future<void>? _syncFuture;
  bool _syncRequested = false;
  WidgetSnapshot? _lastSuccessfulSnapshot;

  Future<void> ensureConfigured() async {
    if (_configured || kIsWeb) return;
    try {
      await _bridge.setAppGroupId(WidgetSyncConfig.appGroupId);
      _configured = true;
    } catch (e, stack) {
      developer.log(
        'Failed to configure home widget',
        name: 'widget_sync',
        error: e,
        stackTrace: stack,
      );
    }
  }

  Future<WidgetSnapshot> buildSnapshot() async {
    final date = _clock.todayString();
    final results = await Future.wait([
      _settingsRepository.getRotatingPrompts(),
      _entryRepository.getTodayEntry(),
      _entryRepository.getCurrentStreakWithGrace(),
    ]);
    final prompts = results[0] as List<String>;
    final today = results[1] as DailyEntry?;
    final streakResult = results[2] as ({int count, bool usedGraceDay});
    final isCompleted = today != null;
    final emotion = today?.emotion;
    final streak = streakResult.count;

    return WidgetSnapshot(
      date: date,
      streak: streak,
      isCompleted: isCompleted,
      prompt: prompts.isNotEmpty ? prompts[0] : '오늘 감사한 작은 것 하나는?',
      emotion: emotion,
      statusMessage: WidgetSnapshot.buildStatusMessage(
        isCompleted: isCompleted,
        streak: streak,
        emotion: emotion,
      ),
      streakLabel: WidgetSnapshot.buildStreakLabel(streak),
    );
  }

  @override
  Future<void> sync() {
    if (kIsWeb) return Future<void>.value();
    _syncRequested = true;
    return _syncFuture ??= _drainSyncRequests();
  }

  Future<void> _drainSyncRequests() async {
    try {
      while (_syncRequested) {
        _syncRequested = false;
        try {
          await _syncOnce();
        } catch (e, stack) {
          developer.log(
            'Failed to sync home widget',
            name: 'widget_sync',
            error: e,
            stackTrace: stack,
          );
        }
      }
    } finally {
      _syncFuture = null;
      if (_syncRequested) {
        scheduleMicrotask(sync);
      }
    }
  }

  Future<void> _syncOnce() async {
    await ensureConfigured();
    final snapshot = await buildSnapshot();
    if (snapshot == _lastSuccessfulSnapshot) return;
    await _persist(snapshot);
    await _bridge.updateWidget(
      iOSName: WidgetSyncConfig.iOSWidgetName,
      androidName: WidgetSyncConfig.androidWidgetName,
    );
    _lastSuccessfulSnapshot = snapshot;
  }

  Future<void> _persist(WidgetSnapshot snapshot) async {
    await Future.wait([
      _bridge.saveString(WidgetSyncConfig.keyDate, snapshot.date),
      _bridge.saveString(WidgetSyncConfig.keyStreak, '${snapshot.streak}'),
      _bridge.saveString(
        WidgetSyncConfig.keyIsCompleted,
        snapshot.isCompleted ? 'true' : 'false',
      ),
      _bridge.saveString(WidgetSyncConfig.keyPrompt, snapshot.prompt),
      _bridge.saveString(
        WidgetSyncConfig.keyEmotion,
        snapshot.emotion?.toString() ?? '',
      ),
      _bridge.saveString(
        WidgetSyncConfig.keyStatusMessage,
        snapshot.statusMessage,
      ),
      _bridge.saveString(WidgetSyncConfig.keyStreakLabel, snapshot.streakLabel),
    ]);
  }

  @override
  Future<Uri?> initiallyLaunchedUri() async {
    if (kIsWeb) return null;
    try {
      await ensureConfigured();
      return await _bridge.initiallyLaunchedFromHomeWidget();
    } catch (e, stack) {
      developer.log(
        'Failed to read initial widget launch URI',
        name: 'widget_sync',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  @override
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) {
    if (kIsWeb) return null;
    return _bridge.widgetClicked.listen((uri) {
      if (uri != null) onUri(uri);
    });
  }
}

/// Pending emotion from widget deep link (applied after unlock / Today load).
final pendingWidgetEmotionProvider =
    NotifierProvider<PendingWidgetEmotion, int?>(PendingWidgetEmotion.new);

class PendingWidgetEmotion extends Notifier<int?> {
  @override
  int? build() => null;

  void setEmotion(int? emotion) {
    if (emotion == null || emotion < 1 || emotion > 5) {
      state = null;
      return;
    }
    state = emotion;
  }

  int? take() {
    final value = state;
    state = null;
    return value;
  }
}

final homeWidgetBridgeProvider = Provider<HomeWidgetBridge>((ref) {
  return LiveHomeWidgetBridge();
});

final widgetSyncServiceProvider = Provider<WidgetSync>((ref) {
  return WidgetSyncService(
    entryRepository: ref.watch(entryRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(appClockProvider),
    bridge: ref.watch(homeWidgetBridgeProvider),
  );
});
