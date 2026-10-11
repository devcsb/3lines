# 3Lines 기록 신뢰성과 UX 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. 각 실행자는 지정 task만 구현하고 root가 교차검토와 통합을 조율한다.

**Goal:** 짧은 기록의 작성/복구/탐색/해석/재방문 흐름을 신뢰할 수 있게 개선한다.
**Architecture:** 기존 Flutter/Riverpod/SQLite 구조를 유지한다. 조회 선택을 재조회 수명과 분리하고 영속 초안은 기존 settings 테이블에 저장한다. 사진 보호, 단일 snapshot 계산과 기존 오프라인 저장 계약을 함께 검증한다.
**Tech Stack:** Flutter 3.47.1, Dart 3.13.1, Riverpod 3, Drift/SQLite. 새 패키지는 필요한 실제 근거 없이는 추가하지 않는다.
**Spec:** `docs/superpowers/specs/2026-10-11-product-trust-and-ux-design.md`

## 공통 제약과 검토 초점

- 구현 medium/독립 검토 xhigh를 사용한다. 다른 작업자의 편집을 되돌리지 않는다. root만 명시 파일을 stage/commit한다. 실행자는 재위임하지 않는다.
- 사용자 자료/secret/외부 배포를 건드리지 않는다. SDK 하한, DB의 일반 saveEntry/JSON 데이터 보존 계약을 근거 없이 바꾸지 않는다.
- R1~R6의 각 항목이 수락 조건이다. 최신 응답, 실제 데이터 보존, 취소와 실패 회복이 겉보기 성공보다 우선한다.
- 작업별 실패 반례/타깃 테스트를 남긴다. 이미 실행한 게이트를 리뷰어가 다시 돌리지 않는다. 전체 analyze/test는 root가 변경 전체에 실행한다.
- 사진 참조 조회 실패와 영속 초안 해석 실패는 보존한다. 보관 성공 전에 사용자에게 '보관됨'을 표시하지 않는다.
- Review Focus는 자정 중 저장, 전체 삭제와 대기 초안 쓰기 경합, 검색 clear와 늦은 응답, 작은 표본/빈 기간, 큰 글씨/키보드 상태다. 각 소유 task에서 실제 순서를 고정한다.

## Task 1 과거 기록 탐색과 조회 의도 보존

**Files:** `lib/features/timeline/{timeline_controller,timeline_state,timeline_screen}.dart`, `lib/features/timeline/widgets/{entry_detail_sheet,heatmap_grid}.dart`, 해당 `test/features/timeline/` tests. EntryRepository는 소비만 하며 수정하지 않는다. Heatmap의 optional `endDate`로 조회와 렌더의 고정 시계를 일치시킨다.
**Interfaces:** 기존 `search(String)`, `clearSearch()`, `setPeriod(TimelinePeriod)`, `deleteEntry(String)`, `getEntryByDate(String)` 호출 호환을 유지한다. TimelineState에 실제 전체 건수/조회 상태가 필요하면 기본값을 갖는 좁은 필드만 추가한다. `getTotalCount`, `searchEntries`, `getEmotionMap`을 재사용한다.

- [ ] 실제 메모리 DB에 2026-03-01 한 건/clock2026-10-11을 넣어 검색→상세에 도달하는 RED를 고정한다. 전체0건과 기간0건 문구를 구분한다.
- [ ] 지연된 `search('여행')`→clear→완료, A검색→B검색→B완료→A완료, 기간 변경과 검색/markChanged/refresh 교차의 RED를 고정한다. debounce 지우기도 실제 widget에서 검증한다.
- [ ] `DateTime(now.year, now.month, now.day - period.days + 1)` 기준으로 N개 달력 날짜를 조회하고 startDateFrom도 일치시킨다. 선택 상태/요청 세대를 유지해 stale 응답을 버린다.
- [ ] 검색/기간 UI를 유지하고 표본 없는 상태와 최신 검색 loading/error/retry를 정직하게 표시한다. 인접 기록이 없거나 조회 실패하면 상세 현재 페이지를 유지한다. 유효한 방향만 이동한다.
- [ ] 실제 단일/첫/마지막 기록과 인접 조회 지연/실패, 스와이프와 버튼, 200% 좁은 화면을 시험한다. 사진 삭제/참조 보호와 실제 삭제 날짜 계약을 유지한다.
- [ ] 타깃 `flutter test --no-pub test/features/timeline --reporter expanded`, 변경 파일 format과 diff check 결과를 보고한다. root가 독립 검토 후 commit한다.

## Task 2 날짜 집계와 통계/PDF 정합성

**Files:** `lib/data/repositories/entry_repository.dart`의 조회/통계 부분, `lib/features/insights/`, `lib/core/services/pdf_report_service.dart`가 필요한 경우, 해당 repository/insights/pdf tests. Timeline과 Today 파일은 수정하지 않는다.
**Interfaces:** `getCurrentStreakWithGrace()`와 `getLongestStreak()` 반환형을 유지한다. 기존 `getAverageEmotionOrNull()`을 소비한다. 기존 PDF generateMonthlyReport 인자를 바꿀 필요가 있으면 모든 해당 호출/시험을 같은 task에서 갱신한다. 일반 saveEntry/import/사진 API는 유지한다.

- [ ] 정확한 7/30/90일과 두 비교 주, weekly retrospective 경계 전날/첫날/오늘을 고정 시계로 시험한다. 10-04=5,10-05~11=1의 1주 평균은1이어야 한다.
- [ ] 03-01,03-03,03-04,03-06,03-07의 longest=4, 단순 연속3일의 usedGraceDay=false와 실제 공백1개의 true를 시험한다. 숨은 400일/3년 제한을 제거하고 전체 날짜 O(n) 계산을 구현한다.
- [ ] `longest >= current`와 윤년/월경계/오늘 미작성/어제미작성/두 공백을 검증한다. 잘못된 옛 기대값을 새 제품 계약으로 고친다.
- [ ] 기간 선택은 journal 변경/refresh/응답 역전에 유지한다. 기간0건은 평균을 null/기록없음으로 표현하고 기록 수/범위를 함께 보여준다. 표본 없는 비교는 표시하지 않는다. 소표본의 과장된 추세/최고 요일 카피를 좁힌다.
- [ ] 월별 entry 목록 한 번에서 평균과 키워드를 계산해 PDF 호출에 넘긴다. 화면 summary가 오래됐어도 새 본문과 같은 snapshot이어야 하며 clock도 주입한다. PDF 인자를 캡처하는 실제 호출자 시험을 추가한다.
- [ ] 타깃 repository, insights, PDF tests와 format/diff check를 실행하고 보고한다. root가 독립 검토 후 commit한다. Task3은 이 저장소 편집 완료 후 시작한다.

## Task 3 날짜별 영속 초안과 저장 연속성

**Files:** 새 `lib/data/models/journal_draft.dart`, 새 `lib/data/repositories/draft_repository.dart` 또는 동등한 좁은 모델/저장소, Today controller/state/screen, Settings controller, app bootstrap, 사진 참조 소비자와 관련 tests. EntryRepository와 Timeline은 Task1/2 완료 후 배타적으로 인계한다.
**Interfaces:** 날짜별 settings row를 사용한다. payload는 작성 날짜, 질문/답변/감정/사진, baseline snapshot과 revision을 보존한다. 기존 JSON export/import는 완료 기록만 다룬다. 상세 API는 구현 전 task brief에 정확히 고정한다.

- [ ] 앱 재생성/질문 변경/import/다른 날짜 삭제/자정 후 초안 복구와 날짜 고정 실패를 실제 메모리 DB/provider 수명으로 시험한다.
- [ ] 날짜별 load/store/discard와 저장 성공의 해당 revision 제거를 구현한다. DB commit+draft 제거를 원자적으로 처리한다. baseline 변경 충돌은 초안 유지와 명시적 회복 UI로 연결한다.
- [ ] 대기 쓰기→전체삭제→대기쓰기완료, copy/초안보관→startup cleanup, 복수 날짜 draft 사진 공유를 결정적으로 시험한다. 사진 참조 집합에 모든 영속 draft를 포함한다.
- [ ] 어제 초안/오늘 작성 전환, 보관 중/보관실패/다시 시도와 저장 중 UI를 구현한다. 질문 변경은 다음 새 초안에만 적용한다.
- [ ] 관련 Today/Settings/Timeline/bootstrap/실제 File target 뒤 독립 검토한다.

## Task 4 작성 도움과 오류 복구

**Files:** Today screen와 prompt widgets, Settings questions_section/controller, PhotoService/호출부, LockScreen 및 관련 tests. Task3과 source가 겹치므로 그 이후 수행한다.

Task4a는 QuestionsSection/LockScreen과 해당 시험만 먼저 진행한다. Task4b의 Today/Prompt/PhotoService/SettingsController는 Task3 독립 검토 지적이 닫힌 뒤 인계한다. Flutter 실행 슬롯은 두 task 사이에서도 공유하지 않는다.

- [ ] 예시→직접편집→Undo, 199 grapheme→예시, 가져온 장문→편집의 반례를 고정한다. 현재 결과가 삽입 결과와 같을 때만 Undo하고 새 예시/저장/날짜전환에서 무효화한다.
- [ ] 검증된 질문별 예시와 자유질문 라벨/예시 숨김을 적용한다. focusable native button/명확한 접근성 이름을 사용한다.
- [ ] 질문 편집 공백/DB 실패/느린 저장/취소를 구현하고 입력을 유지한다. 사진 cancel/error 구분과 인증 재시도 안내를 추가한다.
- [ ] 실제 입력/키보드/200% widget 및 관련 controller/service tests를 수행한다.

## Task 5 하루 한 번 알림과 기대 일치

**Files:** `lib/core/services/{notification_service,reminder_coordinator}.dart`, `lib/features/settings/widgets/notifications_section.dart`, 관련 reminder/notification tests와 test fakes. SettingsRepository/Today는 수정하지 않는다.

- [ ] 매일 토글이 일일+위험+회고를 만드는 기존 예약 반례를 고정한다. 사용자 설정 시각 하루1회만 남기고 기존 위험/회고 ID 예약을 launch/reconcile에서 취소한다.
- [ ] 기록한 날은 건너뛰고 다음 날짜의 일일 예약을 유지한다. 기존 권한 거부/저장 실패 보상/직렬화/시간대 정책을 유지한다.
- [ ] 문구를 '오늘 마음을 짧게 남겨볼까요?'로 좁히고 설정에 하루한번/기록한날건너뜀을 설명한다. 별도 알림 opt-in UI는 추가하지 않는다.
- [ ] 관련 reminder/notification/platform tests와 실제 예약 인자/개수를 확인한다. 실기기 도착은 host 시험과 구분한다.

## Task 6 가독성, 첫 사용과 보관 카피

**Files:** theme/color tokens, onboarding, info/security/data copy, daily_quote, 관련 settings/onboarding/theme/widget tests. Today/Timeline/Insights 하위 UI는 Task1~4의 source 안정 후 적용한다.

공통 theme/onboarding/보관 카피는 Task6a로 먼저 병렬 진행한다. Task3/4가 소유한 controller와 prompt/emotion/Today/Timeline/Insights 화면은 건드리지 않고, 해당 하위 화면의 대비/48dp/렌더는 Task6b로 인계 후 마무리한다.

- [ ] 온보딩 각 페이지를 320×640/640×320/200%/reduce-motion에서 끝까지 조작하고 overflow 반례를 고친다. 페이지 텍스트 안내를 추가한다.
- [ ] 정보 텍스트 onSurfaceVariant/의미 아이콘의 전경색을 보장하고 라이트/다크/액센트별 합성 대비를 검증한다. 알파만 낮춰 읽어야 하는 안내를 흐리게 만들지 않는다.
- [ ] R5의 보관 안내와 검증되지 않은 효과 대신 실제 기록 계약의 카피를 적용한다. 실제 Flutter 렌더를 저장해 작은 화면/큰 글씨/테마를 눈으로 확인한다.

## Task 7 제품 식별과 Android 베타 진입

**Files:** 플랫폼 launcher assets/manifest, 재생성 가능한 icon source/tool, `.github/workflows/release.yml`, `tool/release/`, README/RELEASE 및 beta 관찰 문서.

- [ ] Sage/세 줄의 단순 아이콘을 설계하고 모든 배포 플랫폼 launcher 크기와 Android adaptive mask에 맞게 생성한다. Android label은3Lines로 일치시킨다.
- [ ] 현재 GitHub Release 첨부를 읽기 전용으로 확인한다. APK 빌드/서명 검증/업로드를 workflow에 포함하고 기존 AAB/version/signing gate는 유지한다. 계정/secret/publish는 변경하지 않는다.
- [ ] 첫 기록/재방문/초안 복구/텍스트 복원을 관찰하는 소규모 베타 시나리오와 분모/성공 정의를 문서화한다. 주장과 실제 설치 방법을 맞추고 새 tracking은 넣지 않는다.
- [ ] 가능한 Android 컴파일, release script tests, 실제 생성 icon 시각 검토를 수행한다. 외부 publish나 실기기 미실행은 분리한다.

## 통합과 완료

- [ ] 각 task의 반례, target 결과, 독립 xhigh 검토를 대조한다.
- [ ] 앱 렌더와 핵심 통합 흐름, 전체 analyze/test, 가능한 Android build를 root가 수행한다.
- [ ] R1~R6 completion matrix에 직접 근거를 연결한다. 빠진 요구는 목표 완료로 표시하지 않는다.
- [ ] 로컬 commit/worktree, 남은 외부 작업과 실제 기기 확인 범위를 보고한다. goal 완료 판정은 전체 요구를 확인한 후에만 한다.
