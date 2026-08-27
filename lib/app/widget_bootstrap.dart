import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/events/journal_changes.dart';
import '../core/services/device_time_zone_resolver.dart';
import '../core/services/journal_side_effects.dart';
import '../core/services/widget_sync_service.dart';
import '../features/lock/lock_screen.dart';
import '../features/today/today_controller.dart';
import 'router.dart';

/// Wires home-widget sync and deep-link emotion handling for the app lifetime.
class WidgetBootstrap extends ConsumerStatefulWidget {
  const WidgetBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WidgetBootstrap> createState() => _WidgetBootstrapState();
}

class _WidgetBootstrapState extends ConsumerState<WidgetBootstrap>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _clickSub;
  ProviderSubscription<int>? _journalSub;
  String? _lastTimeZoneIdentifier;
  Future<void> _resumeTail = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final widgetSync = ref.read(widgetSyncServiceProvider);
    _journalSub = ref.listenManual(journalChangesProvider, (_, _) {
      unawaited(ref.read(journalSideEffectsProvider).onJournalChanged());
    });
    _clickSub = widgetSync.listenWidgetClicks(_handleUri);

    await ref.read(journalSideEffectsProvider).onLaunch();
    if (!mounted) return;
    await _captureTimeZone();
    if (!mounted) return;

    final initial = await widgetSync.initiallyLaunchedUri();
    if (!mounted) return;
    if (initial != null) {
      _handleUri(initial);
    }
  }

  void _handleUri(Uri uri) {
    final emotion = WidgetSnapshot.parseEmotionFromUri(uri);
    if (emotion != null) {
      ref.read(pendingWidgetEmotionProvider.notifier).setEmotion(emotion);
      _tryApplyPendingEmotion();
    }

    final lockEnabled = ref.read(biometricLockEnabledProvider).value ?? false;
    final locked = ref.read(biometricLockStateProvider);
    if (!(lockEnabled && locked)) {
      ref.read(routerProvider).go('/');
    }
  }

  void _tryApplyPendingEmotion() {
    final pending = ref.read(pendingWidgetEmotionProvider);
    if (pending == null) return;

    final today = ref.read(todayControllerProvider).value;
    if (today == null) return;
    if (today.isCompleted && !today.isEditing) return;

    final taken = ref.read(pendingWidgetEmotionProvider.notifier).take();
    if (taken != null) {
      ref.read(todayControllerProvider.notifier).setEmotion(taken);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeTail = _resumeTail.then((_) => _handleResume());
    }
  }

  Future<void> _handleResume() async {
    if (!mounted) return;
    final timeZoneChanged = await _hasTimeZoneChanged();
    if (!mounted) return;

    try {
      if (timeZoneChanged) {
        // Notification triggers retain the timezone captured when scheduled.
        // Reconcile the full plan only when the device timezone actually changed;
        // ordinary resumes keep the low-cost widget-only sync path.
        await ref.read(journalSideEffectsProvider).onLaunch();
      } else {
        await ref.read(widgetSyncServiceProvider).sync();
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed app resume side effect',
        name: 'widget_bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (mounted) _tryApplyPendingEmotion();
  }

  Future<void> _captureTimeZone() async {
    if (kIsWeb) return;
    try {
      _lastTimeZoneIdentifier = await ref
          .read(deviceTimeZoneResolverProvider)
          .getIdentifier();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to capture device timezone',
        name: 'widget_bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _hasTimeZoneChanged() async {
    if (kIsWeb) return false;
    try {
      final current = await ref
          .read(deviceTimeZoneResolverProvider)
          .getIdentifier();
      final previous = _lastTimeZoneIdentifier;
      _lastTimeZoneIdentifier = current;
      return previous != null && previous != current;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to detect device timezone change',
        name: 'widget_bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clickSub?.cancel();
    _journalSub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(todayControllerProvider, (_, next) {
      if (next.hasValue) {
        _tryApplyPendingEmotion();
      }
    });
    ref.listen(biometricLockStateProvider, (prev, next) {
      if (prev == true && next == false) {
        _tryApplyPendingEmotion();
        ref.read(routerProvider).go('/');
      }
    });

    return widget.child;
  }
}
