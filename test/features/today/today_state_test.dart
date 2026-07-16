import 'package:flutter_test/flutter_test.dart';
import 'package:three_lines/features/today/today_state.dart';

void main() {
  group('TodayState', () {
    test('default state has null emotion and empty answers', () {
      const state = TodayState();
      expect(state.emotion, isNull);
      expect(state.answer1, isEmpty);
      expect(state.answer2, isEmpty);
      expect(state.answer3, isEmpty);
      expect(state.isCompleted, isFalse);
      expect(state.isEditing, isFalse);
      expect(state.currentStreak, 0);
      expect(state.isSaving, isFalse);
    });

    group('canSave', () {
      test('returns false when emotion is null', () {
        const state = TodayState(answer1: 'test');
        expect(state.canSave, isFalse);
      });

      test('returns false when all answers are empty', () {
        const state = TodayState(emotion: 3);
        expect(state.canSave, isFalse);
      });

      test('returns false when answers only contain whitespace', () {
        const state = TodayState(emotion: 3, answer1: '   ', answer2: '\n');
        expect(state.canSave, isFalse);
      });

      test('returns true when emotion set and at least one answer', () {
        const state = TodayState(emotion: 4, answer1: 'hello');
        expect(state.canSave, isTrue);
      });

      test('returns true with only answer2 filled', () {
        const state = TodayState(emotion: 2, answer2: 'hello');
        expect(state.canSave, isTrue);
      });

      test('returns true with only answer3 filled', () {
        const state = TodayState(emotion: 1, answer3: 'hello');
        expect(state.canSave, isTrue);
      });

      test('returns true with all answers filled', () {
        const state = TodayState(
          emotion: 5,
          answer1: 'a',
          answer2: 'b',
          answer3: 'c',
        );
        expect(state.canSave, isTrue);
      });
    });

    group('writing progress', () {
      test('counts only non-empty trimmed answers', () {
        const state = TodayState(
          answer1: '한 줄',
          answer2: '  ',
          answer3: '세 줄',
        );

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

    group('copyWith', () {
      test('preserves fields when not specified', () {
        const original = TodayState(
          emotion: 3,
          answer1: 'hello',
          isCompleted: true,
          currentStreak: 5,
        );
        final copied = original.copyWith(answer2: 'world');
        expect(copied.emotion, 3);
        expect(copied.answer1, 'hello');
        expect(copied.answer2, 'world');
        expect(copied.isCompleted, isTrue);
        expect(copied.currentStreak, 5);
      });

      test('overwrites specified fields', () {
        const original = TodayState(emotion: 3, answer1: 'old');
        final copied = original.copyWith(emotion: () => 5, answer1: 'new');
        expect(copied.emotion, 5);
        expect(copied.answer1, 'new');
      });

      test('can set isEditing', () {
        const original = TodayState(isEditing: false);
        final copied = original.copyWith(isEditing: true);
        expect(copied.isEditing, isTrue);
      });

      test('can set isSaving', () {
        const original = TodayState(isSaving: false);
        final copied = original.copyWith(isSaving: true);
        expect(copied.isSaving, isTrue);
      });

      test('can clear emotion to null', () {
        const original = TodayState(emotion: 3);
        final copied = original.copyWith(emotion: () => null);
        expect(copied.emotion, isNull);
      });

      test('isSaving defaults to false in copyWith', () {
        const original = TodayState(isSaving: true);
        final copied = original.copyWith(emotion: () => 3);
        expect(copied.isSaving, isTrue);
      });
    });
  });
}
