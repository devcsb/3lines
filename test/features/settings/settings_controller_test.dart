import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/services/reminder_coordinator.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/entry_import.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';
import 'package:three_lines/features/today/today_controller.dart';

import '../../helpers/fake_biometric_service.dart';
import '../../helpers/fake_photo_service.dart';
import '../../helpers/import_fixtures.dart';

class _PhotoReferenceRepository extends EntryRepository {
  _PhotoReferenceRepository(super.db, {required super.clock});
  int? failAfter;
  int reads = 0;
  @override
  Future<List<String>> getAllPhotoPaths() async {
    if (failAfter != null && reads++ >= failAfter!) {
      throw StateError('reference read failed');
    }
    return super.getAllPhotoPaths();
  }
}

class _AfterDeletePhotoService extends FakePhotoService {
  Future<void> Function(String)? afterDelete;

  @override
  Future<void> deletePhoto(String path) async {
    await super.deletePhoto(path);
    await afterDelete?.call(path);
  }
}

final class FakeReminderCoordinator implements ReminderCoordinator {
  bool enabledResult = true;
  bool timeResult = true;
  final enabledCalls = <bool>[];
  final timeCalls = <(int, int)>[];
  Completer<void>? enabledStarted;
  Completer<void>? enabledGate;
  Completer<void>? timeStarted;
  Completer<void>? timeGate;

  @override
  Future<bool> setEnabled(bool enabled) async {
    enabledCalls.add(enabled);
    if (enabledStarted?.isCompleted == false) enabledStarted!.complete();
    await enabledGate?.future;
    return enabledResult;
  }

  @override
  Future<bool> setTime(int hour, int minute) async {
    timeCalls.add((hour, minute));
    if (timeStarted?.isCompleted == false) timeStarted!.complete();
    await timeGate?.future;
    return timeResult;
  }

  @override
  Future<void> reconcileOnLaunch() async {}

  @override
  Future<void> reconcileAfterJournalChange() async {}
}

void main() {
  late AppDatabase db;
  late EntryRepository entryRepo;
  late SettingsRepository settingsRepo;
  late FakePhotoService fakePhoto;
  late FakeReminderCoordinator fakeReminders;
  late FakeBiometricService fakeBio;
  late ProviderContainer container;
  late MutableImportClock clock;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '3Lines',
      packageName: 'com.threelines.threeLines',
      version: '9.9.9',
      buildNumber: '99',
      buildSignature: 'test',
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = MutableImportClock(DateTime(2026, 9, 30, 12));
    entryRepo = _PhotoReferenceRepository(db, clock: clock);
    settingsRepo = SettingsRepository(db);
    fakePhoto = _AfterDeletePhotoService();
    fakeReminders = FakeReminderCoordinator();
    fakeBio = FakeBiometricService();

    container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entryRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        photoServiceProvider.overrideWithValue(fakePhoto),
        reminderCoordinatorProvider.overrideWithValue(fakeReminders),
        biometricServiceProvider.overrideWithValue(fakeBio),
        // Stub the FutureProvider so invalidate() doesn't hit real DB path
        biometricLockEnabledProvider.overrideWith((_) => Future.value(false)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('updatePrompt', () {
    test('ignores invalid prompt indexes', () async {
      final initial = await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      await notifier.updatePrompt(-1, '무효');
      await notifier.updatePrompt(3, '무효');

      final state = container.read(settingsControllerProvider).value;
      expect(state?.prompts, initial.prompts);
      expect(await settingsRepo.getSetting('prompt_0', defaultValue: ''), '');
      expect(await settingsRepo.getSetting('prompt_4', defaultValue: ''), '');
    });

    test('custom prompt 변경은 widget sync용 journal change를 발행한다', () async {
      await container.read(settingsControllerProvider.future);
      final before = container.read(journalChangesProvider);

      await container
          .read(settingsControllerProvider.notifier)
          .updatePrompt(0, '새 질문');

      expect(container.read(journalChangesProvider), before + 1);
    });

    test('prompt reset은 widget sync용 journal change를 발행한다', () async {
      await container.read(settingsControllerProvider.future);
      final before = container.read(journalChangesProvider);

      await container.read(settingsControllerProvider.notifier).resetPrompts();

      expect(container.read(journalChangesProvider), before + 1);
    });
  });

  group('setReminderTime', () {
    test('Coordinator 성공 시 호출 인자와 state 시각을 갱신한다', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final ok = await notifier.setReminderTime(8, 30);

      expect(ok, isTrue);
      expect(fakeReminders.timeCalls, [(8, 30)]);
      final state = container.read(settingsControllerProvider).value;
      expect(state?.reminderHour, 8);
      expect(state?.reminderMinute, 30);
    });

    test('Coordinator 실패 시 state 시각을 유지한다', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final before = container.read(settingsControllerProvider).value!;

      fakeReminders.timeResult = false;
      final ok = await notifier.setReminderTime(9, 15);

      expect(ok, isFalse);
      expect(fakeReminders.timeCalls, [(9, 15)]);
      final current = container.read(settingsControllerProvider).value;
      expect(current?.reminderHour, before.reminderHour);
      expect(current?.reminderMinute, before.reminderMinute);
    });

    test('Coordinator 대기 중 변경된 prompt를 성공 결과가 되돌리지 않는다', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      fakeReminders.timeStarted = Completer<void>();
      fakeReminders.timeGate = Completer<void>();

      final timeFuture = notifier.setReminderTime(8, 30);
      await fakeReminders.timeStarted!.future;
      await notifier.updatePrompt(0, '동시에 바뀐 질문');
      fakeReminders.timeGate!.complete();

      expect(await timeFuture, isTrue);
      final current = container.read(settingsControllerProvider).value;
      expect(current?.reminderHour, 8);
      expect(current?.reminderMinute, 30);
      expect(current?.prompts[0], '동시에 바뀐 질문');
    });
  });

  group('previewImport/applyImport', () {
    test('오늘 기록 가져오기는 Today 실제 상태를 한 번 갱신한다', () async {
      final settingsListen = container.listen(
        settingsControllerProvider,
        (_, _) {},
      );
      var loaded = 0;
      final todayListen = container.listen(todayControllerProvider, (_, next) {
        if (!next.isLoading && next.hasValue) loaded++;
      });
      addTearDown(settingsListen.close);
      addTearDown(todayListen.close);
      await container.read(settingsControllerProvider.future);
      expect(
        (await container.read(todayControllerProvider.future)).isCompleted,
        isFalse,
      );
      expect(loaded, 1);
      final notifier = container.read(settingsControllerProvider.notifier);
      final preview = await notifier.previewImport(
        jsonEncode([importRecord('2026-09-30', answer: '가져온 오늘 기록')]),
      );
      expect(
        container.read(todayControllerProvider).value!.isCompleted,
        isFalse,
      );
      await Future.wait([
        notifier.applyImport(preview),
        notifier.applyImport(preview),
      ]);
      final today = await container.read(todayControllerProvider.future);
      expect((today.isCompleted, today.answer1), (true, '가져온 오늘 기록'));
      expect(loaded, 2);
      await notifier.applyImport(preview);
      final preserved = await notifier.previewImport(
        jsonEncode([importRecord('2026-09-30')]),
      );
      await notifier.applyImport(preserved);
      await container.pump();
      expect(loaded, 2);
    });

    test('동시 확인과 성공 재호출은 첫 policy와 동일 Future를 재사용한다', () async {
      final listen = container.listen(settingsControllerProvider, (_, _) {});
      addTearDown(listen.close);
      await container.read(settingsControllerProvider.future);
      await entryRepo.saveEntry(
        DailyEntry(date: '2026-09-29', emotion: 2, answer1: '로컬'),
        preserveTimestamps: true,
      );
      final notifier = container.read(settingsControllerProvider.notifier);
      final before = container.read(journalChangesProvider);
      final preview = await notifier.previewImport(
        jsonEncode([importRecord('2026-09-29'), importRecord('2026-09-28')]),
      );
      expect(await entryRepo.getTotalCount(), 1);
      expect(container.read(journalChangesProvider), before);
      final first = notifier.applyImport(preview);
      final second = notifier.applyImport(
        preview,
        policy: ConflictPolicy.replacePreviewed,
      );
      expect(identical(first, second), isTrue);
      final results = await Future.wait([first, second]);
      expect(results.map((r) => (r.inserted, r.conflictSkipped)), [
        (1, 1),
        (1, 1),
      ]);
      expect((await entryRepo.getEntryByDate('2026-09-29'))!.answer1, '로컬');
      expect(container.read(journalChangesProvider), before + 1);
      expect(identical(first, notifier.applyImport(preview)), isTrue);
      expect(container.read(journalChangesProvider), before + 1);
    });

    test('DB 실패는 이벤트 없이 재시도하고 실제 변경 없는 성공은 발행하지 않는다', () async {
      final listen = container.listen(settingsControllerProvider, (_, _) {});
      addTearDown(listen.close);
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final before = container.read(journalChangesProvider);
      await db.customStatement('''
        CREATE TRIGGER fail_import BEFORE INSERT ON entries
        BEGIN SELECT RAISE(ABORT, 'failure'); END;
      ''');
      final preview = await notifier.previewImport(
        jsonEncode([importRecord('2026-09-29')]),
      );
      await expectLater(
        notifier.applyImport(preview),
        throwsA(isA<Exception>()),
      );
      expect(await entryRepo.getTotalCount(), 0);
      expect(container.read(journalChangesProvider), before);
      await db.customStatement('DROP TRIGGER fail_import');
      expect((await notifier.applyImport(preview)).inserted, 1);
      expect(container.read(journalChangesProvider), before + 1);
      final preserved = await notifier.previewImport(
        jsonEncode([importRecord('2026-09-29')]),
      );
      expect((await notifier.applyImport(preserved)).conflictSkipped, 1);
      expect(container.read(journalChangesProvider), before + 1);
    });

    test('승인 후 listener가 사라져도 커밋과 저널 이벤트를 완료한다', () async {
      final listen = container.listen(settingsControllerProvider, (_, _) {});
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final preview = await notifier.previewImport(
        jsonEncode([importRecord('2026-09-29')]),
      );
      final started = Completer<void>();
      final gate = Completer<void>();
      final blocker = db.transaction(() async {
        started.complete();
        await gate.future;
      });
      await started.future;
      final before = container.read(journalChangesProvider);
      final application = notifier.applyImport(preview);
      listen.close();
      await container.pump();
      gate.complete();
      await blocker;
      expect((await application).inserted, 1);
      expect(await entryRepo.getTotalCount(), 1);
      expect(container.read(journalChangesProvider), before + 1);
    });

    const validJson = '''
{
  "app": "3Lines",
  "version": "1.0.0",
  "entries": [
    {
      "date": "2026-03-01",
      "emotion": 4,
      "prompts": [
        {"category": "gratitude", "question": "감사한 것", "answer": "가족"},
        {"category": "acceptance", "question": "수용할 것", "answer": ""},
        {"category": "intention", "question": "내일의 의도", "answer": "운동"}
      ]
    },
    {
      "date": "2026-03-02",
      "emotion": 3,
      "prompts": [
        {"category": "gratitude", "question": "감사한 것", "answer": "날씨"},
        {"category": "acceptance", "question": "수용할 것", "answer": ""},
        {"category": "intention", "question": "내일의 의도", "answer": ""}
      ]
    }
  ]
}
''';

    test('imports entries from wrapped JSON format', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final changesBefore = container.read(journalChangesProvider);

      final preview = await notifier.previewImport(validJson);
      expect(await entryRepo.getTotalCount(), 0);
      expect(container.read(journalChangesProvider), changesBefore);
      final result = await notifier.applyImport(preview);

      expect(result.inserted, 2);
      expect(result.total, 2);
      expect(await entryRepo.getTotalCount(), 2);
      expect(container.read(journalChangesProvider), changesBefore + 1);
    });

    test('imports entries from bare list JSON format', () async {
      const bareJson = '''
[
  {
    "date": "2026-04-01",
    "emotion": 5,
    "prompts": [
      {"category": "gratitude", "question": "q", "answer": "a"},
      {"category": "acceptance", "question": "q2", "answer": ""},
      {"category": "intention", "question": "q3", "answer": ""}
    ]
  }
]
''';
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.applyImport(
        await notifier.previewImport(bareJson),
      );
      expect(result.inserted, 1);
    });

    test('throws FormatException for completely invalid JSON', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      expect(
        () => notifier.previewImport('not json at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when entries key is missing', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      expect(
        () => notifier.previewImport('{"app": "3Lines", "version": "1.0.0"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('손상 prompts와 non-map을 invalid로 분류한다', () async {
      const mixedJson = '''
{
  "entries": [
    {
      "date": "2026-03-01",
      "emotion": 4,
      "prompts": [{"category": "gratitude", "question": "q", "answer": "a"}]
    },
    "this is not a map",
    42
  ]
}
''';
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.applyImport(
        await notifier.previewImport(mixedJson),
      );
      expect((result.inserted, result.invalid, result.total), (0, 3, 3));
    });

    test('returns zero imported for empty entries list', () async {
      const emptyEntriesJson =
          '{"app": "3Lines", "version": "1.0.0", "entries": []}';
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final changesBefore = container.read(journalChangesProvider);

      final result = await notifier.applyImport(
        await notifier.previewImport(emptyEntriesJson),
      );
      expect(result.changedCount, 0);
      expect(result.total, 0);
      expect(await entryRepo.getTotalCount(), 0);
      expect(container.read(journalChangesProvider), changesBefore);
    });
  });

  group('exportData', () {
    test(
      'returns valid JSON with correct wrapper structure for empty database',
      () async {
        await container.read(settingsControllerProvider.future);
        final notifier = container.read(settingsControllerProvider.notifier);

        final jsonStr = await notifier.exportData();
        final decoded = json.decode(jsonStr) as Map<String, dynamic>;

        expect(decoded['app'], '3Lines');
        expect(decoded['version'], '9.9.9');
        expect(decoded['exported_at'], isNotEmpty);
        expect(decoded['total_entries'], 0);
        expect(decoded['entries'], isEmpty);
      },
    );

    test('exports all entries with correct field mapping', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-01',
          emotion: 4,
          prompt1: '감사한 것은?',
          answer1: '가족과 저녁',
          prompt2: '수용할 것은?',
          answer2: '실수 인정',
          prompt3: '내일의 의도는?',
          answer3: '일찍 일어나기',
        ),
      );
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-02',
          emotion: 2,
          prompt1: '감사한 것은?',
          answer1: '좋은 날씨',
          prompt2: '',
          answer2: '',
          prompt3: '',
          answer3: '',
        ),
      );

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final jsonStr = await notifier.exportData();
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      expect(decoded['total_entries'], 2);
      final entries = decoded['entries'] as List<dynamic>;
      expect(entries.length, 2);

      // Entries should be in date order (ascending)
      final first = entries[0] as Map<String, dynamic>;
      expect(first['date'], '2026-03-01');
      expect(first['emotion'], 4);

      final prompts = first['prompts'] as List<dynamic>;
      expect(prompts.length, greaterThan(0));
      // First prompt should carry the answer
      final gratitudePrompt = (prompts).cast<Map<String, dynamic>>().firstWhere(
        (p) => p['answer'] == '가족과 저녁',
        orElse: () => {},
      );
      expect(gratitudePrompt, isNotEmpty);
    });

    test('controller export envelope도 photo_path null을 반환한다', () async {
      final entry = DailyEntry(
        date: '2026-09-29',
        emotion: 3,
        answer1: '기록',
        photoPath: '/local/photos/photo_123.jpg',
        createdAt: DateTime(2026, 9, 29, 8),
        updatedAt: DateTime(2026, 9, 29, 9),
      );
      await entryRepo.saveEntry(entry, preserveTimestamps: true);
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final decoded = json.decode(await notifier.exportData()) as Map;

      expect(decoded['app'], '3Lines');
      expect(decoded['version'], isA<String>());
      final exportedEntry =
          (decoded['entries'] as List<Object?>).single as Map<String, Object?>;
      expect(exportedEntry['photo_path'], isNull);
      final saved = (await entryRepo.getEntryByDate(entry.date))!;
      expect(saved.photoPath, entry.photoPath);
      expect(saved.createdAt, entry.createdAt);
      expect(saved.updatedAt, entry.updatedAt);
      expect(saved.answer1, entry.answer1);
    });

    test('exported JSON can be re-imported with correct counts', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-10',
          emotion: 3,
          prompt1: '감사',
          answer1: '건강',
          prompt2: '',
          answer2: '',
          prompt3: '',
          answer3: '',
        ),
      );

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final jsonStr = await notifier.exportData();
      // Delete all and re-import
      await entryRepo.deleteAllEntries();
      expect(await entryRepo.getTotalCount(), 0);

      final result = await notifier.applyImport(
        await notifier.previewImport(jsonStr),
      );
      expect(result.inserted, 1);
      expect(result.total, 1);
      expect(await entryRepo.getTotalCount(), 1);
    });
  });

  group('deleteAllData', () {
    test('전체 삭제 정리 사이 새 DB 참조가 생긴 두 번째 사진은 보존한다', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-09-28',
          emotion: 3,
          answer1: '첫 기록',
          photoPath: '/first.jpg',
        ),
      );
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-09-29',
          emotion: 3,
          answer1: '둘째 기록',
          photoPath: '/second.jpg',
        ),
      );
      (fakePhoto as _AfterDeletePhotoService).afterDelete = (path) async {
        if (path != '/first.jpg') return;
        await entryRepo.saveEntry(
          DailyEntry(
            date: '2026-09-30',
            emotion: 3,
            answer1: '정리 중 새 기록',
            photoPath: '/second.jpg',
          ),
        );
      };
      await container.read(settingsControllerProvider.future);
      final before = container.read(journalChangesProvider);
      expect(
        await container
            .read(settingsControllerProvider.notifier)
            .deleteAllData(),
        isTrue,
      );
      expect(
        (await entryRepo.getEntryByDate('2026-09-30'))!.photoPath,
        '/second.jpg',
      );
      expect(await entryRepo.getTotalCount(), 1);
      expect(fakePhoto.deletedPaths, ['/first.jpg']);
      expect(container.read(journalChangesProvider), before + 1);
    });

    test('전체 삭제 정리 사이 새 초안이 참조한 사진은 보존한다', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-09-29',
          emotion: 3,
          answer1: '첫 기록',
          photoPath: '/first.jpg',
        ),
      );
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-09-30',
          emotion: 3,
          answer1: '오늘 기록',
          photoPath: '/second.jpg',
        ),
      );
      final listen = container.listen(todayControllerProvider, (_, _) {});
      addTearDown(listen.close);
      final initial = await container.read(todayControllerProvider.future);
      expect(initial.isCompleted && !initial.isEditing, isTrue);
      final today = container.read(todayControllerProvider.notifier);
      (fakePhoto as _AfterDeletePhotoService).afterDelete = (path) async {
        if (path != '/first.jpg') return;
        today.toggleEdit();
        await today.attachPhoto('/second.jpg');
        expect(
          container.read(todayControllerProvider).value!.isEditing,
          isTrue,
        );
      };
      await container.read(settingsControllerProvider.future);
      expect(
        await container
            .read(settingsControllerProvider.notifier)
            .deleteAllData(),
        isTrue,
      );
      expect(await entryRepo.getTotalCount(), 0);
      expect(fakePhoto.deletedPaths, ['/first.jpg']);
    });

    for (final editing in [false, true]) {
      test('전체 삭제 후 ${editing ? '수정' : '작성'} Today draft도 제거한다', () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: editing ? '2026-09-30' : '2026-09-29',
            emotion: 3,
            answer1: '기록',
            photoPath: '/real.jpg',
          ),
        );
        final listen = container.listen(todayControllerProvider, (_, _) {});
        addTearDown(listen.close);
        await container.read(todayControllerProvider.future);
        final today = container.read(todayControllerProvider.notifier);
        if (editing) today.toggleEdit();
        fakePhoto.canonicalAliases['/draft.jpg'] = '/real.jpg';
        await today.attachPhoto('/draft.jpg');
        await container.read(settingsControllerProvider.future);
        final before = container.read(journalChangesProvider);
        expect(
          await container
              .read(settingsControllerProvider.notifier)
              .deleteAllData(),
          isTrue,
        );
        expect(await entryRepo.getTotalCount(), 0);
        expect(fakePhoto.deletedPaths.toSet(), {'/real.jpg', '/draft.jpg'});
        expect(await entryRepo.listDrafts(), isEmpty);
        expect(
          container.read(todayControllerProvider).value!.photoPath,
          isNull,
        );
        expect(container.read(journalChangesProvider), before + 1);
      });
    }

    test('완료된 readonly Today 사진은 전체 삭제 후 정리한다', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-09-30',
          emotion: 3,
          answer1: '기록',
          photoPath: '/photo.jpg',
        ),
      );
      expect(
        (await container.read(todayControllerProvider.future)).isCompleted,
        isTrue,
      );
      await container.read(settingsControllerProvider.future);
      expect(
        await container
            .read(settingsControllerProvider.notifier)
            .deleteAllData(),
        isTrue,
      );
      expect(fakePhoto.deletedPaths, ['/photo.jpg']);
    });

    for (final failure in ['postcommit-query', 'unknown']) {
      test('전체 삭제 $failure 실패는 파일만 보존하고 DB 성공을 유지한다', () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: '2026-09-29',
            emotion: 3,
            answer1: '기록',
            photoPath: '/photo.jpg',
          ),
        );
        await container.read(settingsControllerProvider.future);
        if (failure == 'postcommit-query') {
          (entryRepo as _PhotoReferenceRepository).failAfter = 1;
        }
        if (failure == 'unknown') fakePhoto.referenceCheckFails = true;
        final before = container.read(journalChangesProvider);
        expect(
          await container
              .read(settingsControllerProvider.notifier)
              .deleteAllData(),
          isTrue,
        );
        expect(await entryRepo.getTotalCount(), 0);
        expect(fakePhoto.deletedPaths, isEmpty);
        expect(container.read(journalChangesProvider), before + 1);
      });
    }

    for (final failure in ['snapshot-query', 'commit']) {
      test('전체 삭제 $failure 실패는 DB와 사진과 이벤트를 보존한다', () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: '2026-09-29',
            emotion: 3,
            answer1: '기록',
            photoPath: '/photo.jpg',
          ),
        );
        await container.read(settingsControllerProvider.future);
        if (failure == 'snapshot-query') {
          (entryRepo as _PhotoReferenceRepository).failAfter = 0;
        }
        if (failure == 'commit') {
          await db.customStatement(
            "CREATE TRIGGER reject_delete BEFORE DELETE ON entries BEGIN SELECT RAISE(ABORT, 'blocked'); END",
          );
        }
        final before = container.read(journalChangesProvider);
        expect(
          await container
              .read(settingsControllerProvider.notifier)
              .deleteAllData(),
          isFalse,
        );
        expect(await entryRepo.getTotalCount(), 1);
        expect(fakePhoto.deletedPaths, isEmpty);
        expect(container.read(journalChangesProvider), before);
      });
    }

    test('removes all entries from the database', () async {
      await entryRepo.saveEntry(
        DailyEntry(date: '2026-03-01', emotion: 3, answer1: 'test'),
      );
      await entryRepo.saveEntry(
        DailyEntry(date: '2026-03-02', emotion: 4, answer1: 'test2'),
      );

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final changesBefore = container.read(journalChangesProvider);

      final success = await notifier.deleteAllData();

      expect(success, isTrue);
      expect(await entryRepo.getTotalCount(), 0);
      expect(container.read(journalChangesProvider), changesBefore + 1);
    });

    test('deletes photo files for entries that had photos', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-01',
          emotion: 3,
          photoPath: '/photos/pic1.jpg',
        ),
      );
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-02',
          emotion: 4,
          photoPath: '/photos/pic2.jpg',
        ),
      );
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-03',
          emotion: 2, // no photo
        ),
      );

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      await notifier.deleteAllData();

      expect(
        fakePhoto.deletedPaths,
        containsAll(['/photos/pic1.jpg', '/photos/pic2.jpg']),
      );
      expect(fakePhoto.deletedPaths.length, 2);
    });

    test('returns true even when database is already empty', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final changesBefore = container.read(journalChangesProvider);

      final success = await notifier.deleteAllData();
      expect(success, isTrue);
      expect(container.read(journalChangesProvider), changesBefore + 1);
    });

    test('사진 정리 실패 후에도 DB 삭제와 저널 이벤트를 완료한다', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-01',
          emotion: 3,
          photoPath: '/photos/pic1.jpg',
        ),
      );
      await entryRepo.saveEntry(
        DailyEntry(
          date: '2026-03-02',
          emotion: 4,
          photoPath: '/photos/pic2.jpg',
        ),
      );
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final changesBefore = container.read(journalChangesProvider);
      fakePhoto.deleteError = StateError('사진 삭제 실패');

      final success = await notifier.deleteAllData();

      expect(success, isTrue);
      expect(await entryRepo.getTotalCount(), 0);
      expect(
        fakePhoto.deletedPaths,
        containsAll(['/photos/pic1.jpg', '/photos/pic2.jpg']),
      );
      expect(container.read(journalChangesProvider), changesBefore + 1);
    });
  });

  group('setBiometricLockEnabled', () {
    test('returns false when biometric is not available', () async {
      fakeBio.available = false;
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setBiometricLockEnabled(true);
      expect(result, isFalse);
    });

    test('returns false when authentication fails', () async {
      fakeBio.available = true;
      fakeBio.authResult = false;
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setBiometricLockEnabled(true);
      expect(result, isFalse);
    });

    test('enables biometric lock when available and authenticated', () async {
      fakeBio.available = true;
      fakeBio.authResult = true;
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setBiometricLockEnabled(true);
      expect(result, isTrue);

      final state = container.read(settingsControllerProvider).value;
      expect(state?.biometricLockEnabled, isTrue);
    });

    test('disables biometric lock without authentication', () async {
      // First enable
      await settingsRepo.setSetting('biometric_lock_enabled', 'true');

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setBiometricLockEnabled(false);
      expect(result, isTrue);

      final state = container.read(settingsControllerProvider).value;
      expect(state?.biometricLockEnabled, isFalse);
    });
  });

  group('setReminderEnabled', () {
    test('Coordinator 실패 시 state와 저장값을 유지한다', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final before = container.read(settingsControllerProvider).value!;

      fakeReminders.enabledResult = false;

      final result = await notifier.setReminderEnabled(true);

      expect(result, isFalse);
      expect(fakeReminders.enabledCalls, [true]);
      expect(
        container.read(settingsControllerProvider).value?.reminderEnabled,
        before.reminderEnabled,
      );
      expect((await settingsRepo.getReminderSettings()).enabled, isFalse);
    });

    test('Coordinator 성공 시 호출 인자와 state 활성화를 갱신한다', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setReminderEnabled(true);

      expect(result, isTrue);
      expect(fakeReminders.enabledCalls, [true]);
      final state = container.read(settingsControllerProvider).value;
      expect(state?.reminderEnabled, isTrue);
    });

    test('Coordinator 대기 중 변경된 prompt를 성공 결과가 되돌리지 않는다', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      fakeReminders.enabledStarted = Completer<void>();
      fakeReminders.enabledGate = Completer<void>();

      final enabledFuture = notifier.setReminderEnabled(true);
      await fakeReminders.enabledStarted!.future;
      await notifier.updatePrompt(1, '기다리는 동안 바뀐 질문');
      fakeReminders.enabledGate!.complete();

      expect(await enabledFuture, isTrue);
      final current = container.read(settingsControllerProvider).value;
      expect(current?.reminderEnabled, isTrue);
      expect(current?.prompts[1], '기다리는 동안 바뀐 질문');
    });

    test('Coordinator 성공 시 비활성화 결과를 state에 반영한다', () async {
      await settingsRepo.setSetting('reminder_enabled', 'true');
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setReminderEnabled(false);

      expect(result, isTrue);
      expect(fakeReminders.enabledCalls, [false]);
      final state = container.read(settingsControllerProvider).value;
      expect(state?.reminderEnabled, isFalse);
    });
  });
}
