import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/shared/widgets/staggered_fade_in.dart';

void main() {
  testWidgets('renders child widget after animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StaggeredFadeIn(
          index: 0,
          child: Text('fade me'),
        ),
      ),
    ));

    // Pump to let Future.delayed(0) fire, then settle the animation
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('fade me'), findsOneWidget);
  });

  testWidgets('contains FadeTransition and SlideTransition', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StaggeredFadeIn(
          index: 0,
          child: Text('test'),
        ),
      ),
    ));

    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(SlideTransition), findsWidgets);
  });
}
