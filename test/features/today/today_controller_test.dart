import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/notification_service.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/today/today_controller.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/fake_photo_service.dart';

void main() {
  late AppDatabase db;
  late EntryRepository entryRepo;
  late SettingsRepository settingsRepo;
  late FakePhotoService fakePhoto;
  late FakeNotificationService fakeNotif;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepo = EntryRepository(db);
    settingsRepo = SettingsRepository(db);
    fakePhoto = FakePhotoService();
    fakeNotif = FakeNotificationService();

    container = ProviderContainer(overrides: [
      entryRepositoryProvider.overrideWithValue(entryRepo),
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      photoServiceProvider.overrideWithValue(fakePhoto),
      notificationServiceProvider.overrideWithValue(fakeNotif),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('build', () {
    test('initial state is not completed when no entry exists', () async {
      final state = await container.read(todayControllerProvider.future);
      expect(state.isCompleted, isFalse);
      expect(state.emotion, isNull);
      expect(state.existingEntry, isNull);
    });

    test('loads existing entry when today already has data', () async {
      await entryRepo.saveEntry(DailyEntry(
        date: du.getTodayString(),
        emotion: 4,
        prompt1: '감사',
        answer1: '좋은 날씨',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
      ));

      final state = await container.read(todayControllerProvider.future);
      expect(state.isCompleted, isTrue);
      expect(state.emotion, 4);
      expect(state.answer1, '좋은 날씨');
    });
  });

  group('setEmotion', () {
    test('updates emotion in state', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(5);
      final state = container.read(todayControllerProvider).value;
      expect(state?.emotion, 5);
    });

    test('ignores invalid emotion values', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(0);
      notifier.setEmotion(6);
      final state = container.read(todayControllerProvider).value;
      expect(state?.emotion, isNull);
    });
  });

  group('setAnswer', () {
    test('updates answer1 through answer3 by index', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setAnswer(0, '답변1');
      notifier.setAnswer(1, '답변2');
      notifier.setAnswer(2, '답변3');
      final state = container.read(todayControllerProvider).value;
      expect(state?.answer1, '답변1');
      expect(state?.answer2, '답변2');
      expect(state?.answer3, '답변3');
    });
  });

  group('save', () {
    test('persists entry and sets isCompleted to true', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.setEmotion(4);
      notifier.setAnswer(0, '가족과 저녁');

      final success = await notifier.save();
      expect(success, isTrue);

      final state = container.read(todayControllerProvider).value;
      expect(state?.isCompleted, isTrue);
      expect(state?.isEditing, isFalse);
      expect(state?.isSaving, isFalse);

      // Verify persisted in DB
      final saved = await entryRepo.getTodayEntry();
      expect(saved?.emotion, 4);
      expect(saved?.answer1, '가족과 저녁');
    });

    test('returns false and stays incomplete when canSave is false', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      // No emotion, no answers → canSave = false

      final success = await notifier.save();
      expect(success, isFalse);

      final state = container.read(todayControllerProvider).value;
      expect(state?.isCompleted, isFalse);
    });

    test('returns false when emotion is set but no answers', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(3);
      // No answers

      final success = await notifier.save();
      expect(success, isFalse);
    });

    test('deletes old photo file after successful update', () async {
      // Pre-populate with an entry that has a photo
      final existing = DailyEntry(
        date: du.getTodayString(),
        emotion: 3,
        prompt1: '감사',
        answer1: '원래 답변',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
        photoPath: '/old/photo.jpg',
      );
      await entryRepo.saveEntry(existing);

      // Reload controller so it sees the existing entry
      container.invalidate(todayControllerProvider);
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      // Attach a new photo (different path from DB)
      notifier.attachPhoto('/new/photo.jpg');

      // Enable editing, update emotion, then save
      notifier.toggleEdit();
      notifier.setEmotion(5);
      notifier.setAnswer(0, '새 답변');
      await notifier.save();

      // Old photo should have been deleted
      expect(fakePhoto.deletedPaths, contains('/old/photo.jpg'));
    });

    test('does not delete photo when path is unchanged', () async {
      final existing = DailyEntry(
        date: du.getTodayString(),
        emotion: 3,
        prompt1: '감사',
        answer1: '기존 답변',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
        photoPath: '/same/photo.jpg',
      );
      await entryRepo.saveEntry(existing);

      container.invalidate(todayControllerProvider);
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.toggleEdit();
      notifier.setAnswer(0, '수정된 답변');
      await notifier.save();

      // Photo path didn't change → should not be deleted
      expect(fakePhoto.deletedPaths, isNot(contains('/same/photo.jpg')));
    });
  });

  group('attachPhoto', () {
    test('sets photoPath in state', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.attachPhoto('/photos/new.jpg');
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, '/photos/new.jpg');
    });

    test('deletes previous unsaved photo when attaching a new one', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      // Attach first photo (not saved to DB)
      notifier.attachPhoto('/photos/first.jpg');
      // Attach second photo — first should be deleted
      notifier.attachPhoto('/photos/second.jpg');

      expect(fakePhoto.deletedPaths, contains('/photos/first.jpg'));
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, '/photos/second.jpg');
    });

    test('does not delete DB-saved photo when replacing with new one', () async {
      // Entry already saved with a photo
      final existing = DailyEntry(
        date: du.getTodayString(),
        emotion: 3,
        prompt1: '',
        answer1: '기존 답변',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
        photoPath: '/db/photo.jpg',
      );
      await entryRepo.saveEntry(existing);

      container.invalidate(todayControllerProvider);
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      // Attach a new photo — the DB photo should NOT be deleted yet
      notifier.attachPhoto('/photos/new.jpg');

      expect(fakePhoto.deletedPaths, isNot(contains('/db/photo.jpg')));
    });
  });

  group('toggleEdit', () {
    test('toggles isEditing between true and false', () async {
      await entryRepo.saveEntry(DailyEntry(
        date: du.getTodayString(),
        emotion: 3,
        answer1: '기존 답변',
      ));
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      expect(container.read(todayControllerProvider).value?.isEditing, isFalse);
      notifier.toggleEdit();
      expect(container.read(todayControllerProvider).value?.isEditing, isTrue);
      notifier.toggleEdit();
      expect(container.read(todayControllerProvider).value?.isEditing, isFalse);
    });
  });

  group('save — edge cases', () {
    test('prevents concurrent saves via isSaving guard', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(3);
      notifier.setAnswer(0, '동시 저장 테스트');

      // Start two saves concurrently: the first sets isSaving=true before
      // its first await, so the second call should return false immediately.
      final future1 = notifier.save();
      final future2 = notifier.save();

      final result1 = await future1;
      final result2 = await future2;

      expect(result1, isTrue);
      expect(result2, isFalse); // blocked by isSaving guard
    });

    test('detects milestone at 7 total entries', () async {
      // Pre-populate 6 past entries so today's save becomes entry #7
      for (int i = 1; i <= 6; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        await entryRepo.saveEntry(DailyEntry(
          date: du.dateToString(date),
          emotion: 3,
          answer1: '사전 데이터',
        ));
      }

      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(4);
      notifier.setAnswer(0, '7번째 기록');

      await notifier.save();

      final state = container.read(todayControllerProvider).value;
      expect(state?.milestone, 7);
    });

    test('milestone is null when total count is not a milestone', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(3);
      notifier.setAnswer(0, '첫 기록');

      await notifier.save();

      final state = container.read(todayControllerProvider).value;
      // 1 is not a milestone (7, 30, 100, 365)
      expect(state?.milestone, isNull);
    });

    test('isSaving is false after failure', () async {
      // Set emotion and answer so canSave is true initially
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setEmotion(3);
      notifier.setAnswer(0, '테스트');

      // DB will be closed to simulate a save failure
      await db.close();
      final success = await notifier.save();

      expect(success, isFalse);
      final state = container.read(todayControllerProvider).value;
      expect(state?.isSaving, isFalse);

      // Re-open for tearDown
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
  });

  group('setAnswer — boundary', () {
    test('ignores invalid index values', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.setAnswer(-1, '무효');
      notifier.setAnswer(3, '무효');
      notifier.setAnswer(99, '무효');
      final state = container.read(todayControllerProvider).value;
      expect(state?.answer1, '');
      expect(state?.answer2, '');
      expect(state?.answer3, '');
    });
  });

  group('removePhoto', () {
    test('clears photoPath in state', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.attachPhoto('/photos/some.jpg');
      await notifier.removePhoto();
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, isNull);
    });

    test('deletes unsaved photo file immediately', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.attachPhoto('/photos/unsaved.jpg');
      await notifier.removePhoto();
      expect(fakePhoto.deletedPaths, contains('/photos/unsaved.jpg'));
    });

    test('does not delete DB-saved photo on remove (deferred to save)', () async {
      final existing = DailyEntry(
        date: du.getTodayString(),
        emotion: 3,
        prompt1: '',
        answer1: '기존 답변',
        prompt2: '',
        answer2: '',
        prompt3: '',
        answer3: '',
        photoPath: '/db/photo.jpg',
      );
      await entryRepo.saveEntry(existing);

      container.invalidate(todayControllerProvider);
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      // Remove the photo (which is the DB-saved path)
      await notifier.removePhoto();

      // DB photo must NOT be deleted here — it's cleaned up only on save()
      expect(fakePhoto.deletedPaths, isNot(contains('/db/photo.jpg')));
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, isNull);
    });
  });
}
