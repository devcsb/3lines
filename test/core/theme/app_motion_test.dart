import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/theme/app_motion.dart';

void main() {
  test('공통 모션 토큰은 PRD의 상한과 일치한다', () {
    expect(AppMotion.instant, Duration.zero);
    expect(AppMotion.micro, const Duration(milliseconds: 120));
    expect(AppMotion.standard, const Duration(milliseconds: 240));
    expect(AppMotion.entrance, const Duration(milliseconds: 360));
    expect(AppMotion.celebration, const Duration(milliseconds: 600));
    expect(AppMotion.standardCurve, Curves.easeOutCubic);
  });

  testWidgets('reduce-motion에서는 일반 duration을 즉시 상태로 바꾼다', (tester) async {
    Duration? resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            resolved = AppMotion.durationFor(context, AppMotion.entrance);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved, AppMotion.instant);
  });

  testWidgets('일반 모드에서는 전달한 duration을 유지한다', (tester) async {
    Duration? resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: false),
        child: Builder(
          builder: (context) {
            resolved = AppMotion.durationFor(context, AppMotion.standard);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved, AppMotion.standard);
  });
}
