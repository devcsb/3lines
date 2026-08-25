import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app/router.dart';
import 'package:three_lines/app/widget_bootstrap.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/services/journal_side_effects.dart';
import 'package:three_lines/core/services/widget_sync_service.dart';
import 'package:three_lines/features/today/today_controller.dart';
import 'package:three_lines/features/today/today_state.dart';

final class StubTodayController extends TodayController {
  @override
  Future<TodayState> build() async => const TodayState();
}

final class RecordingWidgetSync implements WidgetSync {
  int syncCount = 0;
  final clicks = StreamController<Uri?>.broadcast();

  @override
  Future<void> sync() async => syncCount++;

  @override
  Future<Uri?> initiallyLaunchedUri() async => null;

  @override
  StreamSubscription<Uri?>? listenWidgetClicks(void Function(Uri uri) onUri) {
    return clicks.stream.listen((uri) {
      if (uri != null) onUri(uri);
    });
  }
}

final class RecordingJournalSideEffects implements JournalSideEffects {
  int launchCount = 0;
  int journalChangedCount = 0;
  Completer<void>? launchStarted;
  Completer<void>? launchGate;

  @override
  Future<void> onLaunch() async {
    launchCount++;
    if (launchStarted?.isCompleted == false) launchStarted!.complete();
    await launchGate?.future;
  }

  @override
  Future<void> onJournalChanged() async => journalChangedCount++;
}

void main() {
  late ProviderContainer container;
  late RecordingJournalSideEffects sideEffects;
  late RecordingWidgetSync widgetSync;

  setUp(() {
    sideEffects = RecordingJournalSideEffects();
    widgetSync = RecordingWidgetSync();
    container = ProviderContainer(
      overrides: [
        journalSideEffectsProvider.overrideWithValue(sideEffects),
        widgetSyncServiceProvider.overrideWithValue(widgetSync),
        todayControllerProvider.overrideWith(StubTodayController.new),
        biometricLockEnabledProvider.overrideWith((ref) => Future.value(true)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await widgetSync.clicks.close();
  });

  Future<void> pumpBootstrap(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WidgetBootstrap(child: SizedBox())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> disposeBootstrap(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('첫 프레임 뒤 onLaunch를 한 번 호출한다', (tester) async {
    await pumpBootstrap(tester);

    expect(sideEffects.launchCount, 1);
    expect(sideEffects.journalChangedCount, 0);

    await disposeBootstrap(tester);
  });

  testWidgets('journalChanges 1회 증가가 onJournalChanged 1회로 이어진다', (
    tester,
  ) async {
    await pumpBootstrap(tester);

    container.read(journalChangesProvider.notifier).markChanged();
    await tester.pump();

    expect(sideEffects.journalChangedCount, 1);

    await disposeBootstrap(tester);
  });

  testWidgets('resumed는 위젯만 동기화하고 알림 journal 조정을 호출하지 않는다', (tester) async {
    await pumpBootstrap(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(widgetSync.syncCount, 1);
    expect(sideEffects.journalChangedCount, 0);

    await disposeBootstrap(tester);
  });

  testWidgets('onLaunch 대기 중 저널 변경도 한 번 전달한다', (tester) async {
    sideEffects.launchStarted = Completer<void>();
    sideEffects.launchGate = Completer<void>();
    await pumpBootstrap(tester);
    await sideEffects.launchStarted!.future;

    container.read(journalChangesProvider.notifier).markChanged();
    await tester.pump();
    sideEffects.launchGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(sideEffects.journalChangedCount, 1);

    await disposeBootstrap(tester);
  });

  testWidgets('onLaunch 대기 중 위젯 클릭도 유실하지 않는다', (tester) async {
    sideEffects.launchStarted = Completer<void>();
    sideEffects.launchGate = Completer<void>();
    await pumpBootstrap(tester);
    await sideEffects.launchStarted!.future;

    widgetSync.clicks.add(Uri.parse('threelines://today?emotion=4'));
    await tester.pump();
    sideEffects.launchGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(container.read(todayControllerProvider).value?.emotion, 4);

    await disposeBootstrap(tester);
  });
}
