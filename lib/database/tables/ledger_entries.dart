import 'package:drift/drift.dart';

import 'companies.dart';

@DataClassName('LedgerEntry')
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get companyId =>
      integer().references(Companies, #id, onDelete: KeyAction.cascade)();
  IntColumn get serialNumber => integer()();
  TextColumn get partyName => text().withDefault(const Constant(''))();
  RealColumn get value1 => real().withDefault(const Constant(0))();
  RealColumn get value2 => real().withDefault(const Constant(0))();
  RealColumn get value3 => real().withDefault(const Constant(0))();
  RealColumn get pendingPayment => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
