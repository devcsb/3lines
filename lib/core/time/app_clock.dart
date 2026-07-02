import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/date_utils.dart' as du;

final appClockProvider = Provider<AppClock>((ref) => const AppClock());

class AppClock {
  const AppClock();

  DateTime now() => DateTime.now();

  String todayString() => du.dateToString(now());

  DateTime daysAgo(int days) => now().subtract(Duration(days: days));

  DateTime sameDateMonthsAgo(int months) => du.subtractMonths(now(), months);

  DateTime nextMidnight() {
    final current = now();
    return DateTime(current.year, current.month, current.day + 1);
  }
}
