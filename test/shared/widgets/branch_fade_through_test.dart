import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/shared/widgets/branch_fade_through.dart';

void main() {
  testWidgets('transitionKey가 바뀌면 240ms fade-through를 재생한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: BranchFadeThrough(
        transitionKey: 0,
        child: Text('첫 화면'),
      ),
    ));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(
      home: BranchFadeThrough(
        transitionKey: 1,
        child: Text('다음 화면'),
      ),
    ));
    await tester.pump();

    final fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey<String>('branch-fade-through')),
    );
    expect(fade.opacity.value, lessThan(1.0));
    expect(find.text('첫 화면'), findsNothing);
    expect(find.text('다음 화면'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 240));
    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey<String>('branch-fade-through')),
          )
          .opacity
          .value,
      1.0,
    );
  });

  testWidgets('reduce-motion이면 전환을 기다리지 않는다', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: BranchFadeThrough(
          transitionKey: 0,
          child: Text('첫 화면'),
        ),
      ),
    ));
    await tester.pump();

    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: BranchFadeThrough(
          transitionKey: 1,
          child: Text('다음 화면'),
        ),
      ),
    ));
    await tester.pump();

    expect(
      tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey<String>('branch-fade-through')),
          )
          .opacity
          .value,
      1.0,
    );
  });
}
