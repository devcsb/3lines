import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/database/app_database.dart';
import 'package:three_lines/data/repositories/settings_repository.dart';
import 'package:three_lines/features/settings/widgets/appearance_section.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  testWidgets('액센트 테마 선택지는 48dp 조작 영역과 선택 상태를 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AppearanceSection(themeMode: 'system')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == '기본 (Sage) 테마' &&
          widget.properties.selected == true,
    );
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));

    semantics.dispose();
  });
}
