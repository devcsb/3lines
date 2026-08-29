# UI/UX Accessibility Competitive Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 경쟁 앱과 플랫폼 접근성 기준에 비춰 확인된 텍스트 배율, 히트맵 조작, 새로고침 피드백, 위젯 날짜, 내보내기 메타데이터 결함을 회귀 테스트와 함께 수정한다.

**Architecture:** 기존 Riverpod 화면·서비스 경계를 유지한다. UI는 시스템 `TextScaler`와 충분한 상호작용 컨테이너를 사용하고, 새로고침은 provider Future를 기다린다. iOS 위젯 날짜 정규화는 Swift 순수 함수로 분리하며, 내보내기는 `PackageInfo`를 기존 Settings Controller에 주입 없이 읽어 실패 시 안전한 문자열로 대체한다.

**Tech Stack:** Flutter/Dart 3.9+, Riverpod 3, Flutter accessibility guideline API, SwiftUI/WidgetKit, `package_info_plus`.

**Spec:** `docs/superpowers/specs/2026-08-26-ux-accessibility-competitive-audit-design.md`

## Global Constraints

- 사용자 문구와 작업 보고는 한국어로 유지한다.
- Drift 스키마, JSON entries 구조, 알림/위젯 저장 키는 변경하지 않는다.
- 히트맵 시각 셀 색·크기는 유지하고 상호작용 영역만 확장한다.
- 실기기 배터리·알림 지연은 미측정으로 표시하며 자동화 결과로 과장하지 않는다.
- 각 생산 코드 변경 전에 해당 동작을 재현하는 실패 테스트를 확인한다.

## File Map

### Modify

- `lib/app.dart`: 시스템 텍스트 배율을 자르지 않고 그대로 전달.
- `lib/features/timeline/widgets/heatmap_grid.dart`: 시각 셀과 48dp 조작 영역 분리.
- `lib/features/timeline/timeline_screen.dart`: 새로고침 완료까지 await.
- `lib/features/insights/insights_screen.dart`: 새로고침 완료까지 await.
- `lib/features/settings/settings_controller.dart`: 실제 앱 버전 기반 export metadata.
- `ios/ThreeLinesWidget/ThreeLinesWidget.swift`: 저장 날짜 정규화 및 날짜별 기본 상태.
- `test/features/settings/settings_controller_test.dart`: export version 회귀 검증.
- `test/features/timeline/widgets/heatmap_grid_test.dart`: 셀 조작 크기·라벨 검증.
- `test/integration/app_flow_test.dart`: 200% 텍스트 스케일 핵심 기록 흐름.
- `test/features/timeline/timeline_screen_test.dart`: refresh Future 대기 계약.
- `test/features/insights/insights_screen_test.dart`: refresh Future 대기 계약.

> 실행 메모: 기존 integration flow harness를 확장하는 대신 `test/app/text_scaling_test.dart`가
> 실제 `ThreeLinesApp`을 200% scaler로 펌프해 핵심 렌더링 계약을 검증한다. 앱 데이터 입력
> 흐름은 기존 `test/integration/app_flow_test.dart`가 담당하므로 이번 루프에서 중복하지 않았다.

### Create

- `test/app/accessibility_guideline_test.dart`: Android/iOS 탭 타깃·라벨 가이드와 큰 글자 스모크 검사.
- `ios/ThreeLinesWidget/ThreeLinesWidgetState.swift`: iOS 저장 상태 정규화 순수 타입.
- `ios/ThreeLinesWidgetTests/ThreeLinesWidgetStateTests.swift`: 오늘/지난 날짜 정규화 단위 테스트(타깃이 존재하는 경우).

## Task 1: Text scaling and heatmap target contract

**Files:** `lib/app.dart`, `lib/features/timeline/widgets/heatmap_grid.dart`, `test/features/timeline/widgets/heatmap_grid_test.dart`, `test/app/accessibility_guideline_test.dart`

- [x] Write a test that pumps `HeatmapGrid` with a recorded date and asserts the tappable semantic node has at least 48 logical pixels in both dimensions and a non-empty label.
- [x] Run the focused test and confirm it fails because the current `tapSize` is at most 22.
- [x] Remove the `TextScaler.clamp(maxScaleFactor: 1.3)` override from `ThreeLinesApp.builder`.
- [x] Keep the visual cell size bounded at 8–20 logical pixels but make the `GestureDetector`/`Semantics` container 48×48; align the visual rectangle at the center.
- [x] Run the focused heatmap and accessibility tests; confirm they pass.
- [x] Commit `fix: preserve accessibility scaling and heatmap targets`.

## Task 2: Refresh completion feedback

**Files:** `lib/features/timeline/timeline_screen.dart`, `lib/features/insights/insights_screen.dart`, corresponding screen tests.

- [x] Add a test double provider whose Future completes only after a gate, trigger pull-to-refresh, and assert the refresh callback Future remains pending until the gate opens.
- [x] Run the focused tests and confirm the current invalidate-only callbacks complete too early.
- [x] Replace invalidate-only callbacks with `await ref.refresh(timelineControllerProvider.future)` and the equivalent Insights call; preserve haptic feedback.
- [x] Run focused screen tests and confirm the callback waits for data completion.
- [x] Commit `fix: await journal screen refresh completion`.

## Task 3: Cross-platform widget date normalization

**Files:** `ios/ThreeLinesWidget/ThreeLinesWidgetState.swift`, `ios/ThreeLinesWidget/ThreeLinesWidget.swift`, optional Swift tests.

- [x] Add a pure-state test for a stored date different from today: completion is false, emotion is nil, and the prompt/status reset to today defaults.
- [x] Run the Swift test or syntax/build check and confirm it fails before the pure resolver exists.
- [x] Implement the resolver and call it from `loadEntry`, using `Calendar.current` and `yyyy-MM-dd` local dates.
- [x] Run the available iOS target test/build; record if the host cannot build iOS targets.
- [x] Commit `fix: normalize stale iOS widget state`.

## Task 4: Export metadata correctness

**Files:** `lib/features/settings/settings_controller.dart`, `test/features/settings/settings_controller_test.dart`.

- [x] Add a test that seeds the Settings state with the package version and asserts export metadata uses that version rather than the historical literal.
- [x] Run the focused test and confirm it fails with `1.0.0` when the current package version differs.
- [x] Read `PackageInfo.fromPlatform()` for export, fall back to loaded Settings state, then `unknown` if unavailable; do not change entries or import parsing.
- [x] Run the focused Settings tests and confirm round-trip behavior remains unchanged.
- [x] Commit `fix: report actual app version in exports`.

## Task 5: Full verification and release evidence

**Files:** `docs/superpowers/sdd/2026-08-26-ux-accessibility-competitive-audit/progress.md`, `docs/superpowers/reviews/2026-08-26-ux-accessibility-competitive-audit.md`

- [x] Run `dart format` on changed Dart files and `flutter analyze`.
- [x] Run focused tests, then full `flutter test` and `flutter test --coverage`.
- [x] Run the accessibility guideline test with semantics enabled and record any platform-specific guideline caveats.
- [x] Run Android JDK 21 `app:testDebugUnitTest` and the arm64 release APK build; check release manifest permissions.
- [x] Run available iOS syntax/build/test checks; record host limitations without claiming device verification.
- [x] Write the competitive gap matrix, score changes, remaining risks, and exact command evidence to the review file and progress ledger.
- [x] Commit `docs: record ux accessibility audit evidence`.
