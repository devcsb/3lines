import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/services/photo_service.dart';
import 'package:three_lines/core/utils/date_utils.dart' as du;
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/today/today_controller.dart';

import '../../helpers/fake_photo_service.dart';

class _PhotoReferenceRepository extends EntryRepository {
  _PhotoReferenceRepository(super.db);

  bool referenceReadFails = false;

  @override
  Future<List<String>> getAllPhotoPaths() async {
    if (referenceReadFails) throw StateError('reference read failed');
    return super.getAllPhotoPaths();
  }
}

void main() {
  late AppDatabase db;
  late EntryRepository entryRepo;
  late SettingsRepository settingsRepo;
  late FakePhotoService fakePhoto;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepo = _PhotoReferenceRepository(db);
    settingsRepo = SettingsRepository(db);
    fakePhoto = FakePhotoService();

    container = ProviderContainer(
      overrides: [
        entryRepositoryProvider.overrideWithValue(entryRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        photoServiceProvider.overrideWithValue(fakePhoto),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('사진 참조 보호', () {
    test('같은 draft 재첨부와 별칭 교체는 현재 사진을 보존한다', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      fakePhoto.canonicalAliases.addAll({
        '/draft/a.jpg': '/real/a.jpg',
        '/draft/alias.jpg': '/real/a.jpg',
      });
      await notifier.attachPhoto('/draft/a.jpg');
      await notifier.attachPhoto('/draft/a.jpg');
      await notifier.attachPhoto('/draft/alias.jpg');
      expect(fakePhoto.deletedPaths, isEmpty);
      expect(
        container.read(todayControllerProvider).value!.photoPath,
        '/draft/alias.jpg',
      );
    });

    for (final action in ['attach', 'remove', 'cancel', 'discard']) {
      test('$action 정리는 다른 기록의 사진 별칭을 보존한다', () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: '2026-01-01',
            emotion: 3,
            answer1: '다른 기록',
            photoPath: '/real/shared.jpg',
          ),
        );
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.getTodayString(),
            emotion: 3,
            answer1: '원래 답변',
            photoPath: '/saved.jpg',
          ),
        );
        fakePhoto.canonicalAliases['/alias/shared.jpg'] = '/real/shared.jpg';
        await container.read(todayControllerProvider.future);
        final notifier = container.read(todayControllerProvider.notifier);
        notifier.toggleEdit();
        if (action == 'discard') {
          await notifier.cancelEdit();
          await notifier.attachPhoto('/alias/shared.jpg');
        } else {
          await notifier.attachPhoto('/alias/shared.jpg');
          if (action == 'attach') await notifier.attachPhoto('/new.jpg');
          if (action == 'remove') await notifier.removePhoto();
          if (action == 'cancel') await notifier.cancelEdit();
        }
        expect(fakePhoto.deletedPaths, isEmpty);
        expect(
          (await entryRepo.getEntryByDate('2026-01-01'))!.photoPath,
          '/real/shared.jpg',
        );
      });
    }

    test('늦은 picker 결과가 저장 사진 별칭이면 보존한다', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '저장',
          photoPath: '/saved.jpg',
        ),
      );
      fakePhoto.canonicalAliases['/alias.jpg'] = '/saved.jpg';
      await container.read(todayControllerProvider.future);
      await container
          .read(todayControllerProvider.notifier)
          .attachPhoto('/alias.jpg');
      expect(fakePhoto.deletedPaths, isEmpty);
      expect(
        container.read(todayControllerProvider).value!.photoPath,
        '/saved.jpg',
      );
    });

    for (final failure in ['query', 'unknown', 'shared', 'alias']) {
      test('저장 후 $failure 참조는 파일을 보존하고 DB 성공과 이벤트를 유지한다', () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.getTodayString(),
            emotion: 3,
            answer1: '원래 답변',
            photoPath: '/old.jpg',
          ),
        );
        if (failure == 'shared') {
          await entryRepo.saveEntry(
            DailyEntry(
              date: '2026-01-01',
              emotion: 3,
              answer1: '공유',
              photoPath: '/alias.jpg',
            ),
          );
          fakePhoto.canonicalAliases['/alias.jpg'] = '/old.jpg';
        }
        if (failure == 'alias') {
          fakePhoto.canonicalAliases['/new.jpg'] = '/old.jpg';
        }
        await container.read(todayControllerProvider.future);
        final notifier = container.read(todayControllerProvider.notifier);
        notifier.toggleEdit();
        await notifier.attachPhoto('/new.jpg');
        notifier.setAnswer(0, '저장된 답변');
        if (failure == 'query') {
          (entryRepo as _PhotoReferenceRepository).referenceReadFails = true;
        }
        if (failure == 'unknown') fakePhoto.referenceCheckFails = true;
        final before = container.read(journalChangesProvider);
        expect(await notifier.save(), isTrue);
        expect((await entryRepo.getTodayEntry())!.photoPath, '/new.jpg');
        expect((await entryRepo.getTodayEntry())!.answer1, '저장된 답변');
        expect(fakePhoto.deletedPaths, isEmpty);
        expect(container.read(journalChangesProvider), before + 1);
        expect(
          container.read(todayControllerProvider).value!.isSaving,
          isFalse,
        );
      });
    }

    for (final action in ['attach', 'remove', 'cancel', 'discard']) {
      test('$action 참조 판정 불명은 파일을 보존한다', () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.getTodayString(),
            emotion: 3,
            answer1: '저장',
            photoPath: '/saved.jpg',
          ),
        );
        await container.read(todayControllerProvider.future);
        final notifier = container.read(todayControllerProvider.notifier);
        notifier.toggleEdit();
        await notifier.attachPhoto('/draft.jpg');
        fakePhoto.referenceCheckFails = true;
        if (action == 'attach') await notifier.attachPhoto('/next.jpg');
        if (action == 'remove') await notifier.removePhoto();
        if (action == 'cancel') await notifier.cancelEdit();
        if (action == 'discard') {
          await notifier.cancelEdit();
          await notifier.attachPhoto('/late.jpg');
        }
        expect(fakePhoto.deletedPaths, isEmpty);
      });
    }

    test('DB 저장 실패는 교체 사진을 정리하거나 이벤트를 발행하지 않는다', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '원래 답변',
          photoPath: '/old.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      notifier.toggleEdit();
      await notifier.attachPhoto('/new.jpg');
      await db.customStatement(
        "CREATE TRIGGER reject_save BEFORE UPDATE ON entries BEGIN SELECT RAISE(ABORT, 'blocked'); END",
      );
      final before = container.read(journalChangesProvider);
      expect(await notifier.save(), isFalse);
      expect((await entryRepo.getTodayEntry())!.photoPath, '/old.jpg');
      expect(fakePhoto.deletedPaths, isEmpty);
      expect(container.read(journalChangesProvider), before);
    });
  });

  group('build', () {
    test('initial state is not completed when no entry exists', () async {
      final state = await container.read(todayControllerProvider.future);
      expect(state.isCompleted, isFalse);
      expect(state.emotion, isNull);
      expect(state.existingEntry, isNull);
    });

    test('loads existing entry when today already has data', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 4,
          prompt1: '감사',
          answer1: '좋은 날씨',
          prompt2: '',
          answer2: '',
          prompt3: '',
          answer3: '',
        ),
      );

      final state = await container.read(todayControllerProvider.future);
      expect(state.isCompleted, isTrue);
      expect(state.emotion, 4);
      expect(state.answer1, '좋은 날씨');
    });

    test(
      'keeps the saved questions when the current prompt settings changed',
      () async {
        await settingsRepo.setSetting('prompt_1', '새 질문');
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.getTodayString(),
            emotion: 4,
            prompt1: '저장 당시 질문',
            answer1: '좋은 날씨',
            prompt2: '저장 당시 질문 2',
            answer2: '',
            prompt3: '저장 당시 질문 3',
            answer3: '',
          ),
        );

        final state = await container.read(todayControllerProvider.future);

        expect(state.prompts, ['저장 당시 질문', '저장 당시 질문 2', '저장 당시 질문 3']);
      },
    );

    test(
      'falls back to current questions for entries without saved snapshots',
      () async {
        await settingsRepo.setSetting('prompt_1', '현재 질문');
        await entryRepo.saveEntry(
          DailyEntry(date: du.getTodayString(), emotion: 4, answer1: '예전 답변'),
        );

        final state = await container.read(todayControllerProvider.future);

        expect(state.prompts.first, '현재 질문');
        expect(
          state.prompts.skip(1).every((prompt) => prompt.isNotEmpty),
          isTrue,
        );
      },
    );
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
      final changesBefore = container.read(journalChangesProvider);

      final success = await notifier.save();

      expect(success, isTrue);
      expect(container.read(journalChangesProvider), changesBefore + 1);

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

      // Enable editing, attach a new photo, then save.
      notifier.toggleEdit();
      await notifier.attachPhoto('/new/photo.jpg');
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
      await notifier.attachPhoto('/photos/new.jpg');
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, '/photos/new.jpg');
    });

    test('deletes previous unsaved photo when attaching a new one', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      // Attach first photo (not saved to DB)
      await notifier.attachPhoto('/photos/first.jpg');
      // Attach second photo — first should be deleted
      await notifier.attachPhoto('/photos/second.jpg');

      expect(fakePhoto.deletedPaths, contains('/photos/first.jpg'));
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, '/photos/second.jpg');
    });

    test(
      'does not delete DB-saved photo when replacing with new one',
      () async {
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
        notifier.toggleEdit();
        await notifier.attachPhoto('/photos/new.jpg');

        expect(fakePhoto.deletedPaths, isNot(contains('/db/photo.jpg')));
      },
    );

    test(
      'discards a photo returned after edit mode has been cancelled',
      () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.getTodayString(),
            emotion: 3,
            answer1: '기존 답변',
            photoPath: '/db/photo.jpg',
          ),
        );
        await container.read(todayControllerProvider.future);
        final notifier = container.read(todayControllerProvider.notifier);

        notifier.toggleEdit();
        await notifier.cancelEdit();
        await notifier.attachPhoto('/photos/late.jpg');

        final state = container.read(todayControllerProvider).value;
        expect(state?.isEditing, isFalse);
        expect(state?.photoPath, '/db/photo.jpg');
        expect(fakePhoto.deletedPaths, contains('/photos/late.jpg'));
      },
    );
  });

  group('toggleEdit', () {
    test('toggles isEditing between true and false', () async {
      await entryRepo.saveEntry(
        DailyEntry(date: du.getTodayString(), emotion: 3, answer1: '기존 답변'),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      expect(container.read(todayControllerProvider).value?.isEditing, isFalse);
      notifier.toggleEdit();
      expect(container.read(todayControllerProvider).value?.isEditing, isTrue);
      notifier.toggleEdit();
      expect(container.read(todayControllerProvider).value?.isEditing, isFalse);
    });
  });

  group('cancelEdit', () {
    test('restores persisted fields and exits edit mode', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          prompt1: '감사',
          answer1: '기존 답변',
          prompt2: '수용',
          answer2: '기존 수용',
          prompt3: '의도',
          answer3: '기존 의도',
          photoPath: '/db/photo.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.toggleEdit();
      notifier.setEmotion(5);
      notifier.setAnswer(0, '수정한 답변');
      notifier.setAnswer(1, '수정한 수용');
      notifier.setAnswer(2, '수정한 의도');
      await notifier.attachPhoto('/new/photo.jpg');

      await notifier.cancelEdit();

      final state = container.read(todayControllerProvider).value;
      expect(state?.emotion, 3);
      expect(state?.answer1, '기존 답변');
      expect(state?.answer2, '기존 수용');
      expect(state?.answer3, '기존 의도');
      expect(state?.photoPath, '/db/photo.jpg');
      expect(state?.isEditing, isFalse);
    });

    test(
      'deletes newly attached photo but preserves persisted photo',
      () async {
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.getTodayString(),
            emotion: 3,
            answer1: '기존 답변',
            photoPath: '/db/photo.jpg',
          ),
        );
        await container.read(todayControllerProvider.future);
        final notifier = container.read(todayControllerProvider.notifier);

        notifier.toggleEdit();
        await notifier.attachPhoto('/new/photo.jpg');

        await notifier.cancelEdit();

        expect(fakePhoto.deletedPaths, contains('/new/photo.jpg'));
        expect(fakePhoto.deletedPaths, isNot(contains('/db/photo.jpg')));
      },
    );

    test('restores the entry even when unsaved photo cleanup throws', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '기존 답변',
          photoPath: '/db/photo.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.toggleEdit();
      notifier.setAnswer(0, '수정한 답변');
      await notifier.attachPhoto('/new/photo.jpg');
      fakePhoto.deleteError = StateError('사진 삭제 실패');

      await notifier.cancelEdit();

      final state = container.read(todayControllerProvider).value;
      expect(state?.answer1, '기존 답변');
      expect(state?.photoPath, '/db/photo.jpg');
      expect(state?.isEditing, isFalse);
      expect(state?.isCancelling, isFalse);
    });

    test('does nothing when not editing a saved entry', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      await notifier.cancelEdit();

      final state = container.read(todayControllerProvider).value;
      expect(state?.isEditing, isFalse);
      expect(state?.photoPath, isNull);
    });

    test('does not interrupt an in-progress save', () async {
      await entryRepo.saveEntry(
        DailyEntry(date: du.getTodayString(), emotion: 3, answer1: '기존 답변'),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.toggleEdit();
      notifier.setAnswer(0, '저장할 수정');
      final saveFuture = notifier.save();

      await notifier.cancelEdit();

      final savingState = container.read(todayControllerProvider).value;
      expect(savingState?.isEditing, isTrue);
      expect(savingState?.answer1, '저장할 수정');
      await saveFuture;
    });

    test('blocks edits and saves while discarding an unsaved photo', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '기존 답변',
          photoPath: '/db/photo.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      fakePhoto.deleteStarted = Completer<void>();
      fakePhoto.deleteGate = Completer<void>();

      notifier.toggleEdit();
      notifier.setAnswer(0, '수정한 답변');
      await notifier.attachPhoto('/new/photo.jpg');
      final cancelFuture = notifier.cancelEdit();
      await fakePhoto.deleteStarted!.future;

      expect(
        container.read(todayControllerProvider).value?.isCancelling,
        isTrue,
      );
      notifier.setAnswer(0, '취소 중 변경');
      expect(container.read(todayControllerProvider).value?.answer1, '수정한 답변');
      expect(await notifier.save(), isFalse);

      fakePhoto.deleteGate!.complete();
      await cancelFuture;

      final state = container.read(todayControllerProvider).value;
      expect(state?.answer1, '기존 답변');
      expect(state?.photoPath, '/db/photo.jpg');
      expect(state?.isCancelling, isFalse);
      expect((await entryRepo.getTodayEntry())?.answer1, '기존 답변');
    });

    test('blocks edits and photo changes while saving', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '기존 답변',
          photoPath: '/db/photo.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      fakePhoto.deleteStarted = Completer<void>();
      fakePhoto.deleteGate = Completer<void>();

      notifier.toggleEdit();
      notifier.setAnswer(0, '저장할 답변');
      await notifier.attachPhoto('/new/photo.jpg');
      final saveFuture = notifier.save();
      await fakePhoto.deleteStarted!.future;

      notifier.setAnswer(0, '저장 중 변경');
      final lateAttach = notifier.attachPhoto('/late/photo.jpg');
      await notifier.removePhoto();

      final savingState = container.read(todayControllerProvider).value;
      expect(savingState?.answer1, '저장할 답변');
      expect(savingState?.photoPath, '/new/photo.jpg');
      expect(fakePhoto.deletedPaths, isNot(contains('/new/photo.jpg')));

      fakePhoto.deleteGate!.complete();
      await lateAttach;
      expect(await saveFuture, isTrue);

      final saved = await entryRepo.getTodayEntry();
      expect(saved?.answer1, '저장할 답변');
      expect(saved?.photoPath, '/new/photo.jpg');
      expect(fakePhoto.deletedPaths, contains('/late/photo.jpg'));
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
        await entryRepo.saveEntry(
          DailyEntry(
            date: du.dateToString(date),
            emotion: 3,
            answer1: '사전 데이터',
          ),
        );
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

    test('keeps the committed entry when old photo cleanup fails', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '기존 답변',
          photoPath: '/old/photo.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.toggleEdit();
      notifier.setAnswer(0, '저장된 답변');
      await notifier.attachPhoto('/new/photo.jpg');
      fakePhoto.deleteError = StateError('사진 삭제 실패');

      expect(await notifier.save(), isTrue);

      final state = container.read(todayControllerProvider).value;
      final saved = await entryRepo.getTodayEntry();
      expect(state?.isCompleted, isTrue);
      expect(state?.isSaving, isFalse);
      expect(state?.answer1, '저장된 답변');
      expect(state?.photoPath, '/new/photo.jpg');
      expect(saved?.answer1, '저장된 답변');
      expect(saved?.photoPath, '/new/photo.jpg');
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

  group('completed entry guards', () {
    test('rejects direct mutations outside edit mode', () async {
      await entryRepo.saveEntry(
        DailyEntry(
          date: du.getTodayString(),
          emotion: 3,
          answer1: '기존 답변',
          photoPath: '/db/photo.jpg',
        ),
      );
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);

      notifier.setEmotion(5);
      notifier.setAnswer(0, '변경된 답변');
      await notifier.attachPhoto('/photos/late.jpg');
      await notifier.removePhoto();

      expect(await notifier.save(), isFalse);
      final state = container.read(todayControllerProvider).value;
      expect(state?.emotion, 3);
      expect(state?.answer1, '기존 답변');
      expect(state?.photoPath, '/db/photo.jpg');
      expect(fakePhoto.deletedPaths, contains('/photos/late.jpg'));
    });
  });

  group('removePhoto', () {
    test('clears photoPath in state', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      await notifier.attachPhoto('/photos/some.jpg');
      await notifier.removePhoto();
      final state = container.read(todayControllerProvider).value;
      expect(state?.photoPath, isNull);
    });

    test('deletes unsaved photo file immediately', () async {
      await container.read(todayControllerProvider.future);
      final notifier = container.read(todayControllerProvider.notifier);
      await notifier.attachPhoto('/photos/unsaved.jpg');
      await notifier.removePhoto();
      expect(fakePhoto.deletedPaths, contains('/photos/unsaved.jpg'));
    });

    test(
      'does not delete DB-saved photo on remove (deferred to save)',
      () async {
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
        notifier.toggleEdit();
        await notifier.removePhoto();

        // DB photo must NOT be deleted here — it's cleaned up only on save()
        expect(fakePhoto.deletedPaths, isNot(contains('/db/photo.jpg')));
        final state = container.read(todayControllerProvider).value;
        expect(state?.photoPath, isNull);
      },
    );

    test(
      'persists a removed photo while its file deletion is pending',
      () async {
        await container.read(todayControllerProvider.future);
        final notifier = container.read(todayControllerProvider.notifier);
        notifier.setEmotion(3);
        notifier.setAnswer(0, '사진 제거 후 저장');
        await notifier.attachPhoto('/photos/unsaved.jpg');
        fakePhoto.deleteStarted = Completer<void>();
        fakePhoto.deleteGate = Completer<void>();

        final removeFuture = notifier.removePhoto();
        await fakePhoto.deleteStarted!.future;
        expect(
          container.read(todayControllerProvider).value?.photoPath,
          isNull,
        );

        expect(await notifier.save(), isTrue);
        fakePhoto.deleteGate!.complete();
        await removeFuture;

        final state = container.read(todayControllerProvider).value;
        final saved = await entryRepo.getTodayEntry();
        expect(state?.isCompleted, isTrue);
        expect(state?.photoPath, isNull);
        expect(saved?.photoPath, isNull);
      },
    );
  });
}
