class PromptCategory {
  static const gratitude = 'gratitude';
  static const acceptance = 'acceptance';
  static const intention = 'intention';
}

const defaultPrompts = [
  (
    category: PromptCategory.gratitude,
    question: '오늘 감사한 작은 것 하나는?',
  ),
  (
    category: PromptCategory.acceptance,
    question: '오늘 불편했던 감정을, 있는 그대로 인정한다면?',
  ),
  (
    category: PromptCategory.intention,
    question: '내일 내가 되고 싶은 모습은?',
  ),
];

const defaultPromptQuestions = [
  '오늘 감사한 작은 것 하나는?',
  '오늘 불편했던 감정을, 있는 그대로 인정한다면?',
  '내일 내가 되고 싶은 모습은?',
];

const promptCategories = [
  PromptCategory.gratitude,
  PromptCategory.acceptance,
  PromptCategory.intention,
];

const promptCategoryLabels = {
  PromptCategory.gratitude: '감사',
  PromptCategory.acceptance: '수용',
  PromptCategory.intention: '의도',
};
