import '../database/app_database.dart';
import 'constants.dart';

/// Ledger rows with [LedgerEntry.startsNewPage] begin a new sheet after the
/// previous row, without padding the prior page.
abstract final class LedgerPagination {
  static List<List<LedgerEntry>> pagesWithBreaks(List<LedgerEntry> entries) {
    if (entries.isEmpty) return [[]];
    final blocks = _blocks(entries);
    final pages = <List<LedgerEntry>>[];
    for (final b in blocks) {
      pages.addAll(LedgerLayout.paginate(b));
    }
    return pages;
  }

  static List<List<LedgerEntry>> pdfPagesWithBreaks(List<LedgerEntry> entries) {
    if (entries.isEmpty) return [[]];
    final blocks = _blocks(entries);
    final pages = <List<LedgerEntry>>[];
    for (final b in blocks) {
      pages.addAll(LedgerLayout.paginatePdf(b));
    }
    return pages;
  }

  static List<List<LedgerEntry>> _blocks(List<LedgerEntry> entries) {
    final blocks = <List<LedgerEntry>>[];
    var cur = <LedgerEntry>[];
    for (final e in entries) {
      if (e.startsNewPage && cur.isNotEmpty) {
        blocks.add(List<LedgerEntry>.from(cur));
        cur = [];
      } else if (e.startsNewPage && cur.isEmpty && blocks.isEmpty) {
        // First row is a page break on an empty ledger → show a blank first sheet.
        blocks.add(<LedgerEntry>[]);
      }
      cur.add(e);
    }
    blocks.add(cur);
    return blocks;
  }
}
