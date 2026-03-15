import 'package:drift/drift.dart';

class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();
  TextColumn get prompt1 => text().withDefault(const Constant(''))();
  TextColumn get answer1 => text().withDefault(const Constant(''))();
  TextColumn get prompt2 => text().withDefault(const Constant(''))();
  TextColumn get answer2 => text().withDefault(const Constant(''))();
  TextColumn get prompt3 => text().withDefault(const Constant(''))();
  TextColumn get answer3 => text().withDefault(const Constant(''))();
  IntColumn get emotion => integer()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
