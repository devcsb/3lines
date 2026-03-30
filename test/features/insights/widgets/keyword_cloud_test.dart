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

  testWidgets('renders keyword items for each keyword', (tester) async {
    await tester.pumpWidget(buildApp(keywords: {'감사': 5, '날씨': 3, '가족': 2}));
    expect(find.text('감사'), findsOneWidget);
    expect(find.text('날씨'), findsOneWidget);
    expect(find.text('가족'), findsOneWidget);
  });

  testWidgets('uses Wrap layout', (tester) async {
    await tester.pumpWidget(buildApp(keywords: {'테스트': 1}));
    expect(find.byType(Wrap), findsOneWidget);
  });
}
