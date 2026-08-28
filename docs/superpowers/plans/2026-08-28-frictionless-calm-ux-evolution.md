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

## Plan Self-Review

- **Spec coverage:** MOT-001/002/003 map to Tasks 1–2 and Task 6; SAVE-001 maps to Task 3; A11Y-001 maps to Tasks 2–3, 5, and 6; REC-001 maps to Task 4; DATE-001 remains covered by the existing local-calendar implementation and its existing date tests. P1 notification controls, iOS signing, and physical notification/DST gates are explicitly not silently claimed by this plan.
- **Placeholder scan:** 완료되지 않은 항목을 숨기는 표시어나 추후로 미루는 구현 지시가 없고, 오류 처리·테스트 명령이 각 단계에 구체적으로 적혀 있다.
- **Type consistency:** `AppMotion` names are used consistently; `BranchFadeThrough.transitionKey` is `Object`; `ScaffoldWithNavBar` passes `navigationShell.currentIndex`; `_dismiss()` is the sole completion callback path; the empty timeline test uses the existing `TimelineState` defaults.
- **Scope check:** Tasks 1–4 and Task 6 are independently testable and share only the motion helper. Task 5 is verification/documentation and Task 6 changes only finite input feedback; neither changes data, notification, or routing contracts.
- **Test observability:** Task 4는 `/` 라우트에 `today destination` 텍스트를 렌더링하는 테스트 전용 목적지를 두고, CTA 탭 후 해당 텍스트를 검사해 실제 경로 이동을 증명한다. 버튼 탭 성공만으로 통과시키지 않는다.
