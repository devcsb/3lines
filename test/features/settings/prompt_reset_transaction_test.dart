import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/constants/default_prompts.dart';
import 'package:three_lines/core/events/journal_changes.dart';
import 'package:three_lines/core/time/app_clock.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/settings_controller.dart';
import 'package:three_lines/features/today/today_controller.dart';

class _ResetClock extends AppClock {
  @override
  DateTime now() => DateTime(2026, 10, 11, 9);
}

void main() {
  late AppDatabase db;
  late SettingsRepository settings;
  const custom = ['첫 사용자 질문', '두 번째 사용자 질문', '세 번째 사용자 질문'];

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(db);
    for (var index = 0; index < custom.length; index++) {
      await settings.setSetting('prompt_${index + 1}', custom[index]);
    }
  });
  tearDown(() => db.close());

  Future<void> blockSecondWrite() => db.customStatement(
    "CREATE TRIGGER fail_second_prompt BEFORE UPDATE ON settings WHEN NEW.key = 'prompt_2' BEGIN SELECT RAISE(ABORT, 'blocked second prompt'); END",
  );

  test('실제 SQLite 두 번째 질문 write 실패는 세 질문을 rollback하고 재시도한다', () async {
    await settings.setSetting('theme_mode', 'dark');
    await blockSecondWrite();
    await expectLater(settings.resetPrompts(), throwsA(isA<Exception>()));
    expect(await settings.getPrompts(), custom);
    expect(await settings.getSetting('theme_mode', defaultValue: ''), 'dark');
    await db.customStatement('DROP TRIGGER fail_second_prompt');
    await settings.resetPrompts();
    expect(await settings.getPrompts(), defaultPromptQuestions);
    expect(await settings.getSetting('theme_mode', defaultValue: ''), 'dark');
  });

  test('질문 reset 실패와 재시도는 작성 중인 live/영속 초안 snapshot을 유지한다', () async {
    final clock = _ResetClock();
    final entries = EntryRepository(db, clock: clock);
    final container = ProviderContainer(
      overrides: [
        appClockProvider.overrideWithValue(clock),
        entryRepositoryProvider.overrideWithValue(entries),
        settingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    container.listen(todayControllerProvider, (_, _) {});
    container.listen(settingsControllerProvider, (_, _) {});
    await container.read(todayControllerProvider.future);
    await container.read(settingsControllerProvider.future);
    final today = container.read(todayControllerProvider.notifier);
    today.setAnswer(0, '보존해야 하는 작성 중 입력');
    today.setEmotion(3);
    final before = container.read(todayControllerProvider).value!;
    final durableBefore = (await entries.loadDraft(before.draftDate))!.encode();
    final revisionBefore = container.read(journalChangesProvider);
    await blockSecondWrite();
    final controller = container.read(settingsControllerProvider.notifier);
    await expectLater(controller.resetPrompts(), throwsA(isA<Exception>()));
    expect(container.read(settingsControllerProvider).value!.prompts, custom);
    expect(container.read(journalChangesProvider), revisionBefore);
    expect(await settings.getPrompts(), custom);
    await db.customStatement('DROP TRIGGER fail_second_prompt');
    await controller.resetPrompts();
    expect(
      container.read(settingsControllerProvider).value!.prompts,
      defaultPromptQuestions,
    );
    expect(container.read(journalChangesProvider), revisionBefore + 1);
    final after = container.read(todayControllerProvider).value!;
    expect(after.prompts, custom);
    expect(after.answer1, '보존해야 하는 작성 중 입력');
    expect(after.session, before.session);
    expect(after.draftDate, before.draftDate);
    expect(after.draftRevision, before.draftRevision);
    expect(
      (await entries.loadDraft(before.draftDate))!.encode(),
      durableBefore,
    );
  });
}
