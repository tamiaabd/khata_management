import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

import 'package:khata_management/database/app_database.dart';
import 'package:khata_management/services/pdf_service.dart';
import 'package:khata_management/utils/constants.dart';
import 'package:khata_management/utils/ledger_totals.dart';

void main() {
  testWidgets('builds pdf with page total and final summary rows', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => PdfService.buildPdf(
        format: PdfPageFormat.a4,
        companyName: 'Test Company',
        entries: [
          LedgerEntry(
            id: 1,
            companyId: 1,
            serialNumber: 1,
            partyName: 'Party A',
            value1: 20,
            value2: 30,
            value3: 40,
            pendingPayment: 10,
            startsNewPage: false,
            pageCategory: 'Category',
            createdAt: DateTime(2026),
          ),
        ],
        generatedAt: DateTime(2026, 5, 4),
        urduFont: 'JameelNooriNastaleeq',
        englishFont: 'Poppins',
        godamTotals: const LedgerTotals(
          pending: 1,
          value1: 2,
          value2: 3,
          value3: 4,
        ),
      ),
    );

    expect(bytes, isNotEmpty);
  });

  testWidgets('full export builds all ledger pages', (tester) async {
    final bytes = await tester.runAsync(
      () => _buildTestPdf(_entries(LedgerLayout.lastSheetEntryCapacity() + 1)),
    );

    expect(bytes, isNotNull);
    expect(_pdfPageCount(bytes!), 2);
  });

  testWidgets('single page export builds only the selected ledger page', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => _buildTestPdf(
        _entries(LedgerLayout.lastSheetEntryCapacity() + 1),
        onlyPageIndex: 1,
      ),
    );

    expect(bytes, isNotNull);
    expect(_pdfPageCount(bytes!), 1);
  });
}

Future<Uint8List> _buildTestPdf(
  List<LedgerEntry> entries, {
  int? onlyPageIndex,
}) {
  return PdfService.buildPdf(
    format: PdfPageFormat.a4,
    companyName: 'Test Company',
    entries: entries,
    generatedAt: DateTime(2026, 5, 4),
    urduFont: 'JameelNooriNastaleeq',
    englishFont: 'Poppins',
    onlyPageIndex: onlyPageIndex,
    godamTotals: const LedgerTotals(
      pending: 1,
      value1: 2,
      value2: 3,
      value3: 4,
    ),
  );
}

List<LedgerEntry> _entries(int count) {
  return List<LedgerEntry>.generate(
    count,
    (i) => LedgerEntry(
      id: i + 1,
      companyId: 1,
      serialNumber: i + 1,
      partyName: 'Party ${i + 1}',
      value1: i + 1,
      value2: i + 2,
      value3: i + 3,
      pendingPayment: i + 4,
      startsNewPage: false,
      pageCategory: 'Category',
      createdAt: DateTime(2026),
    ),
  );
}

int _pdfPageCount(Uint8List bytes) {
  final body = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page\b').allMatches(body).length;
}
