import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/database/app_database.dart';

void main() {
  for (final version in [1, 2]) {
    test('v$version 기록과 사진을 보존하고 책갈피 기본값을 추가한다', () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (sqlite) {
            sqlite.execute('''CREATE TABLE entries (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL UNIQUE,
          prompt1 TEXT NOT NULL DEFAULT '', answer1 TEXT NOT NULL DEFAULT '',
          prompt2 TEXT NOT NULL DEFAULT '', answer2 TEXT NOT NULL DEFAULT '',
          prompt3 TEXT NOT NULL DEFAULT '', answer3 TEXT NOT NULL DEFAULT '',
          emotion INTEGER NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          ${version == 2 ? ', photo_path TEXT' : ''}
        )''');
            sqlite.execute(
              'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)',
            );
            sqlite.execute(
              "INSERT INTO entries (date, emotion, answer1) VALUES ('2026-11-01', 2, '남겨둔 말')",
            );
            if (version == 2) {
              sqlite.execute(
                "UPDATE entries SET photo_path = '/photo/kept.jpg'",
              );
            }
            sqlite.execute('PRAGMA user_version = $version');
          },
        ),
      );
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT answer1, photo_path, is_bookmarked FROM entries',
          )
          .getSingle();
      expect(row.read<String>('answer1'), '남겨둔 말');
      expect(
        row.readNullable<String>('photo_path'),
        version == 2 ? '/photo/kept.jpg' : null,
      );
      expect(row.read<int>('is_bookmarked'), 0);
      expect(db.schemaVersion, 3);
    });
  }
}
