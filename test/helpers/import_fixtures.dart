import 'package:three_lines/core/time/app_clock.dart';

Map<String, Object?> importRecord(
  String date, {
  Object emotion = 3,
  String answer = '기록',
}) => {
  'date': date,
  'emotion': emotion,
  'prompts': [
    {'question': '질문1', 'answer': answer},
    {'question': '질문2', 'answer': ''},
    {'question': '질문3', 'answer': ''},
  ],
};

class MutableImportClock extends AppClock {
  MutableImportClock(this.value);

  DateTime value;
  int reads = 0;

  @override
  DateTime now() {
    reads++;
    return value;
  }
}
