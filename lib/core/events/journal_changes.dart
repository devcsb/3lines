import 'package:flutter_riverpod/flutter_riverpod.dart';

final journalChangesProvider = NotifierProvider<JournalChanges, int>(
  JournalChanges.new,
);

class JournalChanges extends Notifier<int> {
  @override
  int build() => 0;

  void markChanged() {
    state++;
  }
}
