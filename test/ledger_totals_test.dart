import 'package:flutter_test/flutter_test.dart';
import 'package:khata_management/database/app_database.dart';
import 'package:khata_management/utils/ledger_totals.dart';

void main() {
  test('sums only numeric ledger columns', () {
    final entries = [
      _entry(id: 1, pendingPayment: 10, value1: 20, value2: 30.5, value3: -5),
      _entry(
        id: 2,
        partyName: 'Non numeric text is ignored',
        pendingPayment: 2.5,
        value1: 0,
        value2: 9.5,
        value3: 5,
      ),
    ];

    expect(
      LedgerTotals.fromEntries(entries),
      const LedgerTotals(pending: 12.5, value1: 20, value2: 40, value3: 0),
    );
  });

  test('empty entry list totals as zero', () {
    expect(LedgerTotals.fromEntries([]), LedgerTotals.zero);
  });

  test('grand total adds total and godam values per column', () {
    const total = LedgerTotals(pending: 10, value1: 20, value2: 30, value3: 40);
    const godam = LedgerTotals(pending: 1, value1: 2, value2: 3, value3: 4);

    expect(
      total + godam,
      const LedgerTotals(pending: 11, value1: 22, value2: 33, value3: 44),
    );
  });
}

LedgerEntry _entry({
  required int id,
  String partyName = '',
  double pendingPayment = 0,
  double value1 = 0,
  double value2 = 0,
  double value3 = 0,
}) {
  return LedgerEntry(
    id: id,
    companyId: 1,
    serialNumber: id,
    partyName: partyName,
    value1: value1,
    value2: value2,
    value3: value3,
    pendingPayment: pendingPayment,
    startsNewPage: false,
    pageCategory: '',
    createdAt: DateTime(2026),
  );
}
