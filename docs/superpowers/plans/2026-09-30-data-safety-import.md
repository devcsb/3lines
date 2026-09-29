# 기록 보존과 안전한 JSON 가져오기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 확인 없이 기록을 덮어쓰거나 외부 사진 경로를 지우지 않는 텍스트 JSON 가져오기와 내보내기를 제공한다.

**Architecture:** 작은 불변 import 모델과 순수 검증 함수를 만들고, 저장소에서 읽기 전용 미리보기와 단일 트랜잭션 적용을 분리한다. SettingsController와 확인 dialog는 이 결과를 전달하며, 사진 서비스는 실파일 소유 경계를 검증하고 호출자는 DB 커밋 뒤 현재 참조와 보존할 draft를 보호한다. 시작 정리와 picker는 같은 PhotoService 인스턴스의 짧은 보호 구간을 사용한다.

**Tech Stack:** Flutter, Dart SDK `^3.9.0`, Riverpod `^3.0.0`, Drift `^2.34.0`, `path ^1.9.0`, `path_provider ^2.1.5`, `file_picker ^11.0.0`, `image_picker ^1.2.2`, flutter_test, NativeDatabase.memory(). 새 패키지는 추가하지 않는다.

**Spec:** `docs/superpowers/specs/2026-09-30-data-safety-import-design.md`. 2026-09-30 사용자가 명세와 이 계획을 승인하고 실행을 지시했다. 격리 브랜치 `codex/data-safety-import-implementation`에서 구현한다. 실행 중 계약 조정과 검증은 `docs/superpowers/sdd/2026-09-30-data-safety-import/progress.md`에 기록한다.

## Global Constraints

- DB 스키마, `EntryRepository.saveEntry`의 일반 작성 계약, 현재 JSON 필드는 유지한다.
- JSON 기능은 “텍스트 기록 내보내기/가져오기”로 부른다. 새 export의 `photo_path`는 `null`, import 입력의 `photo_path`는 타입과 무관하게 무시한다. 사진 바이트는 포함하지 않는다.
- envelope `{ "app": "3Lines", "version": "문자열", "entries": [...] }`, app 없는 envelope, legacy bare list를 허용한다. 존재하는 app은 정확히 `3Lines`, 존재하는 version은 문자열이어야 한다.
- 날짜는 정확히 `yyyy-MM-dd` 형식, 실제 달력 날짜, AppClock의 로컬 오늘 이하이다. 미리보기와 적용은 같은 주입 clock을 사용하며 각 단계에서 `now()`를 한 번만 읽는다.
- 감정은 유한한 정수 1~5만 허용하며 `5.0`은 허용한다. prompts는 정확히 세 map, question/answer는 문자열, trim한 답변 하나 이상이 비어 있지 않아야 한다. 보정하거나 답변을 자르지 않는다.
- timestamp는 absent/null 또는 파싱 가능한 문자열이다. 새 기록의 미지정 시각은 적용 시각으로 채운다. 교체는 로컬 createdAt와 photoPath를 유지하고 입력 updatedAt 또는 적용 시각을 사용한다.
- 원본 입력, candidates, invalid, duplicate와 preview 충돌 행을 불변 스냅샷으로 고정한다. 첫 유효 날짜만 후보이고 무효 항목은 날짜를 선점하지 않는다.
- 기본은 preserve다. replace는 preview에서 본 충돌 행이 ID, 날짜, 감정, 세 질문/답변, 사진 경로, createdAt, updatedAt 모두 그대로일 때만 허용한다. timestamp를 제외하는 DailyEntry.==를 판정에 쓰지 않는다.
- 적용 시 새 충돌은 보존하고 사라진 preview 충돌은 신규 삽입한다. 시계 역행은 후보를 invalid로 강등할 뿐이다. 자정 이후 제외 입력이나 뒤의 duplicate를 승격하지 않는다.
- inserted/replaced/conflictSkipped/changedSincePreview/invalid/duplicate는 배타적이며 합은 입력 목록 건수다. 예상치 못한 DB 오류는 전체 rollback하며 부분 성공 결과를 반환하지 않는다.
- 취소는 쓰기 0건이다. 파일 선택부터 완료까지 busy guard, 확인은 one-shot, 동일 preview의 성공 적용은 재사용하지 않는다. 실패는 일반 오류로 표시하고 재시도를 허용한다. 성공한 변경의 저널 이벤트와 Today 갱신은 각각 한 번이다.
- 신뢰 기준은 플랫폼 Documents를 real path로 해석한 디렉터리다. 그 아래 photos root와 최종 파일 symlink는 거부하고 no-follow 조회/순회를 사용한다. 절대경로, 원래 경로에 `..` 없음, photos 직접 자식 조건을 모두 확인한다.
- 소유 basename은 `photo_<숫자로 된 밀리초>.<확장자>`, 허용 확장자는 대소문자 무관 `jpg`, `jpeg`, `png`, `heic`, `heif`, `webp`, `gif`, `bmp`, `avif`다. 목록 밖 기존 파일은 보존한다. 파일 내용 판별은 추가하지 않는다.
- 사진 삭제는 현재 DB 참조와 보존할 draft를 정규 경로로 비교한 뒤 수행한다. 참조 조회/정규화 실패는 보존한다. DB 커밋 뒤 파일 삭제 실패로 텍스트 저장/삭제를 실패로 바꾸지 않는다.
- 시작 보호는 DB 스냅샷 이전부터 cleanup finally까지다. 복사 경로는 copy 전에 예약하고 picker가 반환해도 정리 종료까지 유지한다. 같은 인스턴스를 provider에 override한다. 전역 락, 범용 filesystem 레이어, 공유 coordinator는 추가하지 않는다.
- 사용자 문구와 commit은 한국어다. 이번 가져오기와 사진 경계의 오류/로그에 파일 경로, JSON fragment, 질문/답변 원문 또는 예외 message를 넣지 않는다. 200% 글씨와 좁은 화면에서도 취소/확인을 완료할 수 있어야 한다.
- 계획 작성 중 제품 코드/테스트/의존성 변경, pub get, 테스트/빌드 실행은 하지 않는다. 문서와 승인 기록만 로컬 commit하며 외부 push나 릴리스 배포는 하지 않는다. 아래 구현 명령은 계획 승인 뒤 실행자에게 주는 명령이다.

## Review Focus

1. UTF-8 오류와 JSON parse 오류에 파일 내용이 포함되어도 화면/로그에는 일반 오류만 보여야 한다. Task 2에서 악성 bytes와 raw marker를 시험한다.
2. 질문/답변/사진은 그대로이고 timestamp만 바뀐 충돌도 replace하지 않아야 한다. Task 2에서 createdAt와 updatedAt만 각각 바꾸는 실제 DB 시험을 한다.
3. 같은 사진을 Documents 별칭 경로로 참조해도 삭제하지 않아야 한다. 참조 조회나 정규화가 실패해도 보존해야 한다. Task 4와 Task 6에서 실제 symlink 별칭 및 조회 실패를 시험한다.
4. 미리보기 화면을 닫거나 dispose하는 동안 읽기가 끝나도 쓰지 않아야 한다. 파일 선택 중 재탭과 확인 재탭은 별도 guard로 막아야 한다. Task 2에서 gated 위젯 시험을 한다.
5. 시작 DB 스냅샷 이후 새 사진의 picker가 반환해도 정리 완료 전에는 파일이 남아야 한다. Task 5에서 실제 서비스와 copy/scan gate로 순서를 고정한다.

---

## 파일 책임과 실행 순서

| 작업 | 소유 파일 | 책임 |
| --- | --- | --- |
| 1 | `lib/data/models/entry_import.dart`, `test/data/models/entry_import_test.dart`, `test/helpers/import_fixtures.dart` | 불변 스냅샷, 엄격한 순수 JSON 검증, 고정 clock/입력 fixture |
| 2 | `lib/data/repositories/entry_repository.dart`, `lib/features/settings/settings_controller.dart`, `lib/features/settings/widgets/data_section.dart`, 새 `lib/features/settings/widgets/import_preview_dialog.dart`, `test/data/repositories/entry_repository_test.dart`, 새 `test/data/repositories/entry_repository_import_test.dart`, `test/features/settings/settings_controller_test.dart`, 새 `test/features/settings/widgets/data_section_test.dart`, 새 `test/features/settings/widgets/import_preview_dialog_test.dart` | import 수직 기능 전체와 기존 import 호출/시험의 동시 교체. 중간 consumer 컴파일 단절을 만들지 않음 |
| 3 | `lib/data/repositories/entry_repository.dart`, `lib/features/settings/widgets/data_section.dart`, `test/data/repositories/entry_repository_test.dart`, `test/features/settings/settings_controller_test.dart`, `test/features/settings/widgets/data_section_test.dart` | export 경계의 photo_path null과 내보내기 사진 경고 |
| 4 | `lib/core/services/photo_service.dart`, 새 `test/core/services/photo_service_test.dart`, `test/helpers/fake_photo_service.dart` | 소유 경로 판정, 참조 정규화, 안전한 명시 삭제와 고아 정리 |
| 5 | `lib/core/services/photo_service.dart`, `lib/app/bootstrap.dart`, `test/core/services/photo_service_test.dart`, 새 `test/app/photo_cleanup_bootstrap_test.dart` | 시작 보호 수명, 복사 예약, shared provider 인스턴스와 실제 race 시험 |
| 6 | `lib/features/today/today_controller.dart`, `lib/features/timeline/timeline_controller.dart`, `lib/features/settings/settings_controller.dart`, `test/features/today/today_controller_test.dart`, `test/features/timeline/timeline_controller_test.dart`, `test/features/settings/settings_controller_test.dart` | 커밋 후 현재 DB 참조와 retained draft 보호 |

`DailyEntry`, AppClock, DB 테이블/생성 코드는 읽기 참조만 한다. 파일마다 owner를 한 명만 배정한다. Task 1 → 2 → 3, Task 4 → 5, Task 2/4 → 6이다. Task 1과 4는 병렬 가능하며 Task 2/3과 5도 소유 파일이 겹치지 않는다. Task 3과 6은 settings 시험 파일이 겹쳐 직렬로 실행한다. Task 4와 5는 같은 파일을 동시에 편집하지 않는다.

사용자가 선택한 실행 방식은 task별 subagent 구현이다. 계획 승인 뒤 `using-git-worktrees`로 적합한 기존 격리 작업 공간을 확인하거나 승인된 브랜치 커밋에서 격리 공간을 만든다. 새 경로가 생기면 이 계획의 상대 경로와 명령을 그 공간 기준으로 실행하고 재개 기록에 절대 경로를 남긴다. 메인이 작업별 실행자와 새 리뷰어를 배정한다. 실행자는 재위임하지 않으며 다른 작업자의 변경을 되돌리지 않는다. 리뷰어는 해당 diff와 명세, 아래 해당 target gate 결과를 읽는다. 이미 돌린 게이트는 리뷰어가 재실행하지 않고 반례가 있으면 입력/순서/기대 결과를 구체적으로 보고한다. 5개 이상 파일 변경 작업은 이 독립 교차 검토를 반드시 받는다. 리뷰 통과 뒤 다음 의존 작업을 시작한다.

이 문서 끝의 재개 원장에는 owner, commit, 실행 명령/결과, 리뷰 결과, blocker를 메인이 갱신한다. 문서 owner와 실행자 변경이 겹치지 않게 원장 편집을 직렬화한다. 전체 분석/전체 시험은 마지막에 root가 한 번 실행한다.

### Task 1: 불변 import 계약과 순수 검증

**Files:** 위 파일 책임표의 Task 1. `pubspec.yaml`은 수정하지 않는다. 실행 시 pub get으로 lock 변경이 생기면 이유를 검토한 뒤 이 작업에 포함할지 결정한다.

**Interfaces:**
- Consumes: 기존 `DailyEntry(...)`, `AppClock.now() → DateTime`, `du.dateToString(DateTime) → String`.
- Produces: `enum ConflictPolicy { preserve, replacePreviewed }`; `parseImportJson(String jsonStr, {required DateTime now}) → ParsedImport`; `isImportDateValid(String date, DateTime now) → bool`; `sameImportSnapshot(DailyEntry a, DailyEntry b) → bool`.
- Produces: `ImportPrompt({required String question, required String answer})`; `ImportCandidate({required String date, required int emotion, required List<ImportPrompt> prompts, DateTime? createdAt, DateTime? updatedAt})`, 같은 이름의 final 필드와 `toEntry(DateTime now, {DailyEntry? replacing}) → DailyEntry`.
- Produces: `ParsedImport({required List<Object?> entries, required List<ImportCandidate> candidates, required int invalid, required int duplicate})`, final 필드, `inputCount → int`.
- Produces: `ImportPreview({required ParsedImport parsed, required Map<String, DailyEntry> conflicts})`, final 필드, `newCount → int`, `conflictCount → int`.
- Produces: `const ImportResult({required int inserted, required int replaced, required int conflictSkipped, required int changedSincePreview, required int invalid, required int duplicate})`, 같은 이름의 final 필드, `total → int`, `changedCount → int`.
- Produces 시험 fixture: `importRecord(String date, {Object emotion = 3, String answer = '기록'}) → Map<String, Object?>`; `MutableImportClock(DateTime value)` extends AppClock, mutable `value`, `int reads`, `now() → DateTime`.

- [ ] **Step 1: 실행 환경만 복구한다.** 계획 승인 뒤 `flutter pub get`을 한 번 실행한다. 기대 결과는 package_config에 flutter_timezone가 다시 등록되는 것이다. `git diff -- pubspec.lock`으로 변경 이유를 확인하며 불필요한 버전 상승을 요구하지 않는다. 계획 작성 때 확인한 analyze timezone 2건과 test `+346/-11`은 PASS 기준선이 아니다. 여기서 전체 gate를 재실행하지 않는다.
- [ ] **Step 2: fixture와 아래 실패 시험을 작성한다.** 새 테스트는 flutter_test와 entry_import.dart를 import한다. helper는 다음 내용을 갖는다.

```dart
Map<String, Object?> importRecord(String date,
    {Object emotion = 3, String answer = '기록'}) => {
  'date': date, 'emotion': emotion,
  'prompts': [
    {'question': '질문1', 'answer': answer},
    {'question': '질문2', 'answer': ''},
    {'question': '질문3', 'answer': ''},
  ],
};
class MutableImportClock extends AppClock {
  MutableImportClock(this.value);
  DateTime value;
  int reads = 0;
  @override
  DateTime now() { reads++; return value; }
}
test('무효 첫 항목은 날짜를 선점하지 않고 뒤 유효 항목만 중복이다', () {
  final parsed = parseImportJson(jsonEncode([
    importRecord('2026-09-29', emotion: 1.2),
    importRecord('2026-09-29', emotion: 5.0),
    importRecord('2026-09-29'), 7,
  ]), now: DateTime(2026, 9, 30));
  expect(parsed.candidates.single.emotion, 5);
  expect((parsed.invalid, parsed.duplicate, parsed.inputCount), (2, 1, 4));
  expect(() => parsed.candidates.clear(), throwsUnsupportedError);
  expect(() => parsed.entries.clear(), throwsUnsupportedError);
  final first = parsed.entries.first as Map;
  expect(() => first['date'] = '2000-01-01', throwsUnsupportedError);
  expect(() => (first['prompts'] as List).clear(), throwsUnsupportedError);
});
test('envelope 오류는 목록 분류와 구분한다', () {
  for (final bad in [
    '', 'null', '{}', '{"entries":{}}', '{"app":7,"entries":[]}',
    '{"app":"other","entries":[]}', '{"version":1,"entries":[]}',
  ]) {
    expect(() => parseImportJson(bad, now: DateTime(2026, 9, 30)),
        throwsFormatException);
  }
  for (final ok in ['[]', '{"entries":[]}',
      '{"app":"3Lines","version":"x","entries":[]}']) {
    expect(parseImportJson(ok, now: DateTime(2026, 9, 30)).inputCount, 0);
  }
});
test('날짜, 감정, 세 prompt와 timestamp를 엄격하게 분류한다', () {
  final bad = <Object?>[
    for (final date in ['2026-2-01', '2026-02-30', '2026-10-01'])
      importRecord(date),
    for (final emotion in [0, 6, 2.5, '3'])
      importRecord('2026-09-29', emotion: emotion),
    {...importRecord('2026-09-29'), 'prompts': []},
    {...importRecord('2026-09-29'), 'prompts': [1, 2, 3]},
    importRecord('2026-09-29', answer: ' \n '),
    {...importRecord('2026-09-29'), 'created_at': 4},
    {...importRecord('2026-09-29'), 'updated_at': 'broken'},
  ];
  final parsed = parseImportJson(jsonEncode(bad), now: DateTime(2026, 9, 30));
  expect(parsed.invalid, bad.length);
  expect(parsed.candidates, isEmpty);
  final valid = parseImportJson(jsonEncode([
    {...importRecord('2024-02-29'), 'created_at': null,
      'updated_at': '2026-09-29T09:00:00+09:00', 'photo_path': {'evil': true}},
  ]), now: DateTime(2026, 9, 30)).candidates.single;
  expect(valid.createdAt, isNull);
  expect(valid.updatedAt, DateTime.parse('2026-09-29T09:00:00+09:00'));
  expect(valid.toEntry(DateTime(2026, 9, 30)).photoPath, isNull);
});
```

- [ ] **Step 3: 실패를 확인한다.** `flutter test --no-pub test/data/models/entry_import_test.dart --reporter expanded`. 새 import 모델/함수가 미정의라 FAIL하는지 확인한다.
- [ ] **Step 4: 모델과 아래 parser를 구현한다.** entries는 list/map을 재귀적으로 unmodifiable로 복제하고 candidate.prompts와 preview.conflicts도 unmodifiable로 만든다. 필드와 getter는 Interfaces와 일치시킨다. inputCount=entries.length, newCount=candidates 중 conflicts에 없는 날짜 수, conflictCount=conflicts.length, total=여섯 카운터 합, changedCount=inserted+replaced이다.

```dart
Object? _freeze(Object? value) {
  if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
  if (value is Map) return Map<String, Object?>.unmodifiable(
      value.map((key, item) => MapEntry(key as String, _freeze(item))));
  return value;
}
bool isImportDateValid(String date, DateTime now) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return false;
  final y = int.parse(date.substring(0, 4));
  final m = int.parse(date.substring(5, 7));
  final d = int.parse(date.substring(8, 10));
  final value = DateTime.utc(y, m, d);
  final localNow = now.toLocal();
  return value.year == y && value.month == m && value.day == d &&
      !value.isAfter(DateTime.utc(localNow.year, localNow.month, localNow.day));
}
DateTime? _timestamp(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('시각 형식 오류');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('시각 형식 오류');
  return parsed;
}
ImportCandidate? _candidate(Object? value, DateTime now) {
  if (value is! Map) return null;
  final date = value['date'];
  final emotion = value['emotion'];
  final prompts = value['prompts'];
  if (date is! String || !isImportDateValid(date, now) || emotion is! num ||
      !emotion.isFinite || emotion != emotion.truncateToDouble() ||
      emotion < 1 || emotion > 5 || prompts is! List || prompts.length != 3) {
    return null;
  }
  final parsedPrompts = <ImportPrompt>[];
  for (final prompt in prompts) {
    if (prompt is! Map || prompt['question'] is! String ||
        prompt['answer'] is! String) return null;
    parsedPrompts.add(ImportPrompt(question: prompt['question'] as String,
        answer: prompt['answer'] as String));
  }
  if (parsedPrompts.every((p) => p.answer.trim().isEmpty)) return null;
  try {
    return ImportCandidate(date: date, emotion: emotion.toInt(),
      prompts: parsedPrompts, createdAt: _timestamp(value['created_at']),
      updatedAt: _timestamp(value['updated_at']));
  } on FormatException { return null; }
}
ParsedImport parseImportJson(String jsonStr, {required DateTime now}) {
  final Object? decoded;
  try { decoded = jsonDecode(jsonStr); }
  on FormatException { throw const FormatException('JSON 형식 오류'); }
  final List<dynamic> entries;
  if (decoded is List) { entries = decoded; }
  else if (decoded is Map && decoded['entries'] is List &&
      (!decoded.containsKey('app') || decoded['app'] == '3Lines') &&
      (!decoded.containsKey('version') || decoded['version'] is String)) {
    entries = decoded['entries'] as List;
  } else { throw const FormatException('가져오기 형식 오류'); }
  final seen = <String>{};
  final candidates = <ImportCandidate>[];
  var invalid = 0;
  var duplicate = 0;
  for (final value in entries) {
    final candidate = _candidate(value, now);
    if (candidate == null) { invalid++; }
    else if (!seen.add(candidate.date)) { duplicate++; }
    else { candidates.add(candidate); }
  }
  return ParsedImport(entries: entries.map(_freeze).toList(),
      candidates: candidates, invalid: invalid, duplicate: duplicate);
}
// ImportCandidate.toEntry의 본문. 필드 문자열은 trim하지 않고 원문을 유지한다.
DailyEntry toEntry(DateTime now, {DailyEntry? replacing}) => DailyEntry(
  id: replacing?.id, date: date, emotion: emotion,
  prompt1: prompts[0].question, answer1: prompts[0].answer,
  prompt2: prompts[1].question, answer2: prompts[1].answer,
  prompt3: prompts[2].question, answer3: prompts[2].answer,
  createdAt: replacing?.createdAt ?? createdAt ?? now,
  updatedAt: updatedAt ?? now, photoPath: replacing?.photoPath,
);
bool sameImportSnapshot(DailyEntry a, DailyEntry b) =>
  a.id == b.id && a.date == b.date && a.emotion == b.emotion &&
  a.prompt1 == b.prompt1 && a.answer1 == b.answer1 &&
  a.prompt2 == b.prompt2 && a.answer2 == b.answer2 &&
  a.prompt3 == b.prompt3 && a.answer3 == b.answer3 &&
  a.photoPath == b.photoPath && a.createdAt == b.createdAt &&
  a.updatedAt == b.updatedAt;
```

- [ ] **Step 5: 대상 시험을 통과시키고 commit한다.** 위 시험 명령 PASS. `git add lib/data/models/entry_import.dart test/data/models/entry_import_test.dart test/helpers/import_fixtures.dart` 뒤 `git commit -m "feat: 가져오기 불변 모델과 엄격한 검증 추가"`. lock 변경은 검토한 경우만 별도로 명시해 stage한다. AI attribution을 넣지 않는다.

### Task 2: 미리보기부터 확인과 원자적 적용까지 연결

**Files:** 파일 책임표의 Task 2 전부. 기존 `importEntries`와 `importData` 및 기존 호출 시험은 같은 commit에서 제거/교체한다. 일반 saveEntry 시험은 그대로 둔다.

**Interfaces:**
- Consumes: Task 1의 모든 import 계약, 기존 `EntryRepository.getEntryByDate(String) → Future<DailyEntry?>`, `_toCompanion(DailyEntry, {bool preserveTimestamps = false}) → EntriesCompanion`, `AppDatabase.transaction`, `journalChangesProvider.notifier.markChanged() → void`.
- Produces: `EntryRepository.previewImport(String jsonStr) → Future<ImportPreview>`; `EntryRepository.applyImport(ImportPreview preview, {ConflictPolicy policy = ConflictPolicy.preserve}) → Future<ImportResult>`.
- Produces: `SettingsController.previewImport(String jsonStr) → Future<ImportPreview>`; `SettingsController.applyImport(ImportPreview preview, {ConflictPolicy policy = ConflictPolicy.preserve}) → Future<ImportResult>`.
- Produces: `DataSection({Key? key, Future<Uint8List?> Function()? pickImportBytes})` as ConsumerStatefulWidget. Optional callback은 위젯 시험에만 쓰며 production은 기존 FilePicker.pickFiles 설정을 사용한다.
- Produces: `ImportPreviewDialog({Key? key, required ImportPreview preview, required Future<ImportResult> Function(ConflictPolicy) onApply})` as StatefulWidget. 성공 시 `Navigator.pop<ImportResult>(context, result)`, 취소 시 null. repository와 controller는 UI context에 의존하지 않는다.

- [ ] **Step 1: 새 repository 시험의 setUp과 원자성 반례를 작성한다.** 각 test는 in-memory DB, MutableImportClock, clock 주입 repo를 사용하고 tearDown에서 db.close를 호출한다. 일반 saveEntry가 timestamp를 바꾸지 않게 fixture 저장에 preserveTimestamps를 명시한다.

```dart
late AppDatabase db;
late EntryRepository repo;
late MutableImportClock clock;
setUp(() {
  db = AppDatabase.forTesting(NativeDatabase.memory());
  clock = MutableImportClock(DateTime(2026, 9, 30, 12));
  repo = EntryRepository(db, clock: clock);
});
tearDown(() => db.close());
test('두 번째 실제 INSERT 실패는 첫 INSERT도 rollback한다', () async {
  await repo.getTotalCount(); // 테이블 초기화
  await db.customStatement('''
    CREATE TRIGGER fail_second_import BEFORE INSERT ON entries
    WHEN NEW.date = '2026-09-29'
    BEGIN SELECT RAISE(ABORT, 'injected failure'); END;
  ''');
  final preview = await repo.previewImport(jsonEncode([
    importRecord('2026-09-28'), importRecord('2026-09-29'),
  ]));
  expect(await repo.getTotalCount(), 0);
  await expectLater(repo.applyImport(preview), throwsA(isA<Exception>()));
  expect(await repo.getTotalCount(), 0);
  await db.customStatement('DROP TRIGGER fail_second_import');
  expect((await repo.applyImport(preview)).inserted, 2);
});
test('여섯 카운터는 배타적이고 합은 입력 건수다', () async {
  for (final date in ['2026-09-25', '2026-09-26']) {
    await repo.saveEntry(DailyEntry(date: date, emotion: 2, answer1: '로컬'),
        preserveTimestamps: true);
  }
  final preview = await repo.previewImport(jsonEncode([
    importRecord('2026-09-25'), importRecord('2026-09-26'),
    importRecord('2026-09-27'), importRecord('2026-09-28'),
    null, importRecord('2026-09-28'),
  ]));
  final changed = (await repo.getEntryByDate('2026-09-26'))!;
  await repo.saveEntry(changed.copyWith(updatedAt:
      changed.updatedAt.add(const Duration(seconds: 1))), preserveTimestamps: true);
  await repo.saveEntry(DailyEntry(date: '2026-09-27', emotion: 2, answer1: '새 충돌'));
  final result = await repo.applyImport(preview, policy: ConflictPolicy.replacePreviewed);
  expect((result.inserted, result.replaced, result.conflictSkipped,
      result.changedSincePreview, result.invalid, result.duplicate), (1, 1, 1, 1, 1, 1));
  expect(result.total, preview.parsed.inputCount);
});
test('시계 역행은 첫 후보만 강등하고 중복을 승격하지 않는다', () async {
  final preview = await repo.previewImport(jsonEncode([
    importRecord('2026-09-30'), importRecord('2026-09-30'),
    importRecord('2026-10-01'),
  ]));
  expect(clock.reads, 1);
  clock.value = DateTime(2026, 9, 29, 23);
  final result = await repo.applyImport(preview);
  expect(clock.reads, 2);
  expect((result.inserted, result.invalid, result.duplicate), (0, 2, 1));
  clock.value = DateTime(2026, 10, 1);
  final next = await repo.applyImport(preview);
  expect((next.inserted, next.invalid, next.duplicate), (1, 1, 1));
  expect(await repo.getEntryByDate('2026-10-01'), isNull);
});
test('기본 보존과 삭제된 preview 충돌, timestamp fallback을 구분한다', () async {
  final original = DailyEntry(date: '2026-09-29', emotion: 2, answer1: '로컬',
      photoPath: '/local/photo.jpg', createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2));
  await repo.saveEntry(original, preserveTimestamps: true);
  final preview = await repo.previewImport(jsonEncode([
    {...importRecord('2026-09-29'), 'created_at': null, 'updated_at': null,
      'photo_path': '/outside/secret.db'},
  ]));
  expect((await repo.applyImport(preview)).conflictSkipped, 1);
  expect((await repo.getEntryByDate('2026-09-29'))!.answer1, '로컬');
  final replaced = await repo.applyImport(preview, policy: ConflictPolicy.replacePreviewed);
  expect(replaced.replaced, 1);
  final row = (await repo.getEntryByDate('2026-09-29'))!;
  expect(row.createdAt, original.createdAt);
  expect(row.photoPath, original.photoPath);
  expect(row.updatedAt, clock.value);
  await repo.deleteEntry('2026-09-29');
  clock.value = DateTime(2026, 9, 30, 13);
  expect((await repo.applyImport(preview, policy: ConflictPolicy.replacePreviewed)).inserted, 1);
  final inserted = (await repo.getEntryByDate('2026-09-29'))!;
  expect((inserted.createdAt, inserted.updatedAt), (clock.value, clock.value));
  expect(inserted.photoPath, isNull);
});
```

- [ ] **Step 2: timestamp-only 수정 반례와 controller 시험을 작성한다.** 기존 saveEntry의 upsert는 createdAt을 수정하지 않으므로 아래처럼 실제 DB의 한 timestamp column만 update한다. 새 repository 시험 파일에 `package:drift/drift.dart`를 import한다. 정상 timezone timestamp 입력의 신규 createdAt/updatedAt, 교체 updatedAt 보존도 각각 확인한다. 기존 controller setUp에 clock override를 넣고 아래 시험을 추가한다.

```dart
for (final field in ['created', 'updated']) {
  test('$field timestamp만 바뀐 preview 충돌도 교체하지 않는다', () async {
    await repo.saveEntry(DailyEntry(date: '2026-09-29', emotion: 2,
      answer1: '로컬', createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 2)), preserveTimestamps: true);
    final preview = await repo.previewImport(jsonEncode([importRecord('2026-09-29')]));
    final changedTime = DateTime(2026, 9, 3);
    await (db.update(db.entries)..where((t) => t.date.equals('2026-09-29')))
      .write(EntriesCompanion(
        createdAt: field == 'created' ? Value(changedTime) : const Value.absent(),
        updatedAt: field == 'updated' ? Value(changedTime) : const Value.absent(),
      ));
    final result = await repo.applyImport(preview, policy: ConflictPolicy.replacePreviewed);
    expect((result.replaced, result.changedSincePreview), (0, 1));
    expect((await repo.getEntryByDate('2026-09-29'))!.answer1, '로컬');
    expect((await repo.applyImport(preview)).conflictSkipped, 1);
  });
}
// 아래 controller 시험은 기존 settings_controller_test.dart harness에 추가한다.
test('미리보기는 무쓰기, 같은 preview 동시 확인은 적용과 이벤트 한 번이다', () async {
  await container.read(settingsControllerProvider.future);
  final notifier = container.read(settingsControllerProvider.notifier);
  final before = container.read(journalChangesProvider);
  final preview = await notifier.previewImport(jsonEncode([importRecord('2026-09-29')]));
  expect(await entryRepo.getTotalCount(), 0);
  expect(container.read(journalChangesProvider), before);
  final results = await Future.wait([
    notifier.applyImport(preview), notifier.applyImport(preview),
  ]);
  expect(results.map((r) => r.inserted), [1, 1]);
  expect(await entryRepo.getTotalCount(), 1);
  expect(container.read(journalChangesProvider), before + 1);
  await notifier.applyImport(preview); // 성공한 동일 preview는 캐시 결과만 반환
  expect(container.read(journalChangesProvider), before + 1);
});
test('DB 실패는 이벤트 없이 재시도 가능하다', () async {
  await container.read(settingsControllerProvider.future);
  final notifier = container.read(settingsControllerProvider.notifier);
  final before = container.read(journalChangesProvider);
  await db.customStatement('''
    CREATE TRIGGER fail_import BEFORE INSERT ON entries
    BEGIN SELECT RAISE(ABORT, 'failure'); END;
  ''');
  final preview = await notifier.previewImport(jsonEncode([importRecord('2026-09-29')]));
  await expectLater(notifier.applyImport(preview), throwsA(isA<Exception>()));
  expect(await entryRepo.getTotalCount(), 0);
  expect(container.read(journalChangesProvider), before);
  await db.customStatement('DROP TRIGGER fail_import');
  expect((await notifier.applyImport(preview)).inserted, 1);
  expect(container.read(journalChangesProvider), before + 1);
});
```

- [ ] **Step 3: target FAIL을 확인한다.** `flutter test --no-pub test/data/repositories/entry_repository_import_test.dart test/features/settings/settings_controller_test.dart --reporter expanded`. 새 API가 없어 FAIL한다. DB rollback 시험은 fake 예외만으로 대체하지 않는다.
- [ ] **Step 4: repository/controller를 구현하고 기존 API 시험을 같이 옮긴다.** 아래 core를 추가한다. 옛 importEntries/importData와 imported/skipped 참조를 모두 새 계약으로 옮긴다. 손상 prompts 허용, 감정 clamp, 무확인 덮어쓰기 시험은 invalid/preserve 계약으로 바꾼다. UI 호출도 이 Task에서 함께 옮겨 commit 시점의 consumer 컴파일을 유지한다.

```dart
Future<ImportPreview> previewImport(String jsonStr) async {
  final now = _clock.now();
  final parsed = parseImportJson(jsonStr, now: now);
  final conflicts = <String, DailyEntry>{};
  for (final candidate in parsed.candidates) {
    final row = await getEntryByDate(candidate.date);
    if (row != null) conflicts[candidate.date] = row;
  }
  return ImportPreview(parsed: parsed, conflicts: conflicts);
}
Future<ImportResult> applyImport(ImportPreview preview,
    {ConflictPolicy policy = ConflictPolicy.preserve}) async {
  return _db.transaction(() async {
    final now = _clock.now();
    var inserted = 0, replaced = 0, skipped = 0, changed = 0;
    var invalid = preview.parsed.invalid;
    for (final candidate in preview.parsed.candidates) {
      if (!isImportDateValid(candidate.date, now)) { invalid++; continue; }
      final current = await getEntryByDate(candidate.date);
      if (current == null) {
        await _db.into(_db.entries).insert(
          _toCompanion(candidate.toEntry(now), preserveTimestamps: true));
        inserted++;
      } else if (policy == ConflictPolicy.preserve ||
          !preview.conflicts.containsKey(candidate.date)) {
        skipped++;
      } else if (!sameImportSnapshot(current, preview.conflicts[candidate.date]!)) {
        changed++;
      } else {
        final replacement = candidate.toEntry(now, replacing: current);
        await (_db.update(_db.entries)..where((t) => t.id.equals(current.id!)))
            .write(_toCompanion(replacement, preserveTimestamps: true));
        replaced++;
      }
    }
    return ImportResult(inserted: inserted, replaced: replaced,
      conflictSkipped: skipped, changedSincePreview: changed,
      invalid: invalid, duplicate: preview.parsed.duplicate);
  });
}
// SettingsController의 필드/메서드. preview identity는 기본 Object identity다.
final _applications = <ImportPreview, Future<ImportResult>>{};
Future<ImportPreview> previewImport(String text) =>
    ref.read(entryRepositoryProvider).previewImport(text);
Future<ImportResult> applyImport(ImportPreview preview,
    {ConflictPolicy policy = ConflictPolicy.preserve}) {
  return _applications.putIfAbsent(preview, () async {
    final retain = ref.keepAlive(); // 확인한 작업의 커밋/이벤트까지 controller 유지
    try {
      final result = await ref.read(entryRepositoryProvider)
          .applyImport(preview, policy: policy);
      if (ref.mounted && result.changedCount > 0) {
        ref.read(journalChangesProvider.notifier).markChanged();
        ref.invalidate(todayControllerProvider);
      }
      return result;
    } catch (_) {
      _applications.remove(preview);
      rethrow;
    } finally { retain.close(); }
  });
}
```

controller은 preview 생성으로 이벤트를 발행하지 않는다. 실제 변경 0건의 성공에도 이벤트 0건을 유지한다. 같은 preview의 첫 policy가 적용 계약이며 pending/success Future를 다시 반환한다. 실패 Future는 캐시에서 제거한다. controller autoDispose 수명 밖으로 캐시나 preview를 보관하지 않는다.

- [ ] **Step 5: UI 실패 시험을 작성한다.** DataSection 시험 harness는 PackageInfo mock, in-memory DB, clock/repository/settings repository overrides, MaterialApp Scaffold를 사용한다. `pickImportBytes` callback으로 real JSON bytes를 주고 controller를 실제로 사용한다. dialog 개별 시험은 실제 preview와 Completer<ImportResult>로 apply 순서를 확인한다.

```dart
testWidgets('파일 선택 재탭과 취소는 DB 쓰기를 만들지 않는다', (tester) async {
  final gate = Completer<Uint8List?>();
  var picks = 0;
  await tester.pumpWidget(ProviderScope(overrides: [
    appClockProvider.overrideWithValue(clock),
    entryRepositoryProvider.overrideWithValue(entryRepo),
    settingsRepositoryProvider.overrideWithValue(settingsRepo),
  ], child: MaterialApp(home: Scaffold(body: DataSection(
    pickImportBytes: () { picks++; return gate.future; },
  )))));
  await tester.tap(find.text('텍스트 기록 가져오기 (JSON)'));
  await tester.tap(find.text('텍스트 기록 가져오기 (JSON)'));
  expect(picks, 1);
  gate.complete(Uint8List.fromList(utf8.encode(jsonEncode([importRecord('2026-09-29')]))));
  await tester.pumpAndSettle();
  expect(find.text('가져오기 미리보기'), findsOneWidget);
  await tester.tap(find.text('취소'));
  await tester.pumpAndSettle();
  expect(await entryRepo.getTotalCount(), 0);
});
testWidgets('좁은 화면 200%에서 확인 재탭은 한 번 적용한다', (tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final preview = await repo.previewImport(jsonEncode([importRecord('2026-09-29')]));
  final gate = Completer<ImportResult>();
  var calls = 0;
  await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
    child: child!), home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => showDialog<ImportResult>(
        context: context, builder: (_) => ImportPreviewDialog(preview: preview,
          onApply: (_) { calls++; return gate.future; })), child: const Text('열기'))))));
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('가져오기'));
  await tester.tap(find.text('가져오기'));
  await tester.tap(find.text('가져오기'));
  expect(calls, 1);
  expect(tester.takeException(), isNull);
  gate.complete(const ImportResult(inserted: 1, replaced: 0, conflictSkipped: 0,
      changedSincePreview: 0, invalid: 0, duplicate: 0));
  await tester.pumpAndSettle();
});
```

Review Focus 1과 4의 반례는 아래처럼 실제 입력과 gate를 고정한다. helper는 같은 파일의 in-memory entryRepo/settingsRepo/clock fixture를 사용하며 PackageInfo mock을 setUp에서 준비한다. 테스트 설명에 적은 뒤 생략하지 않는다.

```dart
Future<ProviderContainer> mountImportSection(WidgetTester tester,
    Future<Uint8List?> Function() picker) async {
  await tester.pumpWidget(ProviderScope(overrides: [
    appClockProvider.overrideWithValue(clock),
    entryRepositoryProvider.overrideWithValue(entryRepo),
    settingsRepositoryProvider.overrideWithValue(settingsRepo),
  ], child: MaterialApp(home: Scaffold(body: DataSection(pickImportBytes: picker)))));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DataSection)));
}
for (final bytes in [Uint8List.fromList([0xff]),
    Uint8List.fromList(utf8.encode('{"secret":"RAW_MARKER"'))]) {
  testWidgets('손상 파일은 원문 없이 오류를 알리고 쓰지 않는다 $bytes', (tester) async {
    final container = await mountImportSection(tester, () async => bytes);
    final before = container.read(journalChangesProvider);
    await tester.tap(find.text('텍스트 기록 가져오기 (JSON)'));
    await tester.pumpAndSettle();
    expect(find.text('잘못된 파일 형식이에요'), findsOneWidget);
    expect(find.textContaining('RAW_MARKER'), findsNothing);
    expect(find.textContaining('FormatException'), findsNothing);
    expect(await entryRepo.getTotalCount(), 0);
    expect(container.read(journalChangesProvider), before);
  });
}
testWidgets('파일 선택 중 dispose되면 늦은 반환은 쓰지 않는다', (tester) async {
  final gate = Completer<Uint8List?>();
  final container = await mountImportSection(tester, () => gate.future);
  var events = 0;
  container.listen(journalChangesProvider, (_, _) => events++);
  await tester.tap(find.text('텍스트 기록 가져오기 (JSON)'));
  await tester.pumpWidget(const SizedBox.shrink());
  gate.complete(Uint8List.fromList(utf8.encode(jsonEncode([importRecord('2026-09-29')]))));
  await tester.pumpAndSettle();
  expect(await entryRepo.getTotalCount(), 0);
  expect(events, 0);
  expect(tester.takeException(), isNull);
});
```

같은 harness에서 preview dialog cancel 또는 route back 뒤 DB count/event도 0임을 확인한다. replace checkbox 기본 false, checkbox true인 확인 시 기존 사진/createdAt 보존과 실제 replaced 건수를 표시한다. onApply가 StateError('RAW_MARKER')로 실패하면 일반 재시도 안내, 부분 성공 문구 0개, 활성화된 재시도 버튼을 확인한 뒤 두 번째 호출 성공을 시험한다. preview 충돌 날짜가 많을 때 scroll로 마지막 날짜와 취소/확인에 접근하고 semantics 체크 상태를 확인한다. dialog가 열린 채 부모 DataSection만 제거하는 host 시험에서도 확인 callback이 새 적용을 시작하지 못해야 한다.

Run: `flutter test --no-pub test/features/settings/widgets/data_section_test.dart test/features/settings/widgets/import_preview_dialog_test.dart --reporter expanded`. 기대 결과는 새 widget/API 미구현 FAIL이다.

- [ ] **Step 6: 파일 선택 전체 guard와 scrollable dialog를 구현한다.** 기존 delete UI를 유지한다. DataSection.build는 `ref.watch(settingsControllerProvider)`로 dialog 동안 controller 수명을 유지한다. 파일 bytes null도 일반 파일 읽기 오류로 처리한다. UTF-8/envelope 오류는 FormatException.message를 출력하지 않는다. 큰 글씨를 축소하지 않는다. dialog content는 SingleChildScrollView, conflict 날짜 목록, 신규/충돌/invalid/duplicate 수, “사진 파일은 포함되지 않아요” 안내, checkbox를 담는다. actions는 좁은 화면에서 OverflowBar가 줄바꿈하도록 둔다. 다음 core를 실제 클래스 필드/메서드에 넣는다.

```dart
// DataSectionState
bool _importing = false;
Future<Uint8List?> _pickBytes() async {
  if (widget.pickImportBytes != null) return widget.pickImportBytes!();
  final result = await FilePicker.pickFiles(type: FileType.custom,
      allowedExtensions: ['json'], withData: true);
  if (result == null) return null;
  final bytes = result.files.single.bytes;
  if (bytes == null) throw const FormatException('파일 읽기 오류');
  return bytes;
}
Future<void> _importData() async {
  if (_importing) return;
  setState(() => _importing = true);
  try {
    final bytes = await _pickBytes();
    if (!mounted || bytes == null) return;
    final controller = ref.read(settingsControllerProvider.notifier);
    final preview = await controller.previewImport(utf8.decode(bytes));
    if (!mounted) return;
    final result = await showDialog<ImportResult>(context: context,
      barrierDismissible: true, builder: (_) => ImportPreviewDialog(
        preview: preview, onApply: (policy) {
          if (!mounted) throw StateError('가져오기 화면 종료');
          return controller.applyImport(preview, policy: policy);
        }));
    if (!mounted || result == null) return;
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('가져오기 결과'), scrollable: true,
      content: Text('신규 ${result.inserted}개\n교체 ${result.replaced}개\n'
        '충돌 보존 ${result.conflictSkipped}개\n변경 후 보존 ${result.changedSincePreview}개\n'
        '유효하지 않음 ${result.invalid}개\n중복 ${result.duplicate}개'
        '${result.changedSincePreview > 0 ? '\n확인 뒤 바뀐 기록은 보존했어요. 새 미리보기로 확인해 주세요' : ''}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
    ));
  } on FormatException {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('잘못된 파일 형식이에요')));
  } catch (_) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('가져오기에 실패했어요. 다시 시도해 주세요')));
  } finally { if (mounted) setState(() => _importing = false); }
}
// ImportPreviewDialogState
bool _applying = false, _completed = false, _replace = false;
String? _error;
Future<void> _apply() async {
  if (_applying || _completed) return;
  setState(() { _applying = true; _error = null; });
  try {
    final result = await widget.onApply(_replace
        ? ConflictPolicy.replacePreviewed : ConflictPolicy.preserve);
    _completed = true;
    if (mounted) Navigator.pop(context, result);
  } catch (_) {
    if (mounted) setState(() {
      _applying = false;
      _error = '가져오기에 실패했어요. 다시 시도해 주세요';
    });
  }
}
```

dialog는 PopScope(canPop: !_applying)로 적용 시작 뒤 취소를 막고 busy 때 checkbox/취소/확인을 비활성화한다. 미확인 dialog를 닫는 것은 쓰기 0이다. 작업 중 부모 dispose는 새 적용을 시작하지 못하며 이미 확인한 DB 작업을 취소했다고 가장하지 않는다. checkbox 문구는 “미리보기 충돌 기록의 텍스트를 교체해요. 기존 사진은 유지돼요”이다. changedSincePreview>0이면 결과에 “확인 뒤 바뀐 기록은 보존했어요. 새 미리보기로 확인해 주세요”를 추가한다.

- [ ] **Step 7: 좁은 target gate 후 commit한다.** `dart format lib/data/repositories/entry_repository.dart lib/features/settings/settings_controller.dart lib/features/settings/widgets/data_section.dart lib/features/settings/widgets/import_preview_dialog.dart test/data/repositories/entry_repository_test.dart test/data/repositories/entry_repository_import_test.dart test/features/settings/settings_controller_test.dart test/features/settings/widgets/data_section_test.dart test/features/settings/widgets/import_preview_dialog_test.dart`. `flutter test --no-pub test/data/repositories/entry_repository_test.dart test/data/repositories/entry_repository_import_test.dart test/features/settings/settings_controller_test.dart test/features/settings/widgets/data_section_test.dart test/features/settings/widgets/import_preview_dialog_test.dart --reporter expanded`의 PASS를 확인한다. `rg -n 'importEntries\(|importData\(' lib test`는 새 UI private `_importData` 외 옛 public 호출 0개다. 작업 소유 파일만 stage하고 `git commit -m "feat: 미리보기 확인 후 기록을 안전하게 가져오기"`.

### Task 3: 텍스트 export와 사진 미포함 안내

**Files:** 파일 책임표 Task 3. Task 2 뒤에만 실행한다. DailyEntry.toJson 및 일반 saveEntry는 바꾸지 않는다.

**Interfaces:**
- Consumes: 기존 `EntryRepository.exportAllEntries() → Future<List<Map<String, dynamic>>>`, `SettingsController.exportData() → Future<String>`, DailyEntry.toJson()의 기존 필드와 SharePlus.instance.share.
- Produces: 같은 export signatures. 반환 map에서만 photo_path=null. DataSection 내보내기 항목에 사진 미포함 설명을 항상 표시한다.

- [ ] **Step 1: 아래 경계 시험과 UI 문구 시험을 작성한다.** repository 기존 export group와 controller export group에 같은 조건을 각각 고정한다.

```dart
test('export는 경로만 null로 만들고 DB의 로컬 사진은 보존한다', () async {
  await repo.saveEntry(DailyEntry(date: '2026-09-29', emotion: 3,
    answer1: '사진 기록', photoPath: '/local/photos/photo_123.jpg'));
  final exported = await repo.exportAllEntries();
  expect(exported.single.containsKey('photo_path'), isTrue);
  expect(exported.single['photo_path'], isNull);
  expect((await repo.getEntryByDate('2026-09-29'))!.photoPath,
      '/local/photos/photo_123.jpg');
});
test('controller export envelope도 photo_path null을 반환한다', () async {
  await entryRepo.saveEntry(DailyEntry(date: '2026-09-29', emotion: 3,
    answer1: '기록', photoPath: '/local/photos/photo_123.jpg'));
  final decoded = jsonDecode(await container.read(settingsControllerProvider.notifier).exportData()) as Map;
  expect(decoded['app'], '3Lines');
  expect(decoded['version'], isA<String>());
  expect((decoded['entries'] as List).single['photo_path'], isNull);
});
// DataSection 기존 harness에서 추가한다.
expect(find.text('텍스트 기록 내보내기 (JSON)'), findsOneWidget);
expect(find.text('사진 파일은 백업에 포함되지 않아요'), findsOneWidget);
```

- [ ] **Step 2: FAIL을 확인한다.** `flutter test --no-pub test/data/repositories/entry_repository_test.dart test/features/settings/settings_controller_test.dart test/features/settings/widgets/data_section_test.dart --reporter expanded`. export 경로 null 및 사진 설명 시험의 FAIL을 기대한다.
- [ ] **Step 3: export map만 정규화하고 안내를 추가한다.** exportAllEntries의 map 표현식을 아래로 교체하고 DataSection의 내보내기 title/semantics를 텍스트 기록으로 변경한다. subtitle에 사진 설명을 표시하며 ShareParams 파일 형식과 JSON 필드 이름은 유지한다.

```dart
return allEntries.map((e) => <String, dynamic>{
  ..._fromEntry(e).toJson(), 'photo_path': null,
}).toList();
// DataSection export ListTile
title: const Text('텍스트 기록 내보내기 (JSON)'),
subtitle: const Text('사진 파일은 백업에 포함되지 않아요'),
```

- [ ] **Step 4: 같은 target gate PASS 후 commit한다.** 사진 첨부 기록 export→새 DB import round-trip 시험은 answer/questions/timestamp 보존과 photoPath=null을 확인한다. 기존 saveEntry 날짜 upsert 시험도 PASS여야 한다. 작업 파일만 stage하고 `git commit -m "fix: 텍스트 백업에서 사진 경로를 제외하고 안내 추가"`.

### Task 4: 실제 파일 소유 경계와 정규 참조 비교

**Files:** 파일 책임표 Task 4. 기존 picker 구현/생성 확장자 정책은 유지한다.

**Interfaces:**
- Consumes: 기존 File/Directory/Link, FileSystemEntity.type(String, {bool followLinks = true}), Directory.resolveSymbolicLinks(), path API, getApplicationDocumentsDirectory.
- Produces: `PhotoService({Future<Directory> Function()? documentsDirectoryProvider, ImagePicker? picker})`. picker는 기존 구체 ImagePicker를 주입할 수 있게 할 뿐 인터페이스/새 의존성으로 재설계하지 않는다.
- Produces: 기존 `deletePhoto(String path) → Future<void>`, `cleanupOrphanedPhotos(Set<String> validPaths) → Future<int>` 유지. `canonicalPhotoPath(String path) → Future<String?>`, `referencesPhoto(String path, Iterable<String> references) → Future<bool?>` 추가. true=보호 참조 있음, false=확인한 보호 참조 없음, null=판정 불명이라 보존.
- Produces: FakePhotoService.referencesPhoto override, `Map<String,String> canonicalAliases`, `bool referenceCheckFails`; fake은 일반 controller 시험만 담당하고 소유 경계 증거로 쓰지 않는다.

- [ ] **Step 1: 실제 임시 FS 시험을 작성한다.** setUp에서 `Directory.systemTemp.createTemp('3lines_photo_test_')`, 하위 documents/photos 생성, PhotoService documentsDirectoryProvider 주입, tearDown에서 그 시험이 만든 정확한 temp 디렉터리만 삭제한다. 패키지 path를 p로 import한다.

```dart
test('외부, traversal, 디렉터리, DB, 최종 링크는 지우지 않는다', () async {
  final docs = Directory(p.join(temp.path, 'documents'));
  final photos = Directory(p.join(docs.path, 'photos'));
  await photos.create(recursive: true);
  final outside = await File(p.join(temp.path, 'outside.jpg')).writeAsString('x');
  final owned = await File(p.join(photos.path, 'photo_123.jpg')).writeAsString('x');
  final database = await File(p.join(photos.path, 'app.db')).writeAsString('x');
  final arbitrary = await File(p.join(photos.path, 'notes.txt')).writeAsString('x');
  final link = await Link(p.join(photos.path, 'photo_456.jpg')).create(outside.path);
  final service = PhotoService(documentsDirectoryProvider: () async => docs);
  for (final path in [outside.path, photos.path, docs.path, database.path,
      arbitrary.path, link.path, 'photo_123.jpg',
      p.join(photos.path, '..', 'photos', 'photo_123.jpg')]) {
    await service.deletePhoto(path);
  }
  expect(await outside.exists(), isTrue);
  expect(await owned.exists(), isTrue);
  expect(await database.exists(), isTrue);
  expect(await arbitrary.exists(), isTrue);
  expect(await link.exists(), isTrue);
  await service.deletePhoto(owned.path);
  expect(await owned.exists(), isFalse);
  await expectLater(service.deletePhoto(owned.path), completes);
});
test('Documents 별칭 참조는 같은 canonical 사진을 보호한다', () async {
  final docs = Directory(p.join(temp.path, 'documents'));
  final photos = await Directory(p.join(docs.path, 'photos')).create(recursive: true);
  final owned = await File(p.join(photos.path, 'photo_123.JPG')).writeAsString('x');
  final alias = await Link(p.join(temp.path, 'docs_alias')).create(docs.path);
  final service = PhotoService(documentsDirectoryProvider: () async => Directory(alias.path));
  final aliasPath = p.join(alias.path, 'photos', 'photo_123.JPG');
  expect(await service.referencesPhoto(owned.path, [aliasPath]), isTrue);
  expect(await service.cleanupOrphanedPhotos({aliasPath}), 0);
  expect(await owned.exists(), isTrue);
  expect(await service.referencesPhoto(owned.path, [p.join(temp.path, 'unknown')]), isNull);
  expect(await service.cleanupOrphanedPhotos({p.join(temp.path, 'unknown')}), 0);
});
```

추가 test는 photos root를 외부 디렉터리 symlink로 만든 경우 외부 owned 파일과 link 보존, nested direct child가 아닌 owned basename 보존, 허용 확장자 각각 삭제 가능, `.tiff`/잘못된 숫자 basename 보존을 확인한다. root no-follow와 final no-follow를 cleanup에서도 같은 입력으로 시험한다. symlink 시험은 현재 macOS 및 native Linux에서 실제 Link를 사용하며 fake exists로 대체하지 않는다.

- [ ] **Step 2: 실패를 확인한다.** `flutter test --no-pub test/core/services/photo_service_test.dart --reporter expanded`. constructor/validator 미정의 및 외부 삭제 방지 FAIL을 기대한다.
- [ ] **Step 3: 단일 validator와 canonical 참조 판정을 구현한다.** 안전 판정 실패/예외는 null, 삭제/정리 실패는 파일 보존 쪽으로 처리한다. 앱 Documents 별칭은 realDocuments를 기준으로 허용하되 photos와 파일 링크는 따라가지 않는다.

```dart
Future<String?> canonicalPhotoPath(String path) async {
  try {
    if (!p.isAbsolute(path) || p.split(path).contains('..')) return null;
    if (!RegExp(r'^photo_\d+\.(jpg|jpeg|png|heic|heif|webp|gif|bmp|avif)$',
        caseSensitive: false).hasMatch(p.basename(path))) return null;
    final docs = await _documentsDirectoryProvider();
    final realDocs = await docs.resolveSymbolicLinks();
    final trustedRoot = p.join(realDocs, 'photos');
    final originalRoot = p.join(docs.path, 'photos');
    if (await FileSystemEntity.type(originalRoot, followLinks: false) !=
        FileSystemEntityType.directory) return null;
    if (await FileSystemEntity.type(p.dirname(path), followLinks: false) !=
        FileSystemEntityType.directory) return null;
    final parent = await Directory(p.dirname(path)).resolveSymbolicLinks();
    if (!p.equals(parent, trustedRoot)) return null;
    final type = await FileSystemEntity.type(path, followLinks: false);
    if (type != FileSystemEntityType.file && type != FileSystemEntityType.notFound) return null;
    final canonical = p.join(parent, p.basename(path));
    if (type == FileSystemEntityType.file &&
        !p.equals(await File(path).resolveSymbolicLinks(), canonical)) return null;
    return canonical;
  } catch (_) { return null; }
}
Future<bool?> referencesPhoto(String path, Iterable<String> references) async {
  final target = await canonicalPhotoPath(path);
  if (target == null) return null;
  var found = false;
  for (final reference in references) {
    final canonical = await canonicalPhotoPath(reference);
    if (canonical == null) return null;
    if (p.equals(target, canonical)) found = true;
  }
  return found;
}
Future<void> deletePhoto(String path) async {
  final canonical = await canonicalPhotoPath(path);
  if (canonical == null) return;
  try {
    if (await FileSystemEntity.type(canonical, followLinks: false) == FileSystemEntityType.file) {
      await File(canonical).delete();
    }
  } catch (_) { developer.log('Photo deletion failed', name: 'PhotoService'); }
}
```

cleanup는 신뢰 photos root가 regular directory일 때만 `list(followLinks:false)`로 순회한다. validPaths를 미리 canonical set으로 만들되 하나라도 불명이면 전체 정리를 skip한다. 후보마다 위 validator를 재사용하고 보호된 후보는 건너뛴다. 삭제 후 부재를 확인해 removed를 집계한다. File.delete를 서비스 밖에 새로 추가하지 않는다. catch에는 원본 exception/error/stack을 넘기지 않아 OS 예외의 경로 노출도 막는다.

FakePhotoService는 signature를 유지하며 referencesPhoto에서 alias mapping 적용 뒤 비교한다. referenceCheckFails이면 null이다. 기존 controller 시험의 `/photos/new.jpg` 같은 synthetic 경로는 fake에서 판정하도록 유지한다.

- [ ] **Step 4: 같은 target gate PASS 후 commit한다.** `git add lib/core/services/photo_service.dart test/core/services/photo_service_test.dart test/helpers/fake_photo_service.dart` 뒤 `git commit -m "fix: 앱 소유 사진만 삭제하고 경로 별칭을 보호"`.

### Task 5: 시작 정리 보호와 picker 복사 예약

**Files:** 파일 책임표 Task 5. Task 4 뒤에 실행한다. 기존 ImagePicker.pickImage의 source/maxWidth=1024/imageQuality=85를 유지한다.

**Interfaces:**
- Consumes: Task 4 PhotoService와 existing pickFromGallery()/pickFromCamera() → Future<String?>, 기존 `EntryRepository.getAllPhotoPaths() → Future<List<String>>`.
- Produces: `PhotoService.beginStartupCleanupProtection() → void`, `endStartupCleanupProtection() → void`. 같은 인스턴스의 bool/set으로만 보호하며 overlapping begin은 StateError다.
- Produces: constructor에 `Future<void> Function(String savedPath)? beforePhotoCopy`, `Future<void> Function()? beforeOrphanScan` 추가. 두 선택적 test gate는 실제 copy 직전과 canonical validPaths 구성 후 실제 scan 직전에만 호출한다. 새로운 파일시스템 인터페이스는 만들지 않는다.
- Produces: bootstrap의 `cleanupStartupPhotos(PhotoService photoService, Future<List<String>> Function() readPhotoPaths) → Future<void>`. 함수 호출 시 첫 await 전에 begin, finally에서 end한다. bootstrap에서 만든 photoService를 provider override한다.

- [ ] **Step 1: 실제 picker/copy/scan gated 시험을 작성한다.** 새 dev_dependency를 추가하지 않고 package:image_picker의 구체 ImagePicker를 상속한 아래 좁은 fake만 사용한다. 현재 설치된 image_picker 1.2.2의 pickImage signature를 먼저 읽고 override의 모든 optional 매개변수를 맞춘다.

```dart
class _Picker extends ImagePicker {
  _Picker(this.file);
  final XFile file;
  @override
  Future<XFile?> pickImage({required ImageSource source, double? maxWidth,
    double? maxHeight, int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true}) async => file;
}
test('스냅샷 뒤 복사와 picker 반환 후에도 cleanup 종료까지 보호한다', () async {
  final docs = await Directory(p.join(temp.path, 'documents')).create();
  final source = await File(p.join(temp.path, 'source.jpg')).writeAsString('image');
  final copyStarted = Completer<void>(), allowCopy = Completer<void>();
  final scanStarted = Completer<void>(), allowScan = Completer<void>();
  final service = PhotoService(documentsDirectoryProvider: () async => docs,
    picker: _Picker(XFile(source.path)),
    beforePhotoCopy: (_) async { copyStarted.complete(); await allowCopy.future; },
    beforeOrphanScan: () async {
      if (!scanStarted.isCompleted) scanStarted.complete();
      await allowScan.future;
    });
  service.beginStartupCleanupProtection();
  final pick = service.pickFromGallery();
  await copyStarted.future;
  final cleanup = service.cleanupOrphanedPhotos({}); // 낡은 스냅샷
  await scanStarted.future;
  allowCopy.complete();
  final saved = (await pick)!;
  expect(await File(saved).exists(), isTrue);
  allowScan.complete();
  expect(await cleanup, 0);
  expect(await File(saved).exists(), isTrue);
  service.endStartupCleanupProtection();
  expect(await service.cleanupOrphanedPhotos({}), 1); // 보호 수명 종료
});
```

gate는 한 번 사용 뒤 후속 cleanup에서 다시 complete하지 않도록 위 코드의 `if (!scanStarted.isCompleted)`로 감싼다. 복사 직전 보호 등록은 아래 변형으로 대상 파일이 존재하는 상태까지 시험한다. OS 내부 복사의 정확한 중간 시점을 제어했다는 주장은 하지 않는다. bootstrap 시험은 readPhotoPaths callback이 DB paths 스냅샷을 먼저 읽고 gate로 반환을 지연하는 동안 실제 사진을 picker로 복사해 DB에 save한 뒤 낡은 스냅샷을 반환한다. cleanup 후 파일 존재와 DB 참조를 모두 확인한다. snapshot 조회가 throw하면 scan/copy 이후 보호가 finally에서 끝나며 기존 사진은 남아야 한다.

```dart
test('복사 전에 예약한 대상 파일은 실제 copy를 기다리는 동안 보존한다', () async {
  final docs = await Directory(p.join(temp.path, 'documents')).create();
  final source = await File(p.join(temp.path, 'source.jpg')).writeAsString('완전한 원본');
  final reserved = Completer<String>(), resumeCopy = Completer<void>();
  final service = PhotoService(documentsDirectoryProvider: () async => docs,
    picker: _Picker(XFile(source.path)), beforePhotoCopy: (path) async {
      await File(path).writeAsString('부분 대상 fixture');
      reserved.complete(path);
      await resumeCopy.future;
    });
  service.beginStartupCleanupProtection();
  final pick = service.pickFromGallery();
  final path = await reserved.future;
  expect(await service.cleanupOrphanedPhotos({}), 0);
  expect(await File(path).exists(), isTrue);
  resumeCopy.complete();
  expect(await pick, path);
  expect(await File(path).readAsString(), '완전한 원본');
  service.endStartupCleanupProtection();
});
```

- [ ] **Step 2: target FAIL을 확인한다.** `flutter test --no-pub test/core/services/photo_service_test.dart test/app/photo_cleanup_bootstrap_test.dart --reporter expanded`. 새 protection/hook/helper가 없어 FAIL한다.
- [ ] **Step 3: 예약과 bootstrap 연결을 구현한다.** root가 없을 때만 photos를 생성하고, 생성 뒤 no-follow root 검사를 한다. root symlink면 copy도 하지 않고 null을 반환한다. Documents realpath와 photos 직접 child인 savedPath를 복사 전에 예약한다.

```dart
bool _startupCleanupActive = false;
final _startupProtected = <String>{};
void beginStartupCleanupProtection() {
  if (_startupCleanupActive) throw StateError('사진 정리 중복 시작');
  _startupCleanupActive = true;
}
void endStartupCleanupProtection() {
  _startupCleanupActive = false;
  _startupProtected.clear();
}
// _pickAndSave에서 savedPath를 정한 직후, File.copy보다 먼저 실행한다.
if (_startupCleanupActive) _startupProtected.add(savedPath);
await _beforePhotoCopy?.call(savedPath);
await File(picked.path).copy(savedPath);
return savedPath; // picker finally에서 보호 예약을 제거하지 않는다.
// cleanup에서 validPaths canonical화를 마친 뒤 gate를 기다린다.
await _beforeOrphanScan?.call();
// 순회 중 매 후보마다 live 보호 집합을 읽는다. 시작 시 set 복제는 금지한다.
if (canonicalValidPaths.contains(canonical) || _startupProtected.contains(canonical)) continue;

Future<void> cleanupStartupPhotos(PhotoService photoService,
    Future<List<String>> Function() readPhotoPaths) async {
  photoService.beginStartupCleanupProtection();
  try {
    final validPaths = (await readPhotoPaths()).toSet();
    await photoService.cleanupOrphanedPhotos(validPaths);
  } catch (_) {
    developer.log('Startup photo cleanup skipped', name: appLogName);
  } finally { photoService.endStartupCleanupProtection(); }
}
// bootstrapAndRun: runApp 전 준비, 별도 PhotoService() cleanup 호출은 제거한다.
final photoService = PhotoService();
unawaited(cleanupStartupPhotos(photoService, EntryRepository(db).getAllPhotoPaths));
// 기존 ProviderScope.overrides에 추가한다.
photoServiceProvider.overrideWithValue(photoService),
```

_startupProtected에 저장하는 savedPath도 real Documents 기준 canonical 경로여야 한다. 예약이 실패한 copy에도 남아 있어도 cleanup finally에서 해제한다. “시작 정리 한 번 동안 새 복사만 보호한다. 다중 프로세스 정리가 필요하면 별도 동기화가 필요하다”라는 한 줄 상한 주석을 붙인다. cleanup 오류에도 finally를 건너뛰지 않는다. `_pickAndSave`의 기존 catch도 일반 로그만 남기도록 바꾸고, OS 예외의 경로를 노출하는 error/stack 인자는 제거한다.

- [ ] **Step 4: shared instance와 실제 stale snapshot gate를 통과시키고 commit한다.** bootstrap 시험은 ProviderContainer(overrides:[photoServiceProvider.overrideWithValue(service)])에서 `identical(container.read(photoServiceProvider), service)`도 확인한다. 같은 target 명령 PASS 후 작업 파일만 stage하고 `git commit -m "fix: 시작 사진 정리 중 새 복사 파일을 보호"`.

### Task 6: 커밋 뒤 현재 참조와 보존 draft 보호

**Files:** 파일 책임표 Task 6. Task 2/4 뒤, Task 3과 겹치는 시험 편집이 끝난 뒤 실행한다. repository saveEntry/DB 구조를 바꾸지 않는다.

**Interfaces:**
- Consumes: 기존 getAllPhotoPaths(), PhotoService.referencesPhoto(String, Iterable<String>) → Future<bool?>와 deletePhoto(String) → Future<void>, TodayState.photoPath/existingEntry, current Provider state와 journalChangesProvider.
- Produces: 각 controller 내부 `_deleteUnreferencedPhoto(String path, {Iterable<String> retainedPaths = const []}) → Future<void>` private helper. repository에서 현재 참조를 조회하고 서비스 canonical 비교를 요청한 뒤 확실한 false일 때만 delete한다. 범용 공용 helper/provider는 만들지 않는다.
- Produces: Timeline과 Settings 내부 `_retainedTodayDraftPaths() → Iterable<String>` private helper. `!isCompleted || isEditing`인 현재 Today 상태의 non-null photoPath만 보존한다. 완료된 기록을 보기만 하는 화면은 초안이 아니며, DB에서 마지막 참조를 삭제한 사진의 영구 보존 이유가 되지 않는다.

- [ ] **Step 1: 공유 참조, retained draft, 실패 보존 시험을 추가한다.** 기존 세 controller harness와 FakePhotoService를 사용한다. fake의 canonicalAliases로 별칭을 같은 값에 대응시키고 referenceCheckFails로 판정 실패를 고정한다. 실제 canonical 보장은 Task 4 실파일 시험을 사용한다.

```dart
// Timeline 기존 test harness
test('다른 기록이 같은 사진 별칭을 참조하면 보존하고 마지막 참조만 삭제한다', () async {
  fakePhoto.canonicalAliases['/alias/photo.jpg'] = '/real/photo.jpg';
  fakePhoto.canonicalAliases['/real/photo.jpg'] = '/real/photo.jpg';
  await entryRepo.saveEntry(makeEntry('2026-09-28', photoPath: '/real/photo.jpg'));
  await entryRepo.saveEntry(makeEntry('2026-09-29', photoPath: '/alias/photo.jpg'));
  await container.read(timelineControllerProvider.future);
  final notifier = container.read(timelineControllerProvider.notifier);
  await notifier.deleteEntry('2026-09-28');
  expect(fakePhoto.deletedPaths, isEmpty);
  await notifier.deleteEntry('2026-09-29');
  expect(fakePhoto.deletedPaths, ['/alias/photo.jpg']);
});
// Today 기존 test harness
test('같은 draft를 재첨부하거나 별칭을 선택하면 현재 draft를 지우지 않는다', () async {
  await container.read(todayControllerProvider.future);
  final notifier = container.read(todayControllerProvider.notifier);
  fakePhoto.canonicalAliases['/draft/a.jpg'] = '/real/a.jpg';
  fakePhoto.canonicalAliases['/draft/alias.jpg'] = '/real/a.jpg';
  await notifier.attachPhoto('/draft/a.jpg');
  await notifier.attachPhoto('/draft/a.jpg');
  await notifier.attachPhoto('/draft/alias.jpg');
  expect(fakePhoto.deletedPaths, isEmpty);
});
// Settings 기존 test harness
test('전체 삭제 뒤 남아 있는 미저장 Today draft는 보호한다', () async {
  await entryRepo.saveEntry(DailyEntry(date: du.getTodayString(), emotion: 3,
      answer1: '기록', photoPath: '/shared.jpg'));
  await container.read(todayControllerProvider.future);
  final today = container.read(todayControllerProvider.notifier);
  today.toggleEdit();
  await today.attachPhoto('/shared.jpg');
  await container.read(settingsControllerProvider.future);
  expect(await container.read(settingsControllerProvider.notifier).deleteAllData(), isTrue);
  expect(await entryRepo.getTotalCount(), 0);
  expect(fakePhoto.deletedPaths, isEmpty);
});
```

Review Focus 3의 조회 실패는 아래 작은 test subclass로 고정한다. 해당 controller test setUp에서 `EntryRepository(db)` 대신 `_PhotoReferenceRepository(db)`를 기존 override에 넣는다. DB는 실제 in-memory이고 사진 참조 조회만 지정 시점에 실패한다. Settings의 삭제 전 대상 경로 조회는 성공시킨 뒤 커밋 이후 조회를 실패시켜야 한다.

```dart
class _PhotoReferenceRepository extends EntryRepository {
  _PhotoReferenceRepository(AppDatabase db) : super(db);
  int? failAfter;
  int reads = 0;
  @override
  Future<List<String>> getAllPhotoPaths() async {
    if (failAfter != null && reads++ >= failAfter!) {
      throw StateError('reference read failed');
    }
    return super.getAllPhotoPaths();
  }
}
// Timeline harness
test('커밋 뒤 사진 참조 조회가 실패해도 기록 삭제 성공은 유지한다', () async {
  await entryRepo.saveEntry(makeEntry('2026-09-29', photoPath: '/photo.jpg'));
  await container.read(timelineControllerProvider.future);
  (entryRepo as _PhotoReferenceRepository).failAfter = 0;
  final before = container.read(journalChangesProvider);
  await container.read(timelineControllerProvider.notifier).deleteEntry('2026-09-29');
  expect(await entryRepo.getEntryByDate('2026-09-29'), isNull);
  expect(fakePhoto.deletedPaths, isEmpty);
  expect(container.read(journalChangesProvider), before + 1);
});
// Settings harness
test('전체 삭제의 커밋 이후 참조 조회 실패는 파일만 보존한다', () async {
  await entryRepo.saveEntry(DailyEntry(date: '2026-09-29', emotion: 3,
    answer1: '기록', photoPath: '/photo.jpg'));
  await container.read(settingsControllerProvider.future);
  (entryRepo as _PhotoReferenceRepository).failAfter = 1;
  expect(await container.read(settingsControllerProvider.notifier).deleteAllData(), isTrue);
  expect(await entryRepo.getTotalCount(), 0);
  expect(fakePhoto.deletedPaths, isEmpty);
});
// Timeline harness
test('완료된 Today 표시만 있으면 마지막 사진 참조를 정상 삭제한다', () async {
  final date = du.getTodayString();
  await entryRepo.saveEntry(makeEntry(date, photoPath: '/photo.jpg'));
  final today = await container.read(todayControllerProvider.future);
  expect(today.isCompleted && !today.isEditing, isTrue);
  await container.read(timelineControllerProvider.future);
  await container.read(timelineControllerProvider.notifier).deleteEntry(date);
  expect(fakePhoto.deletedPaths, ['/photo.jpg']);
});
```

Today 저장 후 정리에도 조회 실패/판정 null을 적용해 delete 호출 0, DB 저장 성공, 이벤트 한 번을 확인한다. commit 실패 시험은 실제 db.close 또는 SQLite trigger로 고정하고 사진 삭제 0을 확인한다. 기존 deleteError 시험은 DB 성공이 파일 실패 때문에 false/throw로 바뀌지 않는지 유지한다.

- [ ] **Step 2: FAIL을 확인한다.** `flutter test --no-pub test/features/today/today_controller_test.dart test/features/timeline/timeline_controller_test.dart test/features/settings/settings_controller_test.dart --reporter expanded`. 공유/draft 사진을 기존 코드가 지우는 FAIL을 기대한다.
- [ ] **Step 3: 각 controller에 좁은 helper와 정확한 retained paths를 넣는다.** helper는 모든 실패를 보존으로 처리하고 raw exception/stack/path를 로그에 넣지 않는다. DB mutation try/catch 밖의 후속 정리이므로 commit 성공을 실패로 바꾸지 않는다.

```dart
Future<void> _deleteUnreferencedPhoto(String path,
    {Iterable<String> retainedPaths = const []}) async {
  try {
    final references = await ref.read(entryRepositoryProvider).getAllPhotoPaths();
    final service = ref.read(photoServiceProvider);
    if (await service.referencesPhoto(path, [...references, ...retainedPaths]) == false) {
      await service.deletePhoto(path);
    }
  } catch (_) {
    developer.log('Photo cleanup skipped');
  }
}
// Timeline/Settings 각각의 작은 private helper. TodayController import를 추가한다.
Iterable<String> _retainedTodayDraftPaths() {
  final today = ref.read(todayControllerProvider).value;
  if (today == null || (today.isCompleted && !today.isEditing)) return const [];
  final photo = today.photoPath;
  return photo == null ? const [] : [photo];
}
```

Today의 save는 DB 성공 뒤 oldPhotoPath를 helper에 넘기고 현재 보존 photoPath를 보호한다. cancelEdit는 saved.photoPath를 retainedPaths로 넘기며 draft 정리 후 저장된 텍스트/사진을 복원한다. attachPhoto는 새 path를 state에 넣은 뒤 previousPath 정리에 새 path를 보호한다. removePhoto는 state를 null로 바꾼 뒤 saved.photoPath를 보호한다. 늦게 picker가 반환한 `_discardUnattachedPhoto`는 현재 state.photoPath와 existingEntry.photoPath 모두 보호한다. 모든 경우 현재 DB 참조를 다시 읽는다.

Timeline.deleteEntry는 `await repo.deleteEntry(date)` 성공 뒤 helper에 `_retainedTodayDraftPaths()`를 넘긴다. Settings.deleteAllData는 대상 path를 삭제 전에 확보하되 deleteAllEntries 성공 뒤 현재 DB 참조를 다시 읽는다. 후보별 canonical 판정에 그 참조와 `_retainedTodayDraftPaths()`를 넣는다. 조회 실패 시 전체 파일 정리를 skip한다. 후보마다 helper가 읽는 구현을 선택하면 같은 안전성을 유지하되 불필요한 중복 쿼리는 추가하지 않는다. 어디에도 빈 집합을 조회 실패의 대체값으로 쓰지 않는다. 이미 완료된 Today 표시 상태를 초안으로 잘못 보호하지 않는 삭제 회귀 테스트도 유지한다. 사진 파일 보호와 별개로 기존 Today invalidate에 따른 텍스트 초안 보존은 두 번째 개선 작업 범위이며, 여기서 해결됐다고 보고하지 않는다.

- [ ] **Step 4: same target gate PASS 뒤 commit한다.** 기존 일반 작성/취소/사진교체/삭제 이벤트 시험을 포함한 세 파일 PASS 후 작업 파일만 stage하고 `git commit -m "fix: 사진 정리 전에 현재 기록과 초안 참조를 보호"`.

## 최종 리뷰와 전체 gate

- [x] 메인이 모든 작업 commit과 새 리뷰어의 승인/반례를 원장에서 대조한다. 명세 전체 수락 조건에 해당 시험이 있는지 확인하고 DB schema/saveEntry 변경, unsafe import public 호출, raw 오류 표시, 서비스 밖 File.delete가 생기지 않았는지 diff를 읽는다.
- [x] 메인이 `flutter analyze --no-pub`를 전체 branch에 한 번 실행한다. 기대 결과는 오류 0이다. 실패하면 baseline의 stale package_config 때문이라고 추정하지 말고 새 로그의 실제 원인을 보고한다.
- [x] 메인이 `flutter test --no-pub --reporter expanded`를 전체 branch에 한 번 실행한다. 기대 결과는 전체 PASS이며 기존 `+346/-11`을 성공 근거로 쓰지 않는다. gate 실패의 수정이 필요하면 명시적 보수 task를 배정하고 그 target 시험만 실행한 뒤 실패한 전체 gate의 재실행 이유를 원장에 기록한다.
- [x] 전체 gate 결과와 좁은 테스트 결과, 사진 실파일/race 검증 여부를 사용자에게 보고한다. 사용자 검토 없이 계획 단계에서 구현을 시작하거나 완료를 주장하지 않는다.

## 재개 원장

| 작업 | 상태 | owner | commit | gate/리뷰 근거 | blocker |
| --- | --- | --- | --- | --- | --- |
| 1 | 구현/독립 검토 승인 | implement_import_contract | 3f42dc2, d7dd13b, 17f7f80 | 최종 target +7 exit0, constructor/clock 보완 후 Approved | 없음 |
| 2 | 구현/독립 검토 승인 | implement_import_flow | 23165da | target +122 exit0, Approved | 없음 |
| 3 | 구현/독립 검토 승인 | implement_text_export | 4d751f9, 6e0701e | target +113 및 round-trip focused +1 exit0, Approved | 없음 |
| 4 | 구현/독립 검토 승인 | implement_photo_boundary | 3c46736 | 실제 FS target +28 exit0, Approved | 없음 |
| 5 | 구현/독립 검토 승인 | implement_startup_photo_protection | 8a431df, 8a336be | 실제 FS/race target +38, 형식 보완 뒤 +41 exit0, Approved | 없음 |
| 6 | 구현/독립 검토 승인 | implement_photo_reference_callers | 7be04a0 | bulk 최신 참조 보완 뒤 target +111 exit0, Approved | 없음 |
| 최종 fix wave | 독립 재검토 Ready Yes | review_data_safety_final, workers/root | 8a336be, b077e6f | copy/삭제 경계 분리, 삭제 안내/controller 수명 정정, UI target +10/취소 focused +1 exit0 | 없음 |
| root 전체 gate | 완료 | root | 48d647c | lint 보수 교차검토 Ready Yes, analyze No issues/exit0, 전체 test +532/exit0, diff check exit0 | 플랫폼/실기기/배포 미검증은 후속 범위 |

위 단계별 시험은 전체 앱/배포 완료를 뜻하지 않는다. 최신 실행과 미검증 범위는
`docs/superpowers/sdd/2026-09-30-data-safety-import/progress.md`에 기록한다.
