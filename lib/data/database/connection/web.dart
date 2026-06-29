import 'package:drift/drift.dart';
// 웹은 1차 타깃이 아니라 deprecated WebDatabase를 유지한다.
// ponytail: 웹을 정식 지원하면 package:drift/wasm.dart의 WasmDatabase로 이관.
// ignore: deprecated_member_use
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return WebDatabase('three_lines');
}
