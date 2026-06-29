import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/timeline/timeline_controller.dart';

import '../../helpers/fake_photo_service.dart';

void main() {
  late AppDatabase db;
  late EntryRepository entryRepo;
  late SettingsRepository settingsRepo;
  late FakePhotoService fakePhoto;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepo = EntryRepository(db);
    settingsRepo = SettingsRepository(db);
    fakePhoto = FakePhotoService();

    container = ProviderContainer(overrides: [
      entryRepositoryProvider.overrideWithValue(entryRepo),
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      photoServiceProvider.overrideWithValue(fakePhoto),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  DailyEntry makeEntry(String date, {int emotion = 3, String? photoPath}) {
    return DailyEntry(
      date: date,
      emotion: emotion,
      prompt1: '감사',
      answer1: '좋은 하루',
      prompt2: '',
      answer2: '',
      prompt3: '',
      answer3: '',
      photoPath: photoPath,
    );
  }

  group('build', () {
    test('initial state has zero streaks when database is empty', () async {
      final state = await container.read(timelineControllerProvider.future);
      expect(state.currentStreak, 0);
      expect(state.longestStreak, 0);
      expect(state.emotionMap, isEmpty);
    });

    test('reflects entries in emotionMap', () async {
      await entryRepo.saveEntry(makeEntry('2026-03-01', emotion: 4));
      await entryRepo.saveEntry(makeEntry('2026-03-02', emotion: 2));

      final state = await container.read(timelineControllerProvider.future);
      // Entries from 2026-03-01/02 may fall outside the 12-week window depending
      // on today's date, so we verify the map structure is correct when within range.
      // Use recent dates for reliable coverage:
      final today = du.getTodayString();
      await entryRepo.saveEntry(makeEntry(today, emotion: 5));

      container.invalidate(timelineControllerProvider);
      final updated = await container.read(timelineControllerProvider.future);
      expect(updated.emotionMap[today], 5);
    });
  });

  group('deleteEntry', () {
    test('removes entry from database', () async {
      await entryRepo.saveEntry(makeEntry(du.getTodayString()));
      await container.read(timelineControllerProvider.future);

      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.deleteEntry(du.getTodayString());

      final entry = await entryRepo.getTodayEntry();
      expect(entry, isNull);
    });

    test('deletes photo file when entry has a photo', () async {
      const photoPath = '/photos/diary_photo.jpg';
      await entryRepo.saveEntry(makeEntry(
        du.getTodayString(),
        photoPath: photoPath,
      ));
      await container.read(timelineControllerProvider.future);

      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.deleteEntry(du.getTodayString());

      expect(fakePhoto.deletedPaths, contains(photoPath));
    });

    test('does not call photo service when entry has no photo', () async {
      await entryRepo.saveEntry(makeEntry(du.getTodayString())); // no photo
      await container.read(timelineControllerProvider.future);

      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.deleteEntry(du.getTodayString());

      expect(fakePhoto.deletedPaths, isEmpty);
    });

    test('reloads state after deletion', () async {
      await entryRepo.saveEntry(makeEntry(du.getTodayString(), emotion: 5));
      final initial = await container.read(timelineControllerProvider.future);
      expect(initial.emotionMap[du.getTodayString()], 5);

      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.deleteEntry(du.getTodayString());

      final updated = await container.read(timelineControllerProvider.future);
      expect(updated.emotionMap.containsKey(du.getTodayString()), isFalse);
    });
  });

  group('setPeriod', () {
    test('changes the period in state', () async {
      final initial = await container.read(timelineControllerProvider.future);
      expect(initial.period, TimelinePeriod.weeks12);

      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.setPeriod(TimelinePeriod.year1);

      final updated = await container.read(timelineControllerProvider.future);
      expect(updated.period, TimelinePeriod.year1);
    });
  });

  group('search', () {
    test('returns matching entries', () async {
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-01',
        emotion: 4,
        answer1: '가족과 여행',
        answer2: '',
        answer3: '',
      ));
      await entryRepo.saveEntry(DailyEntry(
        date: '2026-03-02',
        emotion: 3,
        answer1: '운동을 했다',
        answer2: '',
        answer3: '',
      ));

      await container.read(timelineControllerProvider.future);
      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.search('여행');

      final state = container.read(timelineControllerProvider).value;
      expect(state?.isSearching, isTrue);
      expect(state?.searchResults.length, 1);
      expect(state?.searchResults.first.date, '2026-03-01');
    });

    test('clearSearch resets search state', () async {
      await container.read(timelineControllerProvider.future);
      final notifier = container.read(timelineControllerProvider.notifier);
      await notifier.search('테스트');
      notifier.clearSearch();

      final state = container.read(timelineControllerProvider).value;
      expect(state?.isSearching, isFalse);
      expect(state?.searchResults, isEmpty);
    });
  });

  group('getEntryByDate', () {
    test('returns entry for existing date', () async {
      await entryRepo.saveEntry(makeEntry('2026-03-15', emotion: 5));
      await container.read(timelineControllerProvider.future);

      final notifier = container.read(timelineControllerProvider.notifier);
      final entry = await notifier.getEntryByDate('2026-03-15');
      expect(entry?.emotion, 5);
    });

    test('returns null for non-existent date', () async {
      await container.read(timelineControllerProvider.future);
      final notifier = container.read(timelineControllerProvider.notifier);
      final entry = await notifier.getEntryByDate('2099-01-01');
      expect(entry, isNull);
    });
  });
}
