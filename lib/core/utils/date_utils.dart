import 'package:intl/intl.dart';

String getGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return '좋은 아침이에요';
  if (hour >= 12 && hour < 18) return '좋은 오후예요';
  return '좋은 저녁이에요';
}

String getTodayString() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String formatKoreanDate(DateTime date) =>
    DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(date);

String formatDateString(String dateStr) {
  final date = DateTime.parse(dateStr);
  return formatKoreanDate(date);
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateToString(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime stringToDate(String dateStr) => DateTime.parse(dateStr);

String getDayOfWeekLabel(int weekday) {
  const labels = ['', '월', '화', '수', '목', '금', '토', '일'];
  return labels[weekday];
}
