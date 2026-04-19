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
  static const double headerFontSize = 20;
  static const double tableHeaderFontSize = 13;
  static const double tableBodyFontSize = 14;
  static const double summaryFontSize = 15;
  // Single source of truth for Urdu sizing (UI + PDF sync).
  static const double partyNameFontSize = 26;
  static const double partyHeaderFontSize = 26;
  static const double pendingHeaderFontSize = 26;
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
  static const double rowHeight = 52;
  static const double summaryFooterHeight = 60;
  static const double sheetPadding = 32; // top+bottom padding inside paper

  // Column widths (shared between UI and PDF).
  static const double colSerialFixed = 44;
  static const double colActionFixed = 44;
  static const int colPartyFlex = 3;
  static const int colValueFlex = 2;

  /// UI logical pixels are 96-DPI; PDF points are 72-DPI.
  static const double ptPerPx = 72.0 / 96.0; // 0.75

  /// How many rows fit on a full page (no summary).
  static int fullPageRows() {
    final avail =
        a4Height - sheetPadding - pageHeaderHeight - tableHeaderHeight;
    return (avail / rowHeight).floor().clamp(1, 999);
  }

  /// How many rows fit on the last page (with summary footer).
  static int lastPageRows() {
    final avail =
        a4Height -
        sheetPadding -
        pageHeaderHeight -
        tableHeaderHeight -
        summaryFooterHeight;
    return (avail / rowHeight).floor().clamp(1, 999);
  }

  /// Paginate entries into full pages and one last page.
  static List<List<T>> paginate<T>(List<T> entries) {
    if (entries.isEmpty) return [[]];
    final fullMax = fullPageRows();
    final lastMax = lastPageRows();
    final pages = <List<T>>[];
    var i = 0;
    while (i < entries.length) {
      final remaining = entries.length - i;
      if (remaining <= lastMax) {
        pages.add(entries.sublist(i));
        break;
      }
      if (remaining > fullMax) {
        pages.add(entries.sublist(i, i + fullMax));
        i += fullMax;
        continue;
      }
      final take = remaining - lastMax;
      pages.add(entries.sublist(i, i + take));
      i += take;
    }
    return pages;
  }

  // ── PDF pagination (same logic, but everything already in points) ──

  static int pdfFullPageRows() {
    final avail =
        (a4Height * ptPerPx) -
        (sheetPadding * ptPerPx) -
        (pageHeaderHeight * ptPerPx) -
        (tableHeaderHeight * ptPerPx);
    return (avail / (rowHeight * ptPerPx)).floor().clamp(1, 999);
  }

  static int pdfLastPageRows() {
    final avail =
        (a4Height * ptPerPx) -
        (sheetPadding * ptPerPx) -
        (pageHeaderHeight * ptPerPx) -
        (tableHeaderHeight * ptPerPx) -
        (summaryFooterHeight * ptPerPx);
    return (avail / (rowHeight * ptPerPx)).floor().clamp(1, 999);
  }

  static List<List<T>> paginatePdf<T>(List<T> entries) {
    if (entries.isEmpty) return [[]];
    final fullMax = pdfFullPageRows();
    final lastMax = pdfLastPageRows();
    final pages = <List<T>>[];
    var i = 0;
    while (i < entries.length) {
      final remaining = entries.length - i;
      if (remaining <= lastMax) {
        pages.add(entries.sublist(i));
        break;
      }
      if (remaining > fullMax) {
        pages.add(entries.sublist(i, i + fullMax));
        i += fullMax;
        continue;
      }
      final take = remaining - lastMax;
      pages.add(entries.sublist(i, i + take));
      i += take;
    }
    return pages;
  }
}
