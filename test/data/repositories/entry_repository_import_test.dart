import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/entry_import.dart';
import 'package:three_lines/data/repositories/entry_repository.dart';

import '../../helpers/import_fixtures.dart';

void main() {
  late AppDatabase db;
  late EntryRepository repo;
  late MutableImportClock clock;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = MutableImportClock(DateTime(2026, 9, 30, 12));
    repo = EntryRepository(db, clock: clock);
  });
  tearDown(() => db.close());

  test('미리보기는 DB와 입력을 바꾸지 않고 충돌 스냅샷을 고정한다', () async {
    await repo.saveEntry(
      DailyEntry(date: '2026-09-29', emotion: 2, answer1: '로컬'),
      preserveTimestamps: true,
    );
    final preview = await repo.previewImport(
      jsonEncode([
        importRecord('2026-09-29'),
        importRecord('2026-09-28'),
        null,
        importRecord('2026-09-28'),
      ]),
    );
    expect(
      (
        preview.newCount,
        preview.conflictCount,
        preview.parsed.invalid,
        preview.parsed.duplicate,
      ),
      (1, 1, 1, 1),
    );
    expect(await repo.getTotalCount(), 1);
    expect((await repo.getEntryByDate('2026-09-29'))!.answer1, '로컬');
    expect(() => preview.conflicts.clear(), throwsUnsupportedError);
    expect(() => preview.parsed.candidates.clear(), throwsUnsupportedError);
    await repo.saveEntry(
      DailyEntry(date: '2026-09-29', emotion: 5, answer1: '변경'),
      preserveTimestamps: true,
    );
    expect(preview.conflicts['2026-09-29']!.answer1, '로컬');
  });

  test('두 번째 실제 INSERT 실패는 첫 INSERT도 rollback한다', () async {
    await repo.getTotalCount();
    await db.customStatement('''
      CREATE TRIGGER fail_second_import BEFORE INSERT ON entries
      WHEN NEW.date = '2026-09-29'
      BEGIN SELECT RAISE(ABORT, 'injected failure'); END;
    ''');
    final preview = await repo.previewImport(
      jsonEncode([importRecord('2026-09-28'), importRecord('2026-09-29')]),
    );
    await expectLater(repo.applyImport(preview), throwsA(isA<Exception>()));
    expect(await repo.getTotalCount(), 0);
    await db.customStatement('DROP TRIGGER fail_second_import');
    expect((await repo.applyImport(preview)).inserted, 2);
  });

  test('여섯 카운터는 배타적이고 합은 입력 건수다', () async {
    for (final date in ['2026-09-25', '2026-09-26']) {
      await repo.saveEntry(
        DailyEntry(date: date, emotion: 2, answer1: '로컬'),
        preserveTimestamps: true,
      );
    }
    final preview = await repo.previewImport(
      jsonEncode([
        importRecord('2026-09-25'),
        importRecord('2026-09-26'),
        importRecord('2026-09-27'),
        importRecord('2026-09-28'),
        null,
        importRecord('2026-09-28'),
      ]),
    );
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
    final result = await repo.applyImport(
      preview,
      policy: ConflictPolicy.replacePreviewed,
    );
    expect(
      (
        result.inserted,
        result.replaced,
        result.conflictSkipped,
        result.changedSincePreview,
        result.invalid,
        result.duplicate,
      ),
      (1, 1, 1, 1, 1, 1),
    );
    expect(result.total, 6);
    expect((await repo.getEntryByDate('2026-09-27'))!.answer1, '새 충돌');
  });

  test('시계 역행은 첫 후보만 강등하고 자정 뒤 제외 입력도 승격하지 않는다', () async {
    final preview = await repo.previewImport(
      jsonEncode([
        importRecord('2026-09-30'),
        importRecord('2026-09-30'),
        importRecord('2026-10-01'),
      ]),
    );
    expect(clock.reads, 1);
    clock.value = DateTime(2026, 9, 29, 23);
    final result = await repo.applyImport(preview);
    expect(clock.reads, 2);
    expect(
      (result.inserted, result.invalid, result.duplicate, result.total),
      (0, 2, 1, 3),
    );
    clock.value = DateTime(2026, 10, 1);
    final next = await repo.applyImport(preview);
    expect(clock.reads, 3);
    expect((next.inserted, next.invalid, next.duplicate), (1, 1, 1));
    expect(await repo.getEntryByDate('2026-10-01'), isNull);
  });

  test('기본 보존과 삭제된 충돌을 구분하고 로컬 사진 및 생성 시각을 유지한다', () async {
    final original = DailyEntry(
      date: '2026-09-29',
      emotion: 2,
      answer1: '로컬',
      photoPath: '/local/photo.jpg',
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2),
    );
    await repo.saveEntry(original, preserveTimestamps: true);
    final preview = await repo.previewImport(
      jsonEncode([
        {
          ...importRecord('2026-09-29'),
          'created_at': null,
          'updated_at': null,
          'photo_path': {'malicious': '/outside/secret.db'},
        },
      ]),
    );
    expect((await repo.applyImport(preview)).conflictSkipped, 1);
    expect((await repo.getEntryByDate('2026-09-29'))!.answer1, '로컬');
    expect(
      (await repo.applyImport(
        preview,
        policy: ConflictPolicy.replacePreviewed,
      )).replaced,
      1,
    );
    final row = (await repo.getEntryByDate('2026-09-29'))!;
    expect(
      (row.createdAt, row.photoPath, row.updatedAt, row.answer1),
      (original.createdAt, original.photoPath, clock.value, '기록'),
    );
    await repo.deleteEntry('2026-09-29');
    clock.value = DateTime(2026, 9, 30, 13);
    expect(
      (await repo.applyImport(
        preview,
        policy: ConflictPolicy.replacePreviewed,
      )).inserted,
      1,
    );
    final inserted = (await repo.getEntryByDate('2026-09-29'))!;
    expect(
      (inserted.createdAt, inserted.updatedAt, inserted.photoPath),
      (clock.value, clock.value, null),
    );
  });

  for (final field in ['created', 'updated']) {
    test('$field timestamp만 바뀐 충돌도 교체하지 않는다', () async {
      await repo.saveEntry(
        DailyEntry(
          date: '2026-09-29',
          emotion: 2,
          answer1: '로컬',
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 2),
        ),
        preserveTimestamps: true,
      );
      final preview = await repo.previewImport(
        jsonEncode([importRecord('2026-09-29')]),
      );
      final changedTime = DateTime(2026, 9, 3);
      await (db.update(
        db.entries,
      )..where((t) => t.date.equals('2026-09-29'))).write(
        EntriesCompanion(
          createdAt: field == 'created'
              ? Value(changedTime)
              : const Value.absent(),
          updatedAt: field == 'updated'
              ? Value(changedTime)
              : const Value.absent(),
        ),
      );
      final result = await repo.applyImport(
        preview,
        policy: ConflictPolicy.replacePreviewed,
      );
      expect((result.replaced, result.changedSincePreview), (0, 1));
      expect((await repo.getEntryByDate('2026-09-29'))!.answer1, '로컬');
      expect((await repo.applyImport(preview)).conflictSkipped, 1);
    });
  }

  test('신규 timezone timestamp와 교체 updatedAt을 보존한다', () async {
    final created = DateTime.parse('2026-09-01T09:10:11+09:00');
    final updated = DateTime.parse('2026-09-02T10:11:12+09:00');
    final input = jsonEncode([
      {
        ...importRecord('2026-09-29', emotion: 5.0),
        'created_at': created.toIso8601String(),
        'updated_at': updated.toIso8601String(),
      },
    ]);
    final initial = await repo.previewImport(input);
    expect((await repo.applyImport(initial)).inserted, 1);
    final row = (await repo.getEntryByDate('2026-09-29'))!;
    expect(row.createdAt.toUtc(), created);
    expect(row.updatedAt.toUtc(), updated);
    final newUpdated = DateTime.parse('2026-09-03T12:00:00-04:00');
    final replacement = await repo.previewImport(
      jsonEncode([
        {
          ...importRecord('2026-09-29'),
          'created_at': '2020-01-01T00:00:00Z',
          'updated_at': newUpdated.toIso8601String(),
        },
      ]),
    );
    expect(
      (await repo.applyImport(
        replacement,
        policy: ConflictPolicy.replacePreviewed,
      )).replaced,
      1,
    );
    final replaced = (await repo.getEntryByDate('2026-09-29'))!;
    expect(replaced.createdAt.toUtc(), created);
    expect(replaced.updatedAt.toUtc(), newUpdated);
  });
}
