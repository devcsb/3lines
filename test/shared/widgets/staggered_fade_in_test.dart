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

  testWidgets('reduce-motion snaps to final state without stagger delay',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const Scaffold(
              // index 10 이면 평소 ~1s 지연되지만 reduce-motion 이면 즉시 표시돼야 한다.
              body: StaggeredFadeIn(index: 10, child: Text('instant')),
            ),
          ),
        ),
      ),
    );

    // 스태거 지연을 pump 하지 않아도 이미 최종 상태여야 한다.
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find.byType(FadeTransition).first,
    );
    expect(fade.opacity.value, 1.0);
    expect(find.text('instant'), findsOneWidget);
  });

  testWidgets('높은 index도 480ms 안에 진입을 시작한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StaggeredFadeIn(
          key: ValueKey<String>('bounded-stagger'),
          index: 99,
          child: Text('bounded'),
        ),
      ),
    ));

    await tester.pump();
    final initial = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('bounded-stagger')),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(initial.opacity.value, lessThan(1.0));

    // The timer fires at the end of the 480ms delay pump. A following pump
    // advances the 360ms entrance controller to its final value.
    await tester.pump(const Duration(milliseconds: 480));
    await tester.pump(const Duration(milliseconds: 360));
    final after = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('bounded-stagger')),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(after.opacity.value, 1.0);
  });
}
