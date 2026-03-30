enum PromptCategory {
  gratitude,
  acceptance,
  intention;

  String get label => switch (this) {
        gratitude => '감사',
        acceptance => '수용',
        intention => '의도',
      };
}

const defaultPromptQuestions = [
  '오늘 감사한 작은 것 하나는?',
  '오늘 불편했던 감정을, 있는 그대로 인정한다면?',
  '내일 내가 되고 싶은 모습은?',
];

/// Rotating pool — one per category. Picked by day-of-year so the prompt
/// changes daily without any stored state.
const gratitudePromptPool = [
  '오늘 감사한 작은 것 하나는?',
  '오늘 나를 웃게 만든 순간은?',
  '최근 누군가에게 받은 친절이 있다면?',
  '지금 당연하게 여기지만 사실 감사한 것은?',
  '오늘 만난 사람 중 고마운 사람은?',
  '오늘 내 몸이 해준 일 중 감사한 것은?',
  '이번 주 가장 기억에 남는 좋은 순간은?',
];

const acceptancePromptPool = [
  '오늘 불편했던 감정을, 있는 그대로 인정한다면?',
  '오늘 내 맘대로 되지 않았던 것이 나에게 무엇을 가르쳐줬을까요?',
  '지금 내가 바꿀 수 없는 것을 하나 받아들인다면?',
  '오늘 나 자신에게 조금 더 너그러워질 수 있다면?',
  '지금 느끼는 감정을 판단 없이 한 단어로 표현한다면?',
  '오늘 힘들었던 순간, 그 감정은 나에게 무슨 신호였을까요?',
  '내가 완벽하지 않아도 괜찮은 이유를 하나 적어본다면?',
];

const intentionPromptPool = [
  '내일 내가 되고 싶은 모습은?',
  '내일 단 하나만 집중한다면 무엇을 하고 싶나요?',
  '오늘의 나에게 내일의 내가 해주고 싶은 말은?',
  '이번 주 작은 목표를 하나 세운다면?',
  '내일 나에게 친절한 행동 하나를 미리 계획한다면?',
  '한 달 후 내 모습을 상상한다면?',
  '지금의 나에게 가장 필요한 것을 한 가지 정한다면?',
];

const promptCategories = PromptCategory.values;
