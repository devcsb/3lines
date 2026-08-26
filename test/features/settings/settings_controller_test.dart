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
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';

import '../../helpers/fake_biometric_service.dart';
import '../../helpers/fake_photo_service.dart';

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

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: '3Lines',
      packageName: 'com.threelines.threeLines',
      version: '9.9.9',
      buildNumber: '99',
      buildSignature: 'test',
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepo = EntryRepository(db);
    settingsRepo = SettingsRepository(db);
    fakePhoto = FakePhotoService();
    fakeReminders = FakeReminderCoordinator();
    fakeBio = FakeBiometricService();

    container = ProviderContainer(
      overrides: [
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

  group('importData', () {
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

      final result = await notifier.importData(validJson);

      expect(result.imported, 2);
      expect(result.skipped, 0);
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

      final result = await notifier.importData(bareJson);
      expect(result.imported, 1);
    });

    test('throws FormatException for completely invalid JSON', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      expect(
        () => notifier.importData('not json at all'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when entries key is missing', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      expect(
        () => notifier.importData('{"app": "3Lines", "version": "1.0.0"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('counts non-map items in list as skipped', () async {
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

      final result = await notifier.importData(mixedJson);
      // 2 non-map items counted as skippedByType, 1 map item attempted
      expect(result.skipped, greaterThanOrEqualTo(2));
    });

    test('returns zero imported for empty entries list', () async {
      const emptyEntriesJson =
          '{"app": "3Lines", "version": "1.0.0", "entries": []}';
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);
      final changesBefore = container.read(journalChangesProvider);

      final result = await notifier.importData(emptyEntriesJson);
      expect(result.imported, 0);
      expect(result.skipped, 0);
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

      final result = await notifier.importData(jsonStr);
      expect(result.imported, 1);
      expect(result.skipped, 0);
      expect(await entryRepo.getTotalCount(), 1);
    });
  });

  group('deleteAllData', () {
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
      expect(container.read(journalChangesProvider), changesBefore);
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
