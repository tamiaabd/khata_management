part of '../app_database.dart';

@DriftAccessor(tables: [LedgerEntries])
class LedgerDao extends DatabaseAccessor<AppDatabase> with _$LedgerDaoMixin {
  LedgerDao(super.db);

  Stream<List<LedgerEntry>> watchEntriesForCompany(int companyId) {
    return (select(ledgerEntries)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.serialNumber)]))
        .watch();
  }

  Future<int> nextSerialNumber(int companyId) async {
    final q = selectOnly(ledgerEntries)
      ..addColumns([ledgerEntries.serialNumber.max()])
      ..where(ledgerEntries.companyId.equals(companyId));
    final row = await q.getSingleOrNull();
    final maxSerial = row?.read(ledgerEntries.serialNumber.max()) ?? 0;
    return maxSerial + 1;
  }

  Future<int> insertEntry(LedgerEntriesCompanion companion) {
    return into(ledgerEntries).insert(companion);
  }

  Future<int> insertEntryAfterSerial({
    required int companyId,
    required int afterSerial,
  }) {
    return transaction(() async {
      final insertSerial = afterSerial + 1;
      await (update(ledgerEntries)..where(
            (t) =>
                t.companyId.equals(companyId) &
                t.serialNumber.isBiggerOrEqualValue(insertSerial),
          ))
          .write(
            LedgerEntriesCompanion.custom(
              serialNumber: ledgerEntries.serialNumber + const Constant(1),
            ),
          );
      return into(ledgerEntries).insert(
        LedgerEntriesCompanion.insert(
          companyId: companyId,
          serialNumber: insertSerial,
        ),
      );
    });
  }

  Future<void> updateEntry(LedgerEntry entry) {
    return update(ledgerEntries).replace(entry);
  }

  Future<void> deleteEntry(int id) {
    return transaction(() async {
      final entry = await (select(
        ledgerEntries,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (entry == null) return;

      await (delete(ledgerEntries)..where((t) => t.id.equals(id))).go();
      await (update(ledgerEntries)..where(
            (t) =>
                t.companyId.equals(entry.companyId) &
                t.serialNumber.isBiggerThanValue(entry.serialNumber),
          ))
          .write(
            LedgerEntriesCompanion.custom(
              serialNumber: ledgerEntries.serialNumber - const Constant(1),
            ),
          );
    });
  }

  Future<List<LedgerEntry>> entriesForCompanyOnce(int companyId) {
    return (select(ledgerEntries)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.serialNumber)]))
        .get();
  }

  Future<int> deleteAllEntriesForCompany(int companyId) {
    return (delete(
      ledgerEntries,
    )..where((t) => t.companyId.equals(companyId))).go();
  }
}
