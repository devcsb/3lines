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
}
