import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/widgets/photo_attachment.dart';

void main() {
  testWidgets('사진 추가 버튼은 48dp 조작 영역과 접근성 라벨을 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoAttachment(onPickCamera: () {}, onPickGallery: () {}),
        ),
      ),
    );

    final camera = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == '카메라',
    );
    expect(camera, findsOneWidget);
    final rect = tester.getRect(camera);
    expect(rect.width, greaterThanOrEqualTo(48));
    expect(rect.height, greaterThanOrEqualTo(48));

    semantics.dispose();
  });

  testWidgets('콜백이 없으면 사진 추가 버튼을 비활성 semantics로 노출한다', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PhotoAttachment())),
    );

    final camera = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == '카메라' &&
          widget.properties.enabled == false,
    );
    expect(camera, findsOneWidget);

    semantics.dispose();
  });
}
