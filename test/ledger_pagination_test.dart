import 'package:flutter_test/flutter_test.dart';
import 'package:khata_management/database/app_database.dart';
import 'package:khata_management/utils/constants.dart';
import 'package:khata_management/utils/ledger_pagination.dart';

void main() {
  test('normal pages use full capacity before the final summary page', () {
    final fullCapacity = LedgerLayout.fullSheetEntryCapacity();
    final lastCapacity = LedgerLayout.lastSheetEntryCapacity();

    expect(fullCapacity, greaterThan(lastCapacity));

    final pages = LedgerPagination.pagesWithBreaks(_entries(fullCapacity + 1));

    expect(pages.map((page) => page.length), [fullCapacity, 1]);
  });

  test(
    'manual page breaks reserve final summary space only in final block',
    () {
      final fullCapacity = LedgerLayout.fullSheetEntryCapacity();
      final entries = [
        ..._entries(fullCapacity + 1),
        _entry(id: fullCapacity + 2, startsNewPage: true),
      ];

      final pages = LedgerPagination.pagesWithBreaks(entries);

      expect(pages.map((page) => page.length), [fullCapacity, 1, 1]);
    },
  );

  test('pdf pagination follows the same final-summary rule', () {
    final fullCapacity =
        LedgerLayout.pdfFullPageRows() * LedgerLayout.ledgerColumnsPerSheet;
    final lastCapacity =
        LedgerLayout.pdfLastPageRows() * LedgerLayout.ledgerColumnsPerSheet;

    expect(fullCapacity, greaterThan(lastCapacity));

    final pages = LedgerPagination.pdfPagesWithBreaks(
      _entries(fullCapacity + 1),
    );

    expect(pages.map((page) => page.length), [fullCapacity, 1]);
  });
}

List<LedgerEntry> _entries(int count) {
  return List<LedgerEntry>.generate(count, (i) => _entry(id: i + 1));
}

LedgerEntry _entry({required int id, bool startsNewPage = false}) {
  return LedgerEntry(
    id: id,
    companyId: 1,
    serialNumber: id,
    partyName: 'Party $id',
    value1: id.toDouble(),
    value2: id.toDouble(),
    value3: id.toDouble(),
    pendingPayment: id.toDouble(),
    startsNewPage: startsNewPage,
    pageCategory: 'Category',
    createdAt: DateTime(2026),
  );
}
