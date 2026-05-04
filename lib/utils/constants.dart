import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color background = Color(0xFFF5FAFF);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF5C7EA6);
  static const Color gridLine = Color(0xFFD6EAFB);
  static const Color gridLineLight = Color(0xFFEAF4FF);
  static const Color delete = Color(0xFFDC2626);
}

abstract final class AppUpdateConfig {
  /// CI passes `--dart-define=SUPABASE_URL=...`. Default is the production
  /// project URL so local `flutter run` / builds still fetch `latest.json`.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ftlaqzgfcxlqnnvojooi.supabase.co',
  );

  /// Storage bucket: tagged builds, `latest.json`, and in-app update files
  /// (`version.json`, `latest.msix`, `latest.apk`) at the bucket root.
  static const String supabaseBucket = 'builds';

  /// Same bucket as [supabaseBucket]; update metadata lives next to versioned folders.
  static const String supabaseUpdatesBucket = supabaseBucket;

  static const bool forceUpdate = false;

  /// `{SUPABASE_URL}/storage/v1/object/public/builds/version.json`
  static String get versionManifestUrl =>
      '$supabaseUrl/storage/v1/object/public/$supabaseUpdatesBucket/version.json';
}

abstract final class LedgerLayout {
  static const double headerFontSize = 22;
  static const double tableHeaderFontSize = 13;
  static const double tableBodyFontSize = 14;
  static const double summaryFontSize = 16;
  // Single source of truth for Urdu sizing (UI + PDF sync).
  static const double partyNameFontSize = 20;
  static const double partyHeaderFontSize = 24;
  static const double pendingHeaderFontSize = 16;
  static const String partyHeaderText = 'دوکاندار';
  static const String pendingHeaderText = 'بقایا رقم';

  // A4 dimensions in logical pixels (matches 96-DPI A4). Used as the fixed
  // layout width for the ledger UI and PDF; on-screen scaling preserves this aspect.
  static const double a4Width = 794;
  static const double a4Height = 1123;

  /// Horizontal padding for shell chrome from view width (narrower on phones).
  static double viewportHorizontalPadding(double width) {
    if (width < 360) return 8;
    if (width < 600) return 12;
    return 16;
  }

  // Heights used for both UI preview and PDF pagination.
  static const double pageHeaderHeight = 36;
  static const double tableHeaderHeight = 44;
  static const double rowHeight = 50;
  static const double summaryRowHeight = 48;
  static const double columnTotalsRowHeight = summaryRowHeight;
  static const double pageSummaryTopGap = 8;
  static const double finalSummaryGap = 8;
  static const double pageSummaryFooterHeight = summaryRowHeight;
  static const double finalSummaryFooterHeight =
      (summaryRowHeight * 4) + finalSummaryGap;
  static const double summaryFooterHeight = finalSummaryFooterHeight;
  static const double sheetPadding = 32; // top+bottom padding inside paper

  // Column flex (shared between UI and PDF). PDF [pw.FlexColumnWidth] uses the
  // same ints as the Flutter [Expanded] row — tune ratios here for both.
  static const double colActionFixed = 40;
  static const int colPartyFlex = 12;
  static const int colPendingFlex = 8;
  static const int colValueFlex = 4;

  /// Wide enough for two-digit row numbers in PDF/UI without wrapping.
  static const int colSerialFlex = 4;

  /// Side-by-side ledger tables per sheet (UI + PDF). Each vertical band holds
  /// one row per column, so entry capacity is this times [fullPageRows] slots.
  static const int ledgerColumnsPerSheet = 2;

  /// UI logical pixels are 96-DPI; PDF points are 72-DPI.
  static const double ptPerPx = 72.0 / 96.0; // 0.75

  /// Vertical row bands on one sheet (one column of the register).
  /// How many rows fit on a normal page (page total only, no final summary).
  static int fullPageRows() {
    final avail =
        a4Height -
        sheetPadding -
        pageHeaderHeight -
        tableHeaderHeight -
        columnTotalsRowHeight -
        pageSummaryTopGap -
        pageSummaryFooterHeight;
    return (avail / rowHeight).floor().clamp(1, 999);
  }

  /// How many rows fit on the last page (with summary footer).
  static int lastPageRows() {
    final avail =
        a4Height -
        sheetPadding -
        pageHeaderHeight -
        tableHeaderHeight -
        columnTotalsRowHeight -
        pageSummaryTopGap -
        summaryFooterHeight;
    return (avail / rowHeight).floor().clamp(1, 999);
  }

  /// Entries that fit on one full sheet (all columns).
  static int fullSheetEntryCapacity() => fullPageRows() * ledgerColumnsPerSheet;

  /// Entries that fit on the last sheet (includes room for summary footer).
  static int lastSheetEntryCapacity() => lastPageRows() * ledgerColumnsPerSheet;

  /// Paginate pages that never show the final summary footer.
  static List<List<T>> paginateNonFinal<T>(List<T> entries) {
    return _paginateFixed(entries, fullSheetEntryCapacity());
  }

  /// Left column gets the first `ceil(n/2)` entries (serial order), then the right.
  static (List<T> left, List<T> right) splitSheetColumns<T>(
    List<T> pageEntries,
  ) {
    if (pageEntries.isEmpty) return (<T>[], <T>[]);
    final mid = (pageEntries.length + 1) ~/ 2;
    return (pageEntries.sublist(0, mid), pageEntries.sublist(mid));
  }

  /// Paginate entries so normal pages use their full row capacity and only the
  /// final page reserves room for TOTAL/GODAM/GRAND TOTAL.
  static List<List<T>> paginate<T>(List<T> entries) {
    return _paginateWithFinalFooter(
      entries,
      fullSheetEntryCapacity(),
      lastSheetEntryCapacity(),
    );
  }

  // ── PDF pagination (same logic, but everything already in points) ──

  static int pdfFullPageRows() {
    final avail =
        (a4Height * ptPerPx) -
        (sheetPadding * ptPerPx) -
        (pageHeaderHeight * ptPerPx) -
        (tableHeaderHeight * ptPerPx) -
        (columnTotalsRowHeight * ptPerPx) -
        (pageSummaryTopGap * ptPerPx) -
        (pageSummaryFooterHeight * ptPerPx);
    return (avail / (rowHeight * ptPerPx)).floor().clamp(1, 999);
  }

  static int pdfLastPageRows() {
    final avail =
        (a4Height * ptPerPx) -
        (sheetPadding * ptPerPx) -
        (pageHeaderHeight * ptPerPx) -
        (tableHeaderHeight * ptPerPx) -
        (columnTotalsRowHeight * ptPerPx) -
        (pageSummaryTopGap * ptPerPx) -
        (summaryFooterHeight * ptPerPx);
    return (avail / (rowHeight * ptPerPx)).floor().clamp(1, 999);
  }

  static List<List<T>> paginatePdfNonFinal<T>(List<T> entries) {
    return _paginateFixed(entries, pdfFullPageRows() * ledgerColumnsPerSheet);
  }

  static List<List<T>> paginatePdf<T>(List<T> entries) {
    return _paginateWithFinalFooter(
      entries,
      pdfFullPageRows() * ledgerColumnsPerSheet,
      pdfLastPageRows() * ledgerColumnsPerSheet,
    );
  }

  static List<List<T>> _paginateFixed<T>(List<T> entries, int pageMax) {
    if (entries.isEmpty) return [[]];
    final safePageMax = pageMax < 1 ? 1 : pageMax;
    final pages = <List<T>>[];
    var i = 0;
    while (i < entries.length) {
      final end = (i + safePageMax).clamp(0, entries.length);
      pages.add(entries.sublist(i, end));
      i = end;
    }
    return pages;
  }

  static List<List<T>> _paginateWithFinalFooter<T>(
    List<T> entries,
    int normalPageMax,
    int finalPageMax,
  ) {
    if (entries.isEmpty) return [[]];
    final safeNormalMax = normalPageMax < 1 ? 1 : normalPageMax;
    final safeFinalMax = finalPageMax < 1 ? 1 : finalPageMax;
    if (safeNormalMax <= safeFinalMax) {
      return _paginateFixed(entries, safeNormalMax);
    }

    final pages = <List<T>>[];
    var start = 0;
    while (entries.length - start > safeFinalMax) {
      final remaining = entries.length - start;
      final take = remaining <= safeNormalMax ? safeFinalMax : safeNormalMax;
      final end = start + take;
      pages.add(entries.sublist(start, end));
      start = end;
    }
    pages.add(entries.sublist(start));
    return pages;
  }
}
