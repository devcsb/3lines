enum PromptCategory {
  gratitude,
  acceptance,
  intention;

  String get label => switch (this) {
    gratitude => '꺼내놓기',
    acceptance => '지금 마음',
    intention => '나를 돌보기',
  };
}

const defaultPromptQuestions = [
  '지금 꺼내놓고 싶은 이야기가 있나요?',
  '지금 내 마음에 머물러 있는 것은?',
  '지금 나에게 필요한 것이 있다면?',
];

/// Daily rotation keeps each category open to difficult or uncertain days.
const gratitudePromptPool = [
  '지금 꺼내놓고 싶은 이야기가 있나요?',
  '오늘 말하지 못한 이야기가 있나요?',
  '누군가에게 하고 싶었던 말이 있나요?',
  '떠오르는 이야기부터 적어볼까요?',
  '지금 하고 싶은 말이 있나요?',
  '마음속에서 맴도는 말이 있나요?',
  '오늘의 이야기를 내 말로 남긴다면?',
];

const acceptancePromptPool = [
  '지금 내 마음에 머물러 있는 것은?',
  '오늘 말로 꺼내지 못한 마음이 있다면?',
  '지금 느끼는 마음을 내 말로 적는다면?',
  '오늘 조금 버거웠던 것이 있다면?',
  '어떤 마음인지 모르겠다면, 지금 떠오르는 말은?',
  '오늘의 나에게 해주고 싶은 말이 있다면?',
  '지금은 그대로 두고 싶은 마음이 있다면?',
];

const intentionPromptPool = [
  '지금 나에게 필요한 것이 있다면?',
  '내일 조금 덜어내고 싶은 것이 있다면?',
  '잠깐 쉴 수 있다면 어떻게 쉬고 싶나요?',
  '도움을 받고 싶은 일이 있다면?',
  '나를 편안하게 해주는 것이 있다면?',
  '내일의 나에게 남겨두고 싶은 말은?',
  '지금 결정하지 않아도 되는 것이 있다면?',
];

/// Custom questions should not receive unrelated category-specific examples.
bool isBuiltInPrompt(int index, String question) => switch (index) {
  0 => gratitudePromptPool.contains(question),
  1 => acceptancePromptPool.contains(question),
  2 => intentionPromptPool.contains(question),
  _ => false,
};

const promptCategories = PromptCategory.values;
