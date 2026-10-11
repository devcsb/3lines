import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/settings/widgets/notifications_section.dart';

void main() {
  testWidgets('매일 리마인더는 하루 한 번과 기록한 날 건너뜀을 안내한다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: NotificationsSection(enabled: true, hour: 21, minute: 15),
          ),
        ),
      ),
    );
    expect(find.text('매일 리마인더'), findsOneWidget);
    expect(find.text('설정한 시각에 하루 한 번 알려드려요. 기록한 날은 건너뛰어요.'), findsOneWidget);
    expect(find.text('21:15'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
