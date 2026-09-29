import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/widgets/data_section.dart';

import '../../../helpers/import_fixtures.dart';

void main() {
  late AppDatabase db;
  late EntryRepository repo;
  late SettingsRepository settings;
  late MutableImportClock clock;
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '3Lines',
      packageName: 'test.3lines',
      version: '1.0',
      buildNumber: '1',
      buildSignature: 'test',
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = MutableImportClock(DateTime(2026, 9, 30, 12));
    repo = EntryRepository(db, clock: clock);
    settings = SettingsRepository(db);
  });
  tearDown(() => db.close());

  Uint8List bytes(List<Object?> entries) =>
      Uint8List.fromList(utf8.encode(jsonEncode(entries)));
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(() async {
      await repo.getTotalCount();
      await Future<void>.delayed(Duration.zero);
    });
    // Busy 표시의 반복 animation을 기다리지 않고 dialog 전환 프레임만 진행한다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<ProviderContainer> mount(
    WidgetTester tester,
    Future<Uint8List?> Function() picker, {
    ValueNotifier<bool>? visible,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appClockProvider.overrideWithValue(clock),
          entryRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWithValue(settings),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: visible == null
                  ? DataSection(pickImportBytes: picker)
                  : ValueListenableBuilder<bool>(
                      valueListenable: visible,
                      builder: (_, show, _) => show
                          ? DataSection(pickImportBytes: picker)
                          : const SizedBox.shrink(),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await repo.getTotalCount();
    });
    await flush(tester);
    return ProviderScope.containerOf(tester.element(find.byType(DataSection)));
  }

  Future<void> pick(WidgetTester tester) async {
    await tester.ensureVisible(find.text('텍스트 기록 가져오기 (JSON)'));
    await tester.runAsync(() async {
      await tester.tap(find.text('텍스트 기록 가져오기 (JSON)'));
    });
    await flush(tester);
  }

  Future<int> count(WidgetTester tester) async =>
      (await tester.runAsync(repo.getTotalCount))!;

  testWidgets('파일 선택 재탭과 미리보기 취소는 DB 및 이벤트를 바꾸지 않는다', (tester) async {
    final gate = Completer<Uint8List?>();
    var picks = 0;
    final container = await mount(tester, () {
      picks++;
      return gate.future;
    });
    final before = container.read(journalChangesProvider);
    await pick(tester);
    await tester.tap(find.text('텍스트 기록 가져오기 (JSON)'));
    expect(picks, 1);
    await tester.runAsync(() async {
      gate.complete(bytes([importRecord('2026-09-29')]));
      await Future<void>.delayed(Duration.zero);
    });
    await flush(tester);
    expect(find.text('가져오기 미리보기'), findsOneWidget);
    expect(await count(tester), 0);
    await tester.tap(find.text('취소'));
    await flush(tester);
    expect(await count(tester), 0);
    expect(container.read(journalChangesProvider), before);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, '텍스트 기록 가져오기 (JSON)'))
          .onTap,
      isNotNull,
    );
  });

  testWidgets('picker 취소와 미리보기 route back은 무쓰기다', (tester) async {
    var picks = 0;
    final container = await mount(
      tester,
      () async => picks++ == 0 ? null : bytes([importRecord('2026-09-29')]),
    );
    final before = container.read(journalChangesProvider);
    await pick(tester);
    expect(find.text('가져오기 미리보기'), findsNothing);
    await pick(tester);
    expect(find.text('가져오기 미리보기'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await flush(tester);
    expect(await count(tester), 0);
    expect(container.read(journalChangesProvider), before);
  });

  for (final input in [
    Uint8List.fromList([0xff]),
    Uint8List.fromList(utf8.encode('{"secret":"RAW_MARKER"')),
  ]) {
    testWidgets('손상 bytes ${input.length}는 원문 없이 오류를 알리고 쓰지 않는다', (
      tester,
    ) async {
      final container = await mount(tester, () async => input);
      final before = container.read(journalChangesProvider);
      await pick(tester);
      expect(find.text('잘못된 파일 형식이에요'), findsOneWidget);
      expect(find.textContaining('RAW_MARKER'), findsNothing);
      expect(find.textContaining('FormatException'), findsNothing);
      expect(await count(tester), 0);
      expect(container.read(journalChangesProvider), before);
    });
  }

  testWidgets('파일 선택 중 dispose 뒤 늦은 반환은 쓰지 않는다', (tester) async {
    final gate = Completer<Uint8List?>();
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final container = await mount(tester, () => gate.future, visible: visible);
    final before = container.read(journalChangesProvider);
    await pick(tester);
    visible.value = false;
    await tester.pump();
    await tester.runAsync(() async {
      gate.complete(bytes([importRecord('2026-09-29')]));
      await Future<void>.delayed(Duration.zero);
    });
    await flush(tester);
    expect(find.text('가져오기 미리보기'), findsNothing);
    expect(await count(tester), 0);
    expect(container.read(journalChangesProvider), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('열린 dialog의 부모만 제거하면 새 적용을 시작하지 않는다', (tester) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    final container = await mount(
      tester,
      () async => bytes([importRecord('2026-09-29')]),
      visible: visible,
    );
    final before = container.read(journalChangesProvider);
    await pick(tester);
    visible.value = false;
    await tester.pump();
    await tester.tap(find.text('가져오기'));
    await flush(tester);
    expect(find.text('가져오기에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
    expect(await count(tester), 0);
    expect(container.read(journalChangesProvider), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('명시적 교체는 로컬 사진과 createdAt을 유지하고 실제 여섯 결과를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final created = DateTime(2026, 9, 1);
    await tester.runAsync(() async {
      for (final date in ['2026-09-25', '2026-09-26']) {
        await repo.saveEntry(
          DailyEntry(
            date: date,
            emotion: 2,
            answer1: '로컬',
            photoPath: '/local/photo.jpg',
            createdAt: created,
            updatedAt: DateTime(2026, 9, 2),
          ),
          preserveTimestamps: true,
        );
      }
    });
    final container = await mount(
      tester,
      () async => bytes([
        importRecord('2026-09-25'),
        importRecord('2026-09-26'),
        importRecord('2026-09-27'),
        importRecord('2026-09-28'),
        null,
        importRecord('2026-09-28'),
      ]),
      scale: 2,
    );
    final before = container.read(journalChangesProvider);
    await pick(tester);
    await tester.runAsync(() async {
      final changed = (await repo.getEntryByDate('2026-09-26'))!;
      await repo.saveEntry(
        changed.copyWith(
          updatedAt: changed.updatedAt.add(const Duration(seconds: 1)),
        ),
        preserveTimestamps: true,
      );
      await repo.saveEntry(
        DailyEntry(date: '2026-09-27', emotion: 2, answer1: '새 충돌'),
        preserveTimestamps: true,
      );
    });
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('가져오기'));
    await tester.runAsync(() async {
      await tester.tap(find.text('가져오기'));
    });
    await flush(tester);
    expect(find.text('가져오기 결과'), findsOneWidget);
    for (final label in ['신규', '교체', '충돌 보존', '변경 후 보존', '유효하지 않음', '중복']) {
      expect(find.textContaining('$label 1개'), findsOneWidget);
    }
    expect(
      find.textContaining('확인 뒤 바뀐 기록은 보존했어요. 새 미리보기로 확인해 주세요'),
      findsOneWidget,
    );
    final row = await tester.runAsync(() => repo.getEntryByDate('2026-09-25'));
    expect(
      (row!.answer1, row.photoPath, row.createdAt),
      ('기록', '/local/photo.jpg', created),
    );
    expect(container.read(journalChangesProvider), before + 1);
    await tester.ensureVisible(find.text('확인'));
    await tester.tap(find.text('확인'));
    await flush(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('실제 DB rollback 오류 뒤 재시도는 부분 결과 없이 성공한다', (tester) async {
    await tester.runAsync(() async {
      await repo.getTotalCount();
      await db.customStatement(
        "CREATE TRIGGER fail_import BEFORE INSERT ON entries WHEN NEW.date = '2026-09-29' BEGIN SELECT RAISE(ABORT, 'RAW_MARKER'); END;",
      );
    });
    final container = await mount(
      tester,
      () async =>
          bytes([importRecord('2026-09-28'), importRecord('2026-09-29')]),
    );
    final before = container.read(journalChangesProvider);
    await pick(tester);
    await tester.runAsync(() async {
      await tester.tap(find.text('가져오기'));
    });
    await flush(tester);
    expect(find.text('가져오기에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
    expect(find.textContaining('RAW_MARKER'), findsNothing);
    expect(find.text('가져오기 결과'), findsNothing);
    expect(await count(tester), 0);
    expect(container.read(journalChangesProvider), before);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_import'));
    await tester.runAsync(() async {
      await tester.tap(find.text('다시 시도'));
    });
    await flush(tester);
    expect(find.text('가져오기 결과'), findsOneWidget);
    expect(find.textContaining('신규 2개'), findsOneWidget);
    expect(await count(tester), 2);
    expect(container.read(journalChangesProvider), before + 1);
  });
}
