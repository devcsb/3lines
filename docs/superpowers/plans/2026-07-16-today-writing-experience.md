# Today Writing Experience Implementation Plan

> **Status:** Completed — shipped in `0518a6e` (`feat(today): improve save guidance and operation safety`)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Today 화면에서 저장 조건과 답변 진행 상태를 명확히 안내하고, 기존 기록 편집을 안전하게 취소할 수 있게 한다.

**Architecture:** `TodayState`가 안내 문구와 답변 수를 파생 값으로 제공하고 `AnimatedSaveButton`이 이를 표시한다. `TodayController.cancelEdit()`이 저장된 `DailyEntry`를 복원하며 미저장 사진 수명 주기를 함께 처리한다.

**Tech Stack:** Flutter, Dart, Riverpod `AsyncNotifier`, Flutter Test

## Global Constraints

- 저장 가능 조건은 `감정 1개 + 비어 있지 않은 답변 1개 이상`이다.
- 새 기록 작성 중에는 편집 취소 명령을 제공하지 않는다.
- 기존 DB 사진은 편집 취소 시 삭제하지 않는다.
- 외부 패키지와 데이터베이스 스키마를 추가하거나 변경하지 않는다.

---

### Task 1: 저장 안내 상태

**Files:**
- Modify: `lib/features/today/today_state.dart`
- Test: `test/features/today/today_state_test.dart`

**Interfaces:**
- Produces: `int get filledAnswerCount`, `String get saveGuidanceMessage`

- [x] **Step 1: Write the failing tests**

```dart
group('writing progress', () {
  test('counts only non-empty trimmed answers', () {
    const state = TodayState(answer1: '한 줄', answer2: '  ', answer3: '세 줄');
    expect(state.filledAnswerCount, 2);
  });

  test('asks for emotion before an answer', () {
    const state = TodayState(answer1: '한 줄');
    expect(state.saveGuidanceMessage, '오늘의 감정을 먼저 골라주세요');
  });

  test('asks for one line after emotion is selected', () {
    const state = TodayState(emotion: 3);
    expect(state.saveGuidanceMessage, '한 줄만 적어도 저장할 수 있어요');
  });

  test('reports ready when save condition is met', () {
    const state = TodayState(emotion: 3, answer2: '한 줄');
    expect(state.saveGuidanceMessage, '저장할 준비가 됐어요');
  });
});
```

- [x] **Step 2: Run the state test and verify RED**

Run: `flutter test test/features/today/today_state_test.dart`

Expected: FAIL because `filledAnswerCount` and `saveGuidanceMessage` are not defined.

- [x] **Step 3: Add the minimal derived state**

```dart
int get filledAnswerCount => [answer1, answer2, answer3]
    .where((answer) => answer.trim().isNotEmpty)
    .length;

String get saveGuidanceMessage {
  if (emotion == null) return '오늘의 감정을 먼저 골라주세요';
  if (filledAnswerCount == 0) return '한 줄만 적어도 저장할 수 있어요';
  return '저장할 준비가 됐어요';
}
```

- [x] **Step 4: Run the state test and verify GREEN**

Run: `flutter test test/features/today/today_state_test.dart`

Expected: all tests pass.

### Task 2: 저장 영역 진행 표시

**Files:**
- Modify: `lib/features/today/widgets/animated_save_button.dart`
- Modify: `lib/features/today/today_screen.dart`
- Create: `test/features/today/widgets/animated_save_button_test.dart`

**Interfaces:**
- Consumes: `TodayState.filledAnswerCount`, `TodayState.saveGuidanceMessage`
- Produces: `AnimatedSaveButton.guidanceMessage`

- [x] **Step 1: Write failing widget tests**

```dart
testWidgets('shows guidance and answer progress', (tester) async {
  await tester.pumpWidget(buildApp(
    filledCount: 2,
    guidanceMessage: '저장할 준비가 됐어요',
  ));
  expect(find.text('저장할 준비가 됐어요'), findsOneWidget);
  expect(find.text('2/3'), findsOneWidget);
});

testWidgets('disables save until requirements are met', (tester) async {
  await tester.pumpWidget(buildApp(canSave: false));
  final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
  expect(button.onPressed, isNull);
});
```

- [x] **Step 2: Run the widget test and verify RED**

Run: `flutter test test/features/today/widgets/animated_save_button_test.dart`

Expected: FAIL because `guidanceMessage` and `2/3` are unavailable.

- [x] **Step 3: Render guidance and normalized progress**

Add required `String guidanceMessage` to `AnimatedSaveButton`, render it above the existing row, change the ring text to `'$filledCount/3'`, and pass `state.saveGuidanceMessage` plus `state.filledAnswerCount` from `TodayScreen`.

- [x] **Step 4: Run widget and state tests and verify GREEN**

Run: `flutter test test/features/today/widgets/animated_save_button_test.dart test/features/today/today_state_test.dart`

Expected: all tests pass.

### Task 3: 편집 취소와 원본 복원

**Files:**
- Modify: `lib/features/today/today_controller.dart`
- Modify: `lib/features/today/today_screen.dart`
- Test: `test/features/today/today_controller_test.dart`

**Interfaces:**
- Consumes: `TodayState.existingEntry`, `PhotoService.deletePhoto(String)`
- Produces: `Future<void> TodayController.cancelEdit()`

- [x] **Step 1: Write failing controller tests**

```dart
test('restores persisted fields and exits edit mode', () async {
  // Seed an entry, enter edit mode, mutate emotion/answers/photo, then cancel.
  await notifier.cancelEdit();
  expect(state.emotion, 3);
  expect(state.answer1, '기존 답변');
  expect(state.photoPath, '/db/photo.jpg');
  expect(state.isEditing, isFalse);
});

test('deletes a newly attached photo when cancelling', () async {
  await notifier.cancelEdit();
  expect(fakePhoto.deletedPaths, contains('/new/photo.jpg'));
  expect(fakePhoto.deletedPaths, isNot(contains('/db/photo.jpg')));
});

test('does not interrupt an in-progress save', () async {
  final saveFuture = notifier.save();
  await notifier.cancelEdit();
  expect(state.isEditing, isTrue);
  await saveFuture;
});
```

- [x] **Step 2: Run the controller test and verify RED**

Run: `flutter test test/features/today/today_controller_test.dart`

Expected: FAIL because `cancelEdit()` is not defined.

- [x] **Step 3: Implement cancellation and expose the command**

```dart
Future<void> cancelEdit() async {
  final current = state.value;
  final saved = current?.existingEntry;
  if (current == null || saved == null || !current.isEditing || current.isSaving || current.isCancelling) {
    return;
  }

  state = AsyncData(current.copyWith(isCancelling: true));

  final currentPhoto = current.photoPath;
  if (currentPhoto != null && currentPhoto != saved.photoPath) {
    await ref.read(photoServiceProvider).deletePhoto(currentPhoto);
  }

  state = AsyncData(current.copyWith(
    emotion: () => saved.emotion,
    answer1: saved.answer1,
    answer2: saved.answer2,
    answer3: saved.answer3,
    photoPath: () => saved.photoPath,
    isEditing: false,
    isCancelling: false,
  ));
}
```

In `TodayScreen`, show `TextButton.icon(icon: Icon(Icons.close), label: Text('수정 취소'))` only when `state.isCompleted && state.isEditing`; disable it while `state.isSaving || state.isCancelling`; otherwise await `cancelEdit()` after unfocusing the fields. While saving or cancelling, disable the emotion picker, photo controls, prompt cards, suggestions, and save action.

- [x] **Step 4: Run Today tests and verify GREEN**

Run: `flutter test test/features/today`

Expected: all Today tests pass.

### Task 4: 전체 검증

**Files:**
- Verify only

**Interfaces:**
- Consumes: completed Tasks 1 through 3
- Produces: verified Today behavior without analyzer errors

- [x] **Step 1: Format changed Dart files**

Run: `dart format lib/features/today test/features/today`

Expected: formatter exits with code 0.

- [x] **Step 2: Run focused tests**

Run: `flutter test test/features/today`

Expected: all tests pass.

- [x] **Step 3: Run static analysis**

Run: `flutter analyze`

Expected: no issues found.
