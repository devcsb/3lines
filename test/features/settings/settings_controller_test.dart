import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/app.dart';
import 'package:three_lines/core/services/biometric_service.dart';
import 'package:three_lines/core/services/notification_service.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';

import '../../helpers/fake_biometric_service.dart';
import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_photo_service.dart';

void main() {
  late AppDatabase db;
  late EntryRepository entryRepo;
  late SettingsRepository settingsRepo;
  late FakePhotoService fakePhoto;
  late FakeNotificationService fakeNotif;
  late FakeBiometricService fakeBio;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepo = EntryRepository(db);
    settingsRepo = SettingsRepository(db);
    fakePhoto = FakePhotoService();
    fakeNotif = FakeNotificationService();
    fakeBio = FakeBiometricService();

    container = ProviderContainer(overrides: [
      entryRepositoryProvider.overrideWithValue(entryRepo),
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      photoServiceProvider.overrideWithValue(fakePhoto),
      notificationServiceProvider.overrideWithValue(fakeNotif),
      biometricServiceProvider.overrideWithValue(fakeBio),
      // Stub the FutureProvider so invalidate() doesn't hit real DB path
      biometricLockEnabledProvider
          .overrideWith((_) => Future.value(false)),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
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

      final result = await notifier.importData(validJson);
      expect(result.imported, 2);
      expect(result.skipped, 0);
      expect(await entryRepo.getTotalCount(), 2);
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
      expect(() => notifier.importData('not json at all'), throwsA(isA<FormatException>()));
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
      const emptyEntriesJson = '{"app": "3Lines", "version": "1.0.0", "entries": []}';
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.importData(emptyEntriesJson);
      expect(result.imported, 0);
      expect(result.skipped, 0);
      expect(await entryRepo.getTotalCount(), 0);
    });
  });

  group('exportData', () {
    test('returns valid JSON with correct wrapper structure for empty database', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final jsonStr = await notifier.exportData();
      final decoded = json.decode(jsonStr) as Map<String, dynamic>;

      expect(decoded['app'], '3Lines');
      expect(decoded['version'], isNotEmpty);
      expect(decoded['exported_at'], isNotEmpty);
      expect(decoded['total_entries'], 0);
      expect(decoded['entries'], isEmpty);
    });

    test('exports all entries with correct field mapping', () async {
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        prompt1: '감사한 것은?',
        answer1: '가족과 저녁',
        prompt2: '수용할 것은?',
        answer2: '실수 인정',
        prompt3: '내일의 의도는?',
        answer3: '일찍 일어나기',
      ));
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-02',
        emotion: 2,
        prompt1: '감사한 것은?',
        answer1: '좋은 날씨',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
      ));

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
      final gratitudePrompt = (prompts)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['answer'] == '가족과 저녁', orElse: () => {});
      expect(gratitudePrompt, isNotEmpty);
    });

    test('exported JSON can be re-imported with correct counts', () async {
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-10',
        emotion: 3,
        prompt1: '감사',
        answer1: '건강',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
      ));

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
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-01', emotion: 3, answer1: 'test',
      ));
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-02', emotion: 4, answer1: 'test2',
      ));

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final success = await notifier.deleteAllData();
      expect(success, isTrue);
      expect(await entryRepo.getTotalCount(), 0);
    });

    test('deletes photo files for entries that had photos', () async {
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 3,
        photoPath: '/photos/pic1.jpg',
      ));
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-02',
        emotion: 4,
        photoPath: '/photos/pic2.jpg',
      ));
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-03',
        emotion: 2, // no photo
      ));

      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      await notifier.deleteAllData();

      expect(fakePhoto.deletedPaths, containsAll(['/photos/pic1.jpg', '/photos/pic2.jpg']));
      expect(fakePhoto.deletedPaths.length, 2);
    });

    test('returns true even when database is already empty', () async {
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final success = await notifier.deleteAllData();
      expect(success, isTrue);
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
    test('returns false when permission is denied', () async {
      fakeNotif.permissionGranted = false;
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setReminderEnabled(true);
      expect(result, isFalse);
    });

    test('schedules notification when enabled with permission', () async {
      fakeNotif.permissionGranted = true;
      fakeNotif.scheduleResult = true;
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      final result = await notifier.setReminderEnabled(true);
      expect(result, isTrue);
      expect(fakeNotif.scheduledCount, greaterThan(0));

      final state = container.read(settingsControllerProvider).value;
      expect(state?.reminderEnabled, isTrue);
    });

    test('cancels notification when disabled', () async {
      await settingsRepo.setSetting('reminder_enabled', 'true');
      await container.read(settingsControllerProvider.future);
      final notifier = container.read(settingsControllerProvider.notifier);

      await notifier.setReminderEnabled(false);

      expect(fakeNotif.cancelledCount, greaterThan(0));
      final state = container.read(settingsControllerProvider).value;
      expect(state?.reminderEnabled, isFalse);
    });
  });
}
