import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khata_management/database/app_database.dart';

void main() {
  test('deleteEntry closes the serial number gap for later rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db
          .into(db.companies)
          .insert(
            CompaniesCompanion(
              id: const Value(1),
              companyName: const Value('Test Company'),
              updatedAt: Value(DateTime(2026)),
            ),
          );
      await db
          .into(db.companies)
          .insert(
            CompaniesCompanion(
              id: const Value(2),
              companyName: const Value('Other Company'),
              updatedAt: Value(DateTime(2026)),
            ),
          );

      final ids = <int>[];
      for (final serial in [20, 21, 22, 23, 24]) {
        ids.add(
          await db.ledgerDao.insertEntry(
            LedgerEntriesCompanion.insert(companyId: 1, serialNumber: serial),
          ),
        );
      }
      await db.ledgerDao.insertEntry(
        LedgerEntriesCompanion.insert(companyId: 2, serialNumber: 21),
      );

      await db.ledgerDao.deleteEntry(ids[1]);

      final companyOne = await db.ledgerDao.entriesForCompanyOnce(1);
      expect(
        companyOne.map((entry) => entry.serialNumber),
        orderedEquals([20, 21, 22, 23]),
      );

      final companyTwo = await db.ledgerDao.entriesForCompanyOnce(2);
      expect(
        companyTwo.map((entry) => entry.serialNumber),
        orderedEquals([21]),
      );
    } finally {
      await db.close();
    }
  });
}
