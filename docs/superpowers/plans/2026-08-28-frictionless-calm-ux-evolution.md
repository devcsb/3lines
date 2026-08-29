# Frictionless Calm UX Evolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 3Lines의 기록 루프를 방해하지 않으면서 모션·접근성·탭 전환·회복 흐름을 일관되게 개선한다.

**Architecture:** 상태를 소유한 `StatefulNavigationShell`은 그대로 유지하고, shell을 중복 마운트하지 않는 단일 자식 `BranchFadeThrough` 래퍼로 활성 브랜치의 opacity/짧은 이동만 재생한다. 모션 시간·곡선은 `AppMotion` 토큰으로 모으고, `MediaQuery.disableAnimationsOf`가 켜지면 controller를 최종 상태로 스냅한다. 저장 완료 오버레이는 자동 종료를 유지하되, 즉시 사용할 수 있는 명시적 닫기 버튼과 route semantics를 제공한다.

**Tech Stack:** Flutter 3.47/Dart 3.9, Material 3, go_router 17, flutter_test, Riverpod 기존 화면 상태.

**Spec:** `docs/superpowers/specs/2026-08-28-frictionless-calm-ux-evolution-design.md`

## Global Constraints

- 핵심 기록 루프는 기존 로컬 DB·알림·위젯·내보내기 계약을 변경하지 않는다.
- 모션 토큰은 `instant=0ms`, `micro=120ms`, `standard=240ms`, `entrance=360ms`, `celebration<=600ms`를 사용한다.
- `MediaQuery.disableAnimationsOf(context)`가 true이면 이동·확대·파티클·stagger delay를 제거하고 최종 상태 또는 opacity/색상만 표시한다.
- 모든 새 상호작용의 실제 hit target은 Android 48dp 이상, iOS 44pt 이상이며 색상만으로 상태를 전달하지 않는다.
- 알림·완료 문구에는 저널 원문과 임상적 효과·진단·치료를 암시하는 표현을 넣지 않는다.
- 새 기능은 네트워크, 상시 polling, 무한 animation을 추가하지 않는다.
- 각 작업은 관련 실패 테스트를 먼저 추가하고 `flutter test` 및 `dart analyze` 결과를 기록한다.

## File Map

- Create: `lib/core/theme/app_motion.dart` — 모션 duration/curve와 reduce-motion 판별 함수.
- Modify: `lib/shared/widgets/staggered_fade_in.dart` — entrance token과 bounded stagger 적용.
- Modify: `lib/features/timeline/widgets/heatmap_grid.dart` — entrance token 적용.
- Modify: `lib/features/insights/widgets/insights_locked_view.dart` — entrance token과 reduce-motion 처리.
- Create: `lib/shared/widgets/branch_fade_through.dart` — shell을 한 번만 보유하는 활성 브랜치 전환 래퍼.
- Modify: `lib/shared/widgets/app_bottom_nav.dart` — navigation shell을 위 래퍼로 감싼다.
- Modify: `lib/features/today/widgets/completion_animation.dart` — 모션 상한, 중립 문구, 닫기 semantics, 중복 dismiss 방지.
- Modify: `lib/features/timeline/timeline_screen.dart` — 빈 타임라인의 오늘 기록 CTA.
- Modify: `lib/features/onboarding/onboarding_screen.dart` — 온보딩 모션과 reduced-motion 전환을 공통 토큰으로 통일한다.
- Modify: `lib/features/settings/widgets/appearance_section.dart` — 액센트 테마 선택 피드백을 공통 토큰으로 통일한다.
- Modify: `lib/app/router.dart` — 온보딩 라우트 전환에서 reduced-motion을 존중한다.
- Modify: `lib/features/today/widgets/streak_pulse_badge.dart` — 상시 반복 펄스를 1회 finite 강조로 바꿔 화면 체류 중 ticker를 제거한다.
- Modify: `lib/features/today/today_screen.dart` — 화면 날짜·미니 그래프의 기준을 `AppClock`으로 통일한다.
- Create: `test/core/theme/app_motion_test.dart` — token 불변값 테스트.
- Create: `test/shared/widgets/branch_fade_through_test.dart` — transition/reduce-motion/dispose 테스트.
- Modify: `test/shared/widgets/staggered_fade_in_test.dart` — entrance token과 bounded delay 기대값.
- Modify: `test/features/today/widgets/completion_animation_test.dart` — semantics·즉시 닫기·중립 문구 테스트.
- Modify: `test/features/timeline/timeline_screen_test.dart` — 빈 상태 CTA 테스트.

### Task 1: 공통 모션 토큰과 진입 애니메이션 정리

**Files:**
- Create: `lib/core/theme/app_motion.dart`
- Modify: `lib/shared/widgets/staggered_fade_in.dart`
- Modify: `lib/features/timeline/widgets/heatmap_grid.dart`
- Modify: `lib/features/insights/widgets/insights_locked_view.dart`
- Create: `test/core/theme/app_motion_test.dart`
- Modify: `test/shared/widgets/staggered_fade_in_test.dart`

**Interfaces:**
- Produces `AppMotion.instant`, `AppMotion.micro`, `AppMotion.standard`, `AppMotion.entrance`, `AppMotion.celebration`, `AppMotion.standardCurve`, and `AppMotion.reduceMotion(BuildContext)`.
- Existing widgets continue to accept their current public constructors; callers do not pass raw animation settings for this task.

- [x] **Step 1: Write the failing token test**

Create `test/core/theme/app_motion_test.dart` with exact contract values:

```dart
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
```

- [x] **Step 2: Run the focused test and verify it fails**

Run:

```bash
flutter test test/core/theme/app_motion_test.dart
```

Expected: FAIL because `lib/core/theme/app_motion.dart` does not exist yet.

- [x] **Step 3: Add the minimal token implementation**

Create `lib/core/theme/app_motion.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const instant = Duration.zero;
  static const micro = Duration(milliseconds: 120);
  static const standard = Duration(milliseconds: 240);
  static const entrance = Duration(milliseconds: 360);
  static const celebration = Duration(milliseconds: 600);
  static const Curve standardCurve = Curves.easeOutCubic;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
}
```

- [x] **Step 4: Replace targeted raw durations and bound stagger delay**

In `StaggeredFadeIn`, import `app_motion.dart`, set the default interval to `AppMotion.micro`, set the controller duration to `AppMotion.entrance`, and use `AppMotion.standardCurve` for both animations. Cap the index at `4` so the largest entrance delay is `480ms`; keep the existing timer cancellation and `AppMotion.reduceMotion(context)` snap behavior.

In `HeatmapGrid`, set `_waveController` duration to `AppMotion.entrance` and use `AppMotion.standardCurve` for the interval. In `InsightsLockedView`, set the controller duration to `AppMotion.entrance`, use the same curve for fade/scale/progress, and in `didChangeDependencies` set `_controller.value = 1.0` when `AppMotion.reduceMotion(context)` is true. Do not alter chart data or unlock thresholds.

- [x] **Step 5: Update the staggered widget test for the new bound**

Add this test to `test/shared/widgets/staggered_fade_in_test.dart`:

```dart
testWidgets('높은 index도 480ms 안에 진입을 시작한다', (tester) async {
  await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StaggeredFadeIn(
          key: const ValueKey<String>('bounded-stagger'),
          index: 99,
          child: const Text('bounded'),
        ),
    ),
  ));

    await tester.pump(const Duration(milliseconds: 479));
    final before = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('bounded-stagger')),
        matching: find.byType(FadeTransition),
      ),
  );
  expect(before.opacity.value, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 360));
    final after = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('bounded-stagger')),
        matching: find.byType(FadeTransition),
      ),
  );
  expect(after.opacity.value, 1.0);
});
```

- [x] **Step 6: Run focused tests and static analysis**

Run:

```bash
flutter test test/core/theme/app_motion_test.dart test/shared/widgets/staggered_fade_in_test.dart test/features/timeline/widgets/heatmap_grid_test.dart
dart analyze lib/core/theme/app_motion.dart lib/shared/widgets/staggered_fade_in.dart lib/features/timeline/widgets/heatmap_grid.dart lib/features/insights/widgets/insights_locked_view.dart
```

Expected: all focused tests pass and analyzer reports no issues.

- [x] **Step 7: Commit the task**

```bash
git add lib/core/theme/app_motion.dart lib/shared/widgets/staggered_fade_in.dart lib/features/timeline/widgets/heatmap_grid.dart lib/features/insights/widgets/insights_locked_view.dart test/core/theme/app_motion_test.dart test/shared/widgets/staggered_fade_in_test.dart
git commit -m "feat: centralize motion timing and reduce stagger delay"
```

### Task 2: GlobalKey 안전성을 유지하는 하단 탭 fade-through

**Files:**
- Create: `lib/shared/widgets/branch_fade_through.dart`
- Modify: `lib/shared/widgets/app_bottom_nav.dart`
- Create: `test/shared/widgets/branch_fade_through_test.dart`

**Interfaces:**
- `BranchFadeThrough({Key? key, required Object transitionKey, required Widget child})` keeps exactly one `child` in the tree and restarts only when `transitionKey` changes.
- `ScaffoldWithNavBar` continues to receive the same `StatefulNavigationShell` and retains `goBranch` behavior and `NavigationBar` semantics.

- [x] **Step 1: Write transition and reduced-motion tests**

Create `test/shared/widgets/branch_fade_through_test.dart`:

```dart
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
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const MaterialApp(
        home: BranchFadeThrough(
          transitionKey: 0,
          child: Text('첫 화면'),
        ),
      ),
    ));
    await tester.pump();

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const MaterialApp(
        home: BranchFadeThrough(
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
```

- [x] **Step 2: Run the focused test and verify it fails**

Run `flutter test test/shared/widgets/branch_fade_through_test.dart`.

Expected: FAIL because the wrapper has not been implemented.

- [x] **Step 3: Implement a single-child transition wrapper**

Create `lib/shared/widgets/branch_fade_through.dart`:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class BranchFadeThrough extends StatefulWidget {
  const BranchFadeThrough({
    super.key,
    required this.transitionKey,
    required this.child,
  });

  final Object transitionKey;
  final Widget child;

  @override
  State<BranchFadeThrough> createState() => _BranchFadeThroughState();
}

class _BranchFadeThroughState extends State<BranchFadeThrough>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  var _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppMotion.standard,
      value: 1.0,
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.standardCurve,
    );
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(curved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.reduceMotion(context);
    if (_reduceMotion) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant BranchFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transitionKey == widget.transitionKey) return;
    if (_reduceMotion) {
      _controller.value = 1.0;
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const ValueKey<String>('branch-fade-through'),
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
```

- [x] **Step 4: Wire the wrapper without duplicating the navigation shell**

In `lib/shared/widgets/app_bottom_nav.dart`, import the new wrapper and replace `body: navigationShell` with:

```dart
body: BranchFadeThrough(
  transitionKey: navigationShell.currentIndex,
  child: navigationShell,
),
```

Update the nearby comment to state that the shell remains a single child and only the wrapper’s opacity/offset animates. Do not use `AnimatedSwitcher`, `KeyedSubtree` around a second shell, or a second `StatefulNavigationShell` instance.

- [x] **Step 5: Run transition tests and existing navigation regression tests**

Run:

```bash
flutter test test/shared/widgets/branch_fade_through_test.dart test/app/routing_flash_test.dart test/integration/app_flow_test.dart
```

Expected: all tests pass, including no onboarding/lock flash and no duplicate GlobalKey exception.

- [x] **Step 6: Commit the task**

```bash
git add lib/shared/widgets/branch_fade_through.dart lib/shared/widgets/app_bottom_nav.dart test/shared/widgets/branch_fade_through_test.dart
git commit -m "feat: add global-key-safe branch fade transition"
```

### Task 3: 저장 완료 피드백을 짧고 명시적으로 개선

**Files:**
- Modify: `lib/features/today/widgets/completion_animation.dart`
- Modify: `test/features/today/widgets/completion_animation_test.dart`

**Interfaces:**
- `CompletionAnimation` constructor remains source-compatible (`onComplete`, `streak`, `emotion`).
- The private `_dismiss()` method invokes `onComplete` at most once, regardless of background auto-dismiss or repeated taps.

- [x] **Step 1: Add failing tests for semantics, immediate close, and neutral copy**

Extend `test/features/today/widgets/completion_animation_test.dart`. First add `int emotion = 3` to the existing `buildApp` helper and pass it to `CompletionAnimation`, then add these tests:

```dart
testWidgets('완료 화면은 즉시 접근 가능한 닫기 버튼과 route semantics를 제공한다',
    (tester) async {
  final semantics = tester.ensureSemantics();
  var completed = false;
  await tester.pumpWidget(buildApp(onComplete: () => completed = true));
  await tester.pump();

  expect(find.bySemanticsLabel('기록 저장 완료'), findsOneWidget);
  expect(find.bySemanticsLabel('완료 화면 닫기'), findsOneWidget);

  await tester.tap(find.text('닫기'));
  expect(completed, isTrue);
  semantics.dispose();
  await drainTimers(tester);
});

testWidgets('완료 문구가 저널 원문이나 효능 보장을 노출하지 않는다', (tester) async {
  await tester.pumpWidget(buildApp(emotion: 5));
  await tester.pump(const Duration(milliseconds: 700));

  expect(find.text('감사를 기록하는 사람이 행복해진대요'), findsNothing);
  expect(find.textContaining('행복해진대요'), findsNothing);
  await drainTimers(tester);
});

testWidgets('닫기와 자동 종료가 중복 callback을 만들지 않는다', (tester) async {
  var calls = 0;
  await tester.pumpWidget(buildApp(onComplete: () => calls++));
  await tester.pump();
  await tester.tap(find.text('닫기'));
  await tester.pump(const Duration(seconds: 3));
  expect(calls, 1);
});
```

- [x] **Step 2: Run the focused tests and verify the new tests fail**

Run `flutter test test/features/today/widgets/completion_animation_test.dart`.

Expected: the semantics labels/buttons are missing and the old efficacy copy is still present.

- [x] **Step 3: Apply motion tokens and add an idempotent dismiss path**

Import `app_motion.dart`. Set checkmark, particle, and text controller durations to `AppMotion.celebration`, `AppMotion.celebration`, and `AppMotion.standard` respectively. Replace the fixed 400ms text delay with `AppMotion.micro`; retain the 2500ms hold only as a non-blocking automatic fallback. Add:

```dart
bool _dismissed = false;

void _dismiss() {
  if (_dismissed) return;
  _dismissed = true;
  widget.onComplete?.call();
}
```

Use `_dismiss()` for the delayed callback and all tap actions. Keep the existing mounted checks before calling it from asynchronous code.

- [x] **Step 4: Add accessible close semantics and neutral copy**

Change the root to a `Semantics` container with `scopesRoute: true`, `namesRoute: true`, `label: '기록 저장 완료'`, and `explicitChildNodes: true`. Keep the full-screen tap as a convenience gesture using `_dismiss`, but add a bottom `SafeArea` child that is always built:

```dart
Semantics(
  button: true,
  label: '완료 화면 닫기',
  child: TextButton(
    onPressed: _dismiss,
    child: const Text('닫기'),
  ),
)
```

Remove the low-contrast `탭하여 닫기` instruction. Replace the emotion-5 message `감사를 기록하는 사람이 행복해진대요` with the neutral `오늘의 감정을 차분히 남겼어요`. Keep the emotion label and streak badge as descriptive, non-clinical text.

- [x] **Step 5: Make reduce-motion completion immediate without removing the close action**

Use `AppMotion.reduceMotion(context)` in `didChangeDependencies` and preserve the existing final-state snap. The close button must remain present during reduce-motion and the automatic 2500ms fallback must still be guarded by `_dismiss()`.

- [x] **Step 6: Run completion tests and static analysis**

Run:

```bash
flutter test test/features/today/widgets/completion_animation_test.dart test/features/today/widgets/animated_save_button_test.dart
dart analyze lib/features/today/widgets/completion_animation.dart
```

Expected: all focused tests pass and analyzer reports no issues.

- [x] **Step 7: Commit the task**

```bash
git add lib/features/today/widgets/completion_animation.dart test/features/today/widgets/completion_animation_test.dart
git commit -m "feat: make completion feedback accessible and dismissible"
```

### Task 4: 빈 상태에서 오늘 기록으로 한 번에 회복

**Files:**
- Modify: `lib/features/timeline/timeline_screen.dart`
- Modify: `test/features/timeline/timeline_screen_test.dart`

**Interfaces:**
- Timeline data/controller and database schema remain unchanged.
- The empty-state CTA navigates with the existing `go_router` route `/`; no new global state is introduced.

- [x] **Step 1: Add a failing empty-state CTA test**

Add `import 'package:go_router/go_router.dart';`, then add an empty controller and test to `test/features/timeline/timeline_screen_test.dart`:

```dart
final class _EmptyTimelineController extends TimelineController {
  @override
  Future<TimelineState> build() async => const TimelineState();
}

testWidgets('기록이 없는 타임라인은 오늘 기록 CTA를 제공한다', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        timelineControllerProvider.overrideWith(
          () => _EmptyTimelineController(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/timeline',
          routes: [
            GoRoute(
              path: '/timeline',
              builder: (_, _) => const TimelineScreen(),
            ),
            GoRoute(
              path: '/',
              builder: (_, _) => const Text('today destination'),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('첫 기록을 시작해보세요'), findsOneWidget);
  expect(find.text('오늘 기록하기'), findsOneWidget);
  await tester.tap(find.text('오늘 기록하기'));
  await tester.pumpAndSettle();
  expect(find.text('today destination'), findsOneWidget);
});
```

- [x] **Step 2: Run the focused test and verify it fails**

Run `flutter test test/features/timeline/timeline_screen_test.dart`.

Expected: FAIL because the empty state has no `오늘 기록하기` button.

- [x] **Step 3: Add the CTA with existing router semantics**

Import `package:go_router/go_router.dart` and `../../core/theme/app_motion.dart`. In the empty-state `Column`, after `첫 기록을 시작해보세요`, add:

```dart
const SizedBox(height: 20),
FilledButton.tonal(
  onPressed: () => context.go('/'),
  child: const Text('오늘 기록하기'),
),
```

Keep the existing non-judgmental copy and 600ms entrance behavior, but replace that raw duration with `AppMotion.entrance`. Do not add a streak warning or imply that an empty timeline is a failure.

- [x] **Step 4: Run timeline tests and analyzer**

Run:

```bash
flutter test test/features/timeline/timeline_screen_test.dart test/features/insights/insights_screen_test.dart
dart analyze lib/features/timeline/timeline_screen.dart
```

Expected: all tests pass and analyzer reports no issues.

- [x] **Step 5: Commit the task**

```bash
git add lib/features/timeline/timeline_screen.dart test/features/timeline/timeline_screen_test.dart
git commit -m "feat: add one-tap recovery from empty timeline"
```

### Task 5: 통합 회귀·접근성·성능 검증

**Files:**
- Create: `docs/superpowers/reviews/2026-08-28-frictionless-calm-ux-evolution.md` — 실행한 검증 결과와 잔여 실기기 게이트를 기록한다.

- [x] **Step 1: Run the complete Flutter verification suite**

Run:

```bash
dart format --output=none --set-exit-if-changed lib test
dart analyze
flutter test
git diff --check "$(git merge-base HEAD main)"..HEAD
```

Expected: analyzer reports no issues, all tests pass, and diff check is clean. On the current branch the repository-wide formatter check reports 49 pre-existing files that differ under the installed Dart formatter; it must not be used as evidence against this UX change. Run the targeted formatter check below and require exit 0 for every file touched by this plan. If the number of tests changes, record the actual count rather than a hard-coded expectation.

```bash
dart format --output=none --set-exit-if-changed \
  lib/core/theme/app_motion.dart lib/shared/widgets/branch_fade_through.dart \
  lib/shared/widgets/app_bottom_nav.dart lib/shared/widgets/staggered_fade_in.dart \
  lib/features/timeline/widgets/heatmap_grid.dart \
  lib/features/insights/widgets/insights_locked_view.dart \
  lib/features/today/widgets/completion_animation.dart \
  lib/features/timeline/timeline_screen.dart \
  test/core/theme/app_motion_test.dart test/shared/widgets/branch_fade_through_test.dart \
  test/shared/widgets/staggered_fade_in_test.dart \
  test/features/today/widgets/completion_animation_test.dart \
  test/features/timeline/timeline_screen_test.dart
```

- [x] **Step 2: Run targeted accessibility checks**

Run the existing accessibility suites and the new completion/branch tests:

```bash
flutter test test/app/accessibility_guideline_test.dart test/app/text_scaling_test.dart test/shared/widgets/branch_fade_through_test.dart test/features/today/widgets/completion_animation_test.dart
```

Expected: Android/iOS tap-target and labeled-target guidelines pass; 200% text scaling test passes; reduce-motion and close semantics tests pass.

- [x] **Step 3: Perform a connected-device profile check**

On one Android and one iOS device, execute this exact flow in profile mode: cold launch → Today first input → save → tap close before 600ms → Timeline → Insights → Settings → return to Today. Repeat with system reduce-motion enabled and 200% text size. Confirm no frame hitch is visible during branch switch, the close button is reachable, and no animation blocks the next input. Record device/OS/mode and qualitative result; do not claim a fixed 60fps from host widget tests.

- [x] **Step 4: Review safety and release gates**

Confirm that completion/notification copy contains no journal answer or clinical efficacy promise. Keep iOS signing/provisioning, CocoaPods sync, real-device notification/widget reboot-timezone, Face ID, and battery tests as separate release gates; this plan does not mark those blocked operational items as solved.

- [x] **Step 5: Write the verification review**

Create `docs/superpowers/reviews/2026-08-28-frictionless-calm-ux-evolution.md` with sections `변경 요약`, `자동 검증`, `접근성 검증`, `실기기 검증`, `잔여 릴리스 게이트`. Include command outputs and explicit pass/fail status, with unknown device checks marked `미실행` rather than inferred as passed.

- [x] **Step 6: Commit the verification record**

```bash
git add docs/superpowers/reviews/2026-08-28-frictionless-calm-ux-evolution.md
git commit -m "docs: record frictionless calm ux verification"
```

### Task 6: 핵심 입력 피드백의 reduce-motion·모션 토큰 일관성

**Files:**
- Modify: `lib/core/theme/app_motion.dart` — 일반 모션을 reduce-motion에서 즉시 상태로 바꾸는 helper를 추가한다.
- Modify: `lib/features/today/widgets/emotion_picker.dart` — 선택 scale·색상·라벨 전환에 helper와 공통 curve를 사용한다.
- Modify: `lib/features/today/widgets/prompt_card.dart` — focus/read-only 전환과 답변 editor switcher에 helper를 사용한다.
- Modify: `lib/features/today/widgets/animated_save_button.dart` — 진행 링·카운터 전환에 helper를 사용한다.
- Test: `test/core/theme/app_motion_test.dart`, `test/features/today/widgets/emotion_picker_test.dart`, `test/features/today/widgets/prompt_card_test.dart`, `test/features/today/widgets/animated_save_button_test.dart`.

- [x] **Step 1: Write failing reduce-motion tests**

Add a unit test for `AppMotion.durationFor(context, normal)` and widget tests that pump the three input widgets under `MediaQuery(disableAnimations: true)`. Assert that selection feedback, read/edit switching, and progress/count feedback settle at their final state without advancing a finite animation clock.

- [x] **Step 2: Run the focused tests and verify they fail**

Run:

```bash
flutter test test/core/theme/app_motion_test.dart test/features/today/widgets/emotion_picker_test.dart test/features/today/widgets/prompt_card_test.dart test/features/today/widgets/animated_save_button_test.dart
```

Expected: the new helper assertion fails because it does not exist and at least one widget remains in its animated intermediate state under `disableAnimations`.

- [x] **Step 3: Add the minimal duration helper**

Add `AppMotion.durationFor(BuildContext context, Duration normal)` that returns `AppMotion.instant` when `AppMotion.reduceMotion(context)` is true and otherwise returns `normal`. Keep existing token values and public widget constructors unchanged.

- [x] **Step 4: Apply the helper only to core input feedback**

Use `AppMotion.durationFor` and `AppMotion.standardCurve` for the `AnimatedOpacity`, `AnimatedScale`, `AnimatedContainer`, `AnimatedDefaultTextStyle`, `AnimatedSwitcher`, `TweenAnimationBuilder`, and count/progress transitions in the three input widgets. Do not add new continuous animation, change text validation, or alter save semantics.

- [x] **Step 5: Run focused tests and static analysis**

Run the focused test command again plus:

```bash
dart analyze lib/core/theme/app_motion.dart lib/features/today/widgets/emotion_picker.dart lib/features/today/widgets/prompt_card.dart lib/features/today/widgets/animated_save_button.dart
```

Expected: all focused tests pass, reduced-motion widgets render their final state immediately, and analyzer reports no issues.

- [x] **Step 6: Run the complete regression suite**

Run `flutter test` and the existing accessibility/text-scaling suites. Restore unrelated generated Flutter metadata after the command, then run the targeted formatter check and `git diff --check`.

- [x] **Step 7: Record and commit the follow-up**

Update the verification report with the new focused command and commit:

```bash
git add lib/core/theme/app_motion.dart lib/features/today/widgets/emotion_picker.dart lib/features/today/widgets/prompt_card.dart lib/features/today/widgets/animated_save_button.dart test/core/theme/app_motion_test.dart test/features/today/widgets/emotion_picker_test.dart test/features/today/widgets/prompt_card_test.dart test/features/today/widgets/animated_save_button_test.dart docs/superpowers/reviews/2026-08-28-frictionless-calm-ux-evolution.md
git commit -m "feat: respect reduced motion in input feedback"
```

### Task 7: 인사이트 시각화 모션의 상한·reduce-motion 정합성

**Files:**
- Modify: `lib/features/insights/widgets/emotion_trend_chart.dart` — 차트 진입 애니메이션을 360ms 토큰으로 제한하고 reduce-motion에서 즉시 표시한다.
- Modify: `lib/features/insights/widgets/stat_card.dart` — 카운트업/진입 애니메이션을 토큰화하고 reduce-motion에서 최종 값을 바로 표시한다.
- Modify: `lib/features/timeline/widgets/streak_badge.dart` — 스트릭 카운트업을 토큰화하고 reduce-motion에서 최종 값을 바로 표시한다.
- Modify: `lib/features/insights/widgets/keyword_cloud.dart` — 키워드 stagger를 600ms 이내로 제한하고 reduce-motion에서 모든 pill을 즉시 표시한다.
- Test: 각 위젯의 기존 테스트에 reduce-motion 최종 상태 회귀를 추가한다.

- [x] **Step 1: Write failing visualization tests**

Pump each visualization under `MediaQuery(disableAnimations: true)` and assert that the chart opacity, numeric values, streak values, and keyword pills are already at their final visible state after one frame.

- [x] **Step 2: Run the focused tests and verify they fail**

Run the four existing widget test files. Expected: at least one finite visualization remains at its initial animation state because the current implementation does not read `disableAnimations`.

- [x] **Step 3: Apply shared motion tokens and snap behavior**

Use `AppMotion.entrance`, `AppMotion.standardCurve`, and `AppMotion.reduceMotion(context)` in the four widgets. Set controller values to `1.0` for reduced motion and guard `didUpdateWidget` restarts so data refreshes remain immediate. Preserve chart data, labels, and count semantics.

- [x] **Step 4: Run focused tests and static analysis**

Run the four focused tests and `dart analyze` for the changed widgets. Expected: all tests pass with no issues.

- [x] **Step 5: Run the complete regression suite and update evidence**

Run `flutter test`, the accessibility/text-scaling suite, targeted formatter, and `git diff --check`; restore Flutter-generated metadata and record the final count in the review report.

- [x] **Step 6: Commit the visualization follow-up**

```bash
git add lib/features/insights/widgets/emotion_trend_chart.dart lib/features/insights/widgets/stat_card.dart lib/features/timeline/widgets/streak_badge.dart lib/features/insights/widgets/keyword_cloud.dart test/features/insights/widgets/emotion_trend_chart_test.dart test/features/insights/widgets/stat_card_test.dart test/features/timeline/widgets/streak_badge_test.dart test/features/insights/widgets/keyword_cloud_test.dart docs/superpowers/specs/2026-08-28-frictionless-calm-ux-evolution-design.md docs/superpowers/plans/2026-08-28-frictionless-calm-ux-evolution.md docs/superpowers/reviews/2026-08-28-frictionless-calm-ux-evolution.md
git commit -m "feat: align insight motion with accessibility settings"
```

### Task 8: 잔여 화면 상태·히트 피드백의 모션 계약

**Files:**
- Modify: `lib/features/timeline/widgets/heatmap_grid.dart` — 기록 셀 선택 강조를 reduce-motion에서 즉시 종료하고 공통 micro duration을 사용한다.
- Modify: `lib/features/insights/insights_screen.dart` — 인사이트 해금 배너와 기간 칩의 finite transition을 토큰화하고 reduce-motion에서 최종 상태로 스냅한다.
- Modify: `lib/features/today/today_screen.dart` — 완료 후 sparkline/상태 배지 전환을 토큰화한다.
- Test: `test/features/timeline/widgets/heatmap_grid_test.dart`, `test/features/insights/insights_screen_test.dart`.
- Create: `test/features/today/today_screen_test.dart` — 완료 상태 배지의 reduce-motion 최종 표시를 검증한다.

- [x] **Step 1: Write failing residual-motion tests**

Under `MediaQuery(disableAnimations: true)`, assert the heatmap highlight, period chip, unlock banner, and Today completed-state badge expose zero-duration or final-state behavior after one frame.

- [x] **Step 2: Run the focused tests and verify they fail**

Run the three focused widget test files. Expected: current hard-coded transitions retain non-zero durations or an intermediate controller value.

- [x] **Step 3: Apply tokens and immediate-state behavior**

Use `AppMotion.durationFor`, `AppMotion.standardCurve`, and controller snapping where needed. Keep haptic feedback, navigation, data queries, and existing semantics unchanged; do not add polling or continuous animation.

- [x] **Step 4: Run focused tests and static analysis**

Run the three focused tests and `dart analyze` for changed files. Expected: all tests pass with no issues.

- [x] **Step 5: Run the complete regression suite and update evidence**

Run `flutter test`, accessibility/text-scaling suites, targeted formatter, and `git diff --check`; restore unrelated generated metadata and record the final count.

- [x] **Step 6: Commit the residual-motion follow-up**

```bash
git add lib/features/timeline/widgets/heatmap_grid.dart lib/features/insights/insights_screen.dart lib/features/today/today_screen.dart test/features/timeline/widgets/heatmap_grid_test.dart test/features/insights/insights_screen_test.dart test/features/today/today_screen_test.dart docs/superpowers/plans/2026-08-28-frictionless-calm-ux-evolution.md docs/superpowers/reviews/2026-08-28-frictionless-calm-ux-evolution.md
git commit -m "feat: finish reduced motion coverage"
```

### Task 9: 앱 외곽 화면의 모션 계약 정합성

**Files:**
- Modify: `lib/features/onboarding/onboarding_screen.dart` — 온보딩 점·버튼·다음 페이지 전환에 `AppMotion`과 reduced-motion을 적용한다.
- Modify: `lib/features/settings/widgets/appearance_section.dart` — 액센트 선택 상태 전환에 `AppMotion.durationFor`를 적용한다.
- Modify: `lib/features/timeline/timeline_screen.dart` — 빈 타임라인 진입 애니메이션을 reduced-motion에서 즉시 완료한다.
- Modify: `lib/app/router.dart` — 온보딩 라우트 전환에서 시각적 이동을 제거한다.
- Modify: `lib/features/today/widgets/streak_pulse_badge.dart` — 무한 glow 반복을 진입 1회 펄스로 제한한다.
- Test: `test/features/onboarding/onboarding_screen_test.dart`, `test/features/settings/widgets/appearance_section_test.dart`, `test/features/timeline/timeline_screen_test.dart`.
- Test: `test/features/today/widgets/streak_pulse_badge_test.dart`.

- [x] **Step 1: Write failing residual-screen tests**

`MediaQuery(disableAnimations: true)`에서 온보딩 `AnimatedSwitcher`·점 표시기, 액센트 칩, 빈 타임라인 진입의 duration이 0인지 확인하는 위젯 테스트를 먼저 추가했다.

- [x] **Step 2: Run the focused tests and verify they fail**

기존 하드코딩 duration(200–300ms)과 360ms 진입 애니메이션 때문에 세 테스트가 RED가 되는 것을 확인했다.

- [x] **Step 3: Apply tokens and immediate page navigation**

화면별 duration·curve를 `AppMotion`으로 통일하고, reduced-motion에서는 온보딩 parallax를 고정하고 다음 페이지를 `jumpToPage`로 이동하며 라우트 전환을 시각적으로 생략한다. 스트릭 배지는 화면 체류 중 무한 ticker 대신 진입 1회 펄스만 재생한다.

- [x] **Step 4: Run focused tests and static analysis**

온보딩·설정·타임라인·스트릭 focused tests 12개와 변경 파일 `dart analyze`를 통과했다.

- [x] **Step 5: Include in complete regression and release review**

전체 Flutter 테스트·접근성 검증 및 formatter/diff 검사를 Task 5 최종 실행에 포함하고, 실제 테스트 수와 미실행 실기기 게이트를 review 문서에 기록한다.

### Task 10: Today 날짜 기준 단일화

**Files:**
- Modify: `lib/features/today/today_screen.dart` — 헤더 날짜와 최근 7일 미니 그래프가 컨트롤러·저장 로직과 동일한 `AppClock`을 사용하도록 한다.
- Test: `test/features/today/today_screen_test.dart` — 고정 시계에서 표시 날짜가 어긋나지 않는지 검증한다.

- [x] **Step 1: Write the failing clock-consistency test**

`appClockProvider`를 고정 날짜로 override하고 Today 화면의 헤더가 실제 시스템 시각이 아닌 앱 시계 날짜를 표시해야 한다는 테스트를 추가했다.

- [x] **Step 2: Run the focused test and verify it fails**

기존 `DateTime.now()` 경로에서 고정 날짜 텍스트를 찾지 못하는 RED를 확인했다.

- [x] **Step 3: Use the shared clock for all Today date-derived visuals**

화면 build에서 `AppClock.now()`를 한 번 읽어 헤더와 `_MiniSparkline`에 전달하고, 그래프의 7일 범위도 같은 기준 인스턴스를 사용한다. 저장·알림·DB 계약은 변경하지 않는다.

- [x] **Step 4: Run focused tests and static analysis**

Today 화면 focused tests 2개와 변경 파일 `dart analyze`를 통과했다.

- [x] **Step 5: Include in complete regression and release review**

전체 Flutter 테스트와 diff/formatter 검증 결과를 review 문서에 최신 수로 기록한다.

## Plan Self-Review

- **Spec coverage:** MOT-001/002/003 map to Tasks 1–2 and 6–9; SAVE-001 maps to Task 3; A11Y-001 maps to Tasks 2–3 and 5–10; REC-001 maps to Task 4; DATE-001 maps to the existing local-calendar implementation plus Task 10's shared-clock display test. P1 notification controls, iOS signing, and physical notification/DST gates are explicitly not silently claimed by this plan.
- **Placeholder scan:** 완료되지 않은 항목을 숨기는 표시어나 추후로 미루는 구현 지시가 없고, 오류 처리·테스트 명령이 각 단계에 구체적으로 적혀 있다.
- **Type consistency:** `AppMotion` names are used consistently; `BranchFadeThrough.transitionKey` is `Object`; `ScaffoldWithNavBar` passes `navigationShell.currentIndex`; `_dismiss()` is the sole completion callback path; the empty timeline test uses the existing `TimelineState` defaults.
- **Scope check:** Tasks 1–4 and 6–10 are independently testable and share only the motion helper/clock abstractions. Task 5 is verification/documentation; Tasks 6–9 change only finite visual feedback and Task 10 only aligns display dates with the existing clock, without altering data, notification, or persistence contracts.
- **Test observability:** Task 4는 `/` 라우트에 `today destination` 텍스트를 렌더링하는 테스트 전용 목적지를 두고, CTA 탭 후 해당 텍스트를 검사해 실제 경로 이동을 증명한다. 버튼 탭 성공만으로 통과시키지 않는다.
