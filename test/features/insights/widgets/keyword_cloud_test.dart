import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/insights/widgets/keyword_cloud.dart';

void main() {
  Widget buildApp({Map<String, int> keywords = const {}}) {
    return MaterialApp(
      home: Scaffold(
        body: KeywordCloud(keywords: keywords),
      ),
    );
  }

  testWidgets('shows empty message when no keywords', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(find.text('아직 분석할 키워드가 부족해요'), findsOneWidget);
  });

  testWidgets('shows title when keywords exist', (tester) async {
    await tester.pumpWidget(buildApp(keywords: {'감사': 5, '날씨': 3}));
    expect(find.text('자주 쓰는 단어'), findsOneWidget);
  });

  testWidgets('renders chips for each keyword', (tester) async {
    await tester.pumpWidget(buildApp(keywords: {'감사': 5, '날씨': 3, '가족': 2}));
    expect(find.byType(Chip), findsNWidgets(3));
    expect(find.text('감사'), findsOneWidget);
    expect(find.text('날씨'), findsOneWidget);
    expect(find.text('가족'), findsOneWidget);
  });

  testWidgets('uses Wrap layout', (tester) async {
    await tester.pumpWidget(buildApp(keywords: {'테스트': 1}));
    expect(find.byType(Wrap), findsOneWidget);
  });

  testWidgets('accepts custom title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KeywordCloud(
          keywords: const {'감사': 1},
          title: '커스텀 제목',
        ),
      ),
    ));
    expect(find.text('커스텀 제목'), findsOneWidget);
  });
}
