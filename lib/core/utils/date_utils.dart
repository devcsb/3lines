import 'package:intl/intl.dart';

String getGreeting({int streak = 0}) {
  final now = DateTime.now();
  final hour = now.hour;
  final weekday = now.weekday;

  // Streak-aware greetings for milestones
  if (streak == 6) return '내일이면 7일째예요';
  if (streak == 29) return '내일이면 한 달이에요';
  if (streak >= 50 && streak % 10 == 0) return '$streak일, 대단해요';

  // Day-of-week specials
  if (weekday == DateTime.monday && hour < 12) return '새로운 한 주가 시작됐어요';
  if (weekday == DateTime.friday && hour >= 18) return '한 주 수고했어요';
  if (weekday == DateTime.sunday) return '여유로운 하루 보내세요';

  // Time-based defaults
  if (hour >= 5 && hour < 9) return '고요한 아침이에요';
  if (hour >= 9 && hour < 12) return '좋은 아침이에요';
  if (hour >= 12 && hour < 14) return '오늘 하루도 잘 보내고 있나요';
  if (hour >= 14 && hour < 18) return '좋은 오후예요';
  if (hour >= 18 && hour < 22) return '오늘 하루 어떠셨나요';
  return '늦은 밤, 오늘을 돌아봐요';
}

String getTodayString() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// Days elapsed since a fixed epoch (2024-01-01). Used for deterministic
/// daily prompt rotation without storing any state.
int daysSinceEpoch([DateTime? now]) {
  // Use the user's local calendar date, then convert both dates to UTC
  // midnights. Calculating from the instant would shift rotation to 09:00 in
  // Asia/Seoul (and to another hour in other non-UTC time zones).
  final localDate = now ?? DateTime.now();
  final today = DateTime.utc(localDate.year, localDate.month, localDate.day);
  final epoch = DateTime.utc(2024, 1, 1);
  return today.difference(epoch).inDays;
}

/// Subtracts [months] from [from], clamping the day to the last day of
/// the resulting month. This prevents overflow (e.g. March 31 - 1 month
/// returning March 3 instead of Feb 28).
DateTime subtractMonths(DateTime from, int months) {
  var year = from.year;
  var month = from.month - months;
  while (month <= 0) {
    month += 12;
    year--;
  }
  final maxDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, from.day.clamp(1, maxDay));
}

String formatKoreanDate(DateTime date) =>
    DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(date);

String formatDateString(String dateStr) {
  final date = DateTime.tryParse(dateStr);
  if (date == null) return dateStr;
  return formatKoreanDate(date);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateToString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime stringToDate(String dateStr) => DateTime.parse(dateStr);

String getDayOfWeekLabel(int weekday) {
  const labels = ['', '월', '화', '수', '목', '금', '토', '일'];
  if (weekday < 1 || weekday > 7) return '';
  return labels[weekday];
}

String formatWithTimezone(DateTime dt) {
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  final base = dt.toIso8601String().split('.').first;
  return '$base$sign$hours:$minutes';
}
