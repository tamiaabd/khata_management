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

  Future<void> updateEntry(LedgerEntry entry) {
    return update(ledgerEntries).replace(entry);
  }

  Future<void> deleteEntry(int id) {
    return (delete(ledgerEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<List<LedgerEntry>> entriesForCompanyOnce(int companyId) {
    return (select(ledgerEntries)
          ..where((t) => t.companyId.equals(companyId))
          ..orderBy([(t) => OrderingTerm.asc(t.serialNumber)]))
        .get();
  }

  Future<int> deleteAllEntriesForCompany(int companyId) {
    return (delete(ledgerEntries)..where((t) => t.companyId.equals(companyId))).go();
  }
}
