import 'package:drift/drift.dart';

class Companies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get companyName => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
