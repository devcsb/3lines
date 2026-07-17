import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/events/journal_changes.dart';
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
    final service = ref.read(widgetSyncServiceProvider);
    await service.sync();
    if (!mounted) return;

    final initial = await service.initiallyLaunchedUri();
    if (!mounted) return;
    if (initial != null) {
      _handleUri(initial);
    }

    _clickSub = service.listenWidgetClicks(_handleUri);
    _journalSub = ref.listenManual(journalChangesProvider, (_, _) {
      unawaited(ref.read(widgetSyncServiceProvider).sync());
    });
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
      unawaited(ref.read(widgetSyncServiceProvider).sync());
      _tryApplyPendingEmotion();
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
