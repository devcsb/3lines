import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/core/theme/app_theme.dart';
import 'package:three_lines/features/settings/widgets/info_section.dart';
import 'package:three_lines/features/settings/widgets/security_section.dart';

void main() {
  testWidgets('정보 안내는 자체 서버와 운영체제 백업 범위를 구별한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: InfoSection(appVersion: '1.0')),
        ),
      ),
    );
    expect(
      find.text('3Lines는 기록을 자체 서버로 전송하지 않아요. 운영체제 설정에 따라 앱 데이터가 백업될 수 있어요'),
      findsOneWidget,
    );
  });
  testWidgets('앱 잠금 안내는 진입 보호와 파일 암호화를 구별한다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SecuritySection(biometricLockEnabled: false),
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('기기 인증으로 앱 진입을 보호해요. 기록 파일을 암호화하거나 스크린샷을 차단하지는 않아요'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(SwitchListTile)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
