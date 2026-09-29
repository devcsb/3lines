import 'dart:async';
import 'dart:convert';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/data/models/daily_entry.dart';
import 'package:three_lines/data/models/entry_import.dart';
import 'package:three_lines/features/settings/widgets/import_preview_dialog.dart';

import '../../../helpers/import_fixtures.dart';

void main() {
  ImportPreview preview({int conflicts = 0}) {
    final dates = List.generate(
      conflicts == 0 ? 1 : conflicts,
      (i) => '2026-09-${(i + 1).toString().padLeft(2, '0')}',
    );
    return ImportPreview(
      parsed: parseImportJson(
        jsonEncode(dates.map(importRecord).toList()),
        now: DateTime(2026, 9, 30),
      ),
      conflicts: {
        if (conflicts > 0)
          for (final date in dates)
            date: DailyEntry(date: date, emotion: 2, answer1: '로컬'),
      },
    );
  }

  Future<void> open(
    WidgetTester tester,
    ImportPreview data,
    Future<ImportResult> Function(ConflictPolicy) apply, {
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<ImportResult>(
                context: context,
                builder: (_) =>
                    ImportPreviewDialog(preview: data, onApply: apply),
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  const success = ImportResult(
    inserted: 1,
    replaced: 0,
    conflictSkipped: 0,
    changedSincePreview: 0,
    invalid: 0,
    duplicate: 0,
  );

  for (final size in [const Size(320, 640), const Size(640, 320)]) {
    testWidgets('$size 200%에서 스크롤과 기본 보존 확인 재탭은 한 번 적용한다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gate = Completer<ImportResult>();
      final policies = <ConflictPolicy>[];
      await open(tester, preview(conflicts: 29), (policy) {
        policies.add(policy);
        return gate.future;
      }, scale: 2);
      await tester.ensureVisible(find.text('2026-09-29'));
      await tester.pumpAndSettle();
      expect(find.text('2026-09-29'), findsOneWidget);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('가져오기'));
      await tester.tap(find.text('가져오기'));
      await tester.tap(find.text('가져오기'));
      await tester.pump();
      expect(policies, [ConflictPolicy.preserve]);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '취소'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ImportPreviewDialog), findsOneWidget);
      gate.complete(success);
      await tester.pumpAndSettle();
      expect(find.byType(ImportPreviewDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('취소와 route back은 적용하지 않는다', (tester) async {
    var applications = 0;
    Future<ImportResult> apply(ConflictPolicy _) async {
      applications++;
      return success;
    }

    await open(tester, preview(), apply);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(applications, 0);
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(applications, 0);
    expect(find.byType(ImportPreviewDialog), findsNothing);
  });

  testWidgets('명시적 교체 체크 상태를 semantics와 적용 policy에 전달한다', (tester) async {
    final semantics = tester.ensureSemantics();
    ConflictPolicy? selected;
    await open(tester, preview(conflicts: 1), (policy) async {
      selected = policy;
      return success;
    });
    final checkbox = find.byType(CheckboxListTile);
    expect(
      tester
          .getSemantics(checkbox)
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isFalse,
    );
    await tester.tap(checkbox);
    await tester.pump();
    expect(
      tester
          .getSemantics(checkbox)
          .getSemanticsData()
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );
    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();
    expect(selected, ConflictPolicy.replacePreviewed);
    semantics.dispose();
  });

  testWidgets('적용 실패는 원문 없이 재시도를 허용하고 재탭은 막는다', (tester) async {
    var attempts = 0;
    final retryGate = Completer<ImportResult>();
    await open(tester, preview(), (_) {
      attempts++;
      if (attempts == 1) return Future.error(StateError('RAW_MARKER'));
      return retryGate.future;
    });
    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();
    expect(find.text('가져오기에 실패했어요. 다시 시도해 주세요'), findsOneWidget);
    expect(find.textContaining('RAW_MARKER'), findsNothing);
    expect(find.textContaining('가져오기 결과'), findsNothing);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '다시 시도'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('다시 시도'));
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(attempts, 2);
    retryGate.complete(success);
    await tester.pumpAndSettle();
    expect(find.byType(ImportPreviewDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
