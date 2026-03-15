const koreanStopWords = {
  // 조사
  '은', '는', '이', '가', '을', '를', '의', '에', '에서',
  '로', '으로', '와', '과', '도', '만', '까지', '부터',
  // 대명사
  '나', '너', '그', '저', '이것', '그것', '저것',
  // 동사/형용사 어간
  '하다', '있다', '되다', '없다', '않다', '했다', '했는데',
  // 접속사/부사
  '그리고', '하지만', '그래서', '또한', '때문에',
  '것', '수', '때', '등', '중', '더', '좀', '잘', '못',
  '정말', '진짜', '매우', '아주', '너무',
  // 시간 관련
  '오늘', '내일', '어제',
};

Map<String, int> extractKeywords(List<String> texts, {int limit = 10}) {
  final frequency = <String, int>{};

  for (final text in texts) {
    if (text.trim().isEmpty) continue;

    final words = text
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .where((w) => !koreanStopWords.contains(w));

    for (final word in words) {
      frequency[word] = (frequency[word] ?? 0) + 1;
    }
  }

  final sorted = frequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map.fromEntries(sorted.take(limit));
}
