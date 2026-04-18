import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/app_database.dart';
import '../utils/formatters.dart';
import '../utils/constants.dart';
import '../utils/ledger_pagination.dart';

/// A4 portrait, multi-page ledger with totals on the last page.
/// Matches the on-screen home preview layout exactly.
///
/// Urdu/Arabic text is rendered as PNG images via Flutter's HarfBuzz engine
/// (which properly shapes Nastaleeq glyphs), then embedded in the PDF.
/// This bypasses the pdf package's Arabic shaper which crashes on Nastaleeq
/// fonts that lack Arabic Presentation Forms in their cmap table.
abstract final class PdfService {
  static final _dateFmt = DateFormat('dd-MM-yyyy');
  static const String _fixedUrduHeaderFont = 'BombayBlackUnicode';

  // 1 PDF point = 1/72 inch; A4 = 210×297 mm
  static const double _mm = 72.0 / 25.4;

  /// UI logical pixels are 96-DPI; PDF points are 72-DPI.
  static const double _ptPerPx = 72.0 / 96.0; // 0.75

  // Print-first grayscale: no chroma, strong B&W laser/inkjet contrast.
  static const _headerBand = PdfColor(0.88, 0.88, 0.88); // header / summary strip
  static const _borderStrong = PdfColor(0, 0, 0); // outer frame, emphasis
  static const _textPrimary = PdfColor(0, 0, 0); // body & headings
  static const _textSecondary = PdfColor(0.38, 0.38, 0.38); // page meta
  static const _gridLine = PdfColor(0.52, 0.52, 0.52); // rules & dividers

  /// Render scale for Urdu text images (higher = crisper text in PDF).
  static const double _renderScale = 3.0;

  /// Line-height multiplier for Nastaleeq rendering.
  /// 1.3 matches the clipping ratio used in the Flutter UI rows
  /// (28px content area / 22px fontSize ≈ 1.27).
  static const double _urduLineHeight = 1.3;

  static PdfPageFormat _a4Format() {
    return PdfPageFormat(210 * _mm, 297 * _mm, marginAll: 0);
  }

  static Future<({pw.Font regular, pw.Font bold})> _loadEnglishFonts(
    String englishFont,
  ) async {
    switch (englishFont) {
      case 'Roboto':
        return (
          regular: await PdfGoogleFonts.robotoRegular(),
          bold: await PdfGoogleFonts.robotoBold(),
        );
      case 'Open Sans':
        return (
          regular: await PdfGoogleFonts.openSansRegular(),
          bold: await PdfGoogleFonts.openSansBold(),
        );
      case 'Inter':
        return (
          regular: await PdfGoogleFonts.interRegular(),
          bold: await PdfGoogleFonts.interBold(),
        );
      case 'Lato':
        return (
          regular: await PdfGoogleFonts.latoRegular(),
          bold: await PdfGoogleFonts.latoBold(),
        );
      case 'Poppins':
      default:
        return (
          regular: pw.Font.ttf(
            await rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf'),
          ),
          bold: pw.Font.ttf(
            await rootBundle.load('assets/fonts/poppins/Poppins-Bold.ttf'),
          ),
        );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image-based Urdu text rendering
  // ─────────────────────────────────────────────────────────────────────────

  /// Renders [text] as a PNG image using Flutter's HarfBuzz text engine,
  /// producing properly shaped/joined Nastaleeq glyphs.
  ///
  /// Returns the image and its display dimensions in PDF points.
  static Future<({pw.MemoryImage img, double w, double h})> _renderUrduImage(
    String text, {
    required String fontFamily,
    required double pdfFontSize,
    required Color color,
    bool bold = false,
  }) async {
    final style = TextStyle(
      fontFamily: fontFamily,
      fontSize: pdfFontSize * _renderScale,
      height: _urduLineHeight,
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.rtl,
      maxLines: 1,
    )..layout();

    final w = tp.width.ceil().clamp(1, 4096);
    final h = tp.height.ceil().clamp(1, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    tp.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return (
      img: pw.MemoryImage(png!.buffer.asUint8List()),
      w: w / _renderScale,
      h: h / _renderScale,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// When [onlyPageIndex] is set (0-based), the PDF contains that single sheet
  /// from the same pagination as the full ledger; totals appear only when that
  /// sheet is the last page of the full document.
  static Future<Uint8List> buildPdf({
    required PdfPageFormat format,
    required String companyName,
    required List<LedgerEntry> entries,
    required DateTime generatedAt,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
    int? onlyPageIndex,
  }) async {
    if (onlyPageIndex != null) {
      final pages = LedgerPagination.pdfPagesWithBreaks(entries);
      if (onlyPageIndex < 0 || onlyPageIndex >= pages.length) {
        throw ArgumentError.value(
          onlyPageIndex,
          'onlyPageIndex',
          'must be >= 0 and < ${pages.length}',
        );
      }
    }
    const partyLabel = LedgerLayout.partyHeaderText;
    const pendingLabel = LedgerLayout.pendingHeaderText;
    final latin = await _loadEnglishFonts(englishFont);

    final double partyNameSize = LedgerLayout.partyNameFontSize * _ptPerPx;
    final double partyHeaderSize = LedgerLayout.partyHeaderFontSize * _ptPerPx;
    final double pendingHeaderSize =
        LedgerLayout.pendingHeaderFontSize * _ptPerPx;
    const double companySize = LedgerLayout.headerFontSize * _ptPerPx; // 15 pt

    // Pre-render all Urdu strings as images using Flutter's HarfBuzz engine.
    // This produces properly shaped/joined Nastaleeq text that the pdf
    // package cannot render natively.
    final Map<String, ({pw.MemoryImage img, double w, double h})> urduImgs = {};

    final headerTitles = <String>{};
    for (final page in LedgerPagination.pdfPagesWithBreaks(entries)) {
      headerTitles.add(_pdfSheetHeaderTitle(page));
    }
    for (final t in headerTitles) {
      if (_isUrdu(t)) {
        urduImgs[_hdrImgKey(t)] = await _renderUrduImage(
          t,
          fontFamily: urduFont,
          pdfFontSize: companySize,
          color: Colors.black,
          bold: true,
        );
      }
    }

    if (_isUrdu(partyLabel)) {
      urduImgs['partyLabel'] = await _renderUrduImage(
        partyLabel,
        fontFamily: _fixedUrduHeaderFont,
        pdfFontSize: partyHeaderSize,
        color: Colors.black,
        bold: true,
      );
    }
    if (_isUrdu(pendingLabel)) {
      urduImgs['pendingLabel'] = await _renderUrduImage(
        pendingLabel,
        fontFamily: _fixedUrduHeaderFont,
        pdfFontSize: pendingHeaderSize,
        color: Colors.black,
        bold: true,
      );
    }

    // Render unique Urdu party names.
    final seen = <String>{};
    for (final e in entries) {
      if (e.partyName.isNotEmpty &&
          _isUrdu(e.partyName) &&
          seen.add(e.partyName)) {
        urduImgs['p:${e.partyName}'] = await _renderUrduImage(
          e.partyName,
          fontFamily: urduFont,
          pdfFontSize: partyNameSize,
          color: Colors.black,
        );
      }
    }

    final doc = _buildDocument(
      latin: latin,
      format: format,
      entries: entries,
      generatedAt: generatedAt,
      value1Label: value1Label,
      value2Label: value2Label,
      value3Label: value3Label,
      urduImgs: urduImgs,
      partyNameSize: partyNameSize,
      partyHeaderSize: partyHeaderSize,
      pendingHeaderSize: pendingHeaderSize,
      onlyPageIndex: onlyPageIndex,
    );

    return Uint8List.fromList(await doc.save());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Document builder
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Document _buildDocument({
    required ({pw.Font regular, pw.Font bold}) latin,
    required PdfPageFormat format,
    required List<LedgerEntry> entries,
    required DateTime generatedAt,
    required String value1Label,
    required String value2Label,
    required String value3Label,
    required Map<String, ({pw.MemoryImage img, double w, double h})> urduImgs,
    required double partyNameSize,
    required double partyHeaderSize,
    required double pendingHeaderSize,
    int? onlyPageIndex,
  }) {
    const partyLabel = LedgerLayout.partyHeaderText;
    const pendingLabel = LedgerLayout.pendingHeaderText;
    const bodySize = LedgerLayout.tableBodyFontSize * _ptPerPx; // 10.5 pt
    const headerSize = LedgerLayout.tableHeaderFontSize * _ptPerPx; // 9.75 pt
    const companySize = LedgerLayout.headerFontSize * _ptPerPx; // 15 pt
    const summarySize = LedgerLayout.summaryFontSize * _ptPerPx; // 11.25 pt
    const double serialPt = LedgerLayout.colSerialFixed * _ptPerPx; // 33 pt
    const double pageHeaderPt = LedgerLayout.pageHeaderHeight * _ptPerPx;
    const double tableHeaderPt = LedgerLayout.tableHeaderHeight * _ptPerPx;
    const double rowPt = LedgerLayout.rowHeight * _ptPerPx;
    const double summaryFooterPt = LedgerLayout.summaryFooterHeight * _ptPerPx;
    const double sheetVPaddingPt = (LedgerLayout.sheetPadding * _ptPerPx) / 2.0;
    const double frameInsetPt = 10;
    const double frameHPaddingPt = 12;
    const double pendingHeaderRightInsetPt =
        LedgerLayout.colActionFixed * _ptPerPx;
    final double frameVPaddingPt = (sheetVPaddingPt - frameInsetPt) + 8;

    pw.Widget numText(String s, {pw.TextAlign align = pw.TextAlign.right}) {
      return pw.Text(
        s,
        textAlign: align,
        textDirection: pw.TextDirection.ltr,
        style: pw.TextStyle(
          font: latin.regular,
          fontSize: bodySize,
          color: _textPrimary,
        ),
      );
    }

    /// Returns a pw.Image for Urdu text (from pre-rendered images)
    /// or a pw.Text for Latin text.
    pw.Widget textOrImage(
      String text,
      String imgKey, {
      double fontSize = bodySize,
      pw.TextAlign align = pw.TextAlign.left,
      bool bold = false,
      PdfColor color = _textPrimary,
    }) {
      final rendered = urduImgs[imgKey];
      if (rendered != null) {
        return pw.Image(rendered.img, height: rendered.h, width: rendered.w);
      }
      return pw.Text(
        text,
        textAlign: align,
        textDirection: pw.TextDirection.ltr,
        style: pw.TextStyle(
          font: bold ? latin.bold : latin.regular,
          fontSize: fontSize,
          color: color,
        ),
      );
    }

    final fullPages = LedgerPagination.pdfPagesWithBreaks(entries);
    final totalPages = fullPages.length;
    final pageIndices = onlyPageIndex != null
        ? <int>[onlyPageIndex]
        : List<int>.generate(fullPages.length, (i) => i);

    double sumP = 0;
    double sumV1 = 0;
    double sumV2 = 0;
    double sumV3 = 0;
    for (final e in entries) {
      sumP += e.pendingPayment;
      sumV1 += e.value1;
      sumV2 += e.value2;
      sumV3 += e.value3;
    }

    final doc = pw.Document();

    for (final p in pageIndices) {
      final slice = fullPages[p];
      final isLast = p == fullPages.length - 1;
      final pageIndex = p + 1;
      final pageHeaderCenter = _pdfSheetHeaderTitle(slice);

      doc.addPage(
        pw.Page(
          pageFormat: format,
          build: (ctx) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(frameInsetPt),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: _borderStrong, width: 1),
                ),
                padding: pw.EdgeInsets.fromLTRB(
                  frameHPaddingPt,
                  frameVPaddingPt,
                  frameHPaddingPt,
                  frameVPaddingPt,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    // ── Page header: page# left | page category center | date right ──
                    pw.SizedBox(
                      height: pageHeaderPt,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          pw.Row(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Expanded(
                                child: pw.Text(
                                  'Page $pageIndex of $totalPages',
                                  style: pw.TextStyle(
                                    font: latin.regular,
                                    fontSize: 9,
                                    color: _textSecondary,
                                  ),
                                  textDirection: pw.TextDirection.ltr,
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Center(
                                  child: textOrImage(
                                    pageHeaderCenter,
                                    _hdrImgKey(pageHeaderCenter),
                                    fontSize: companySize,
                                    align: pw.TextAlign.center,
                                    bold: true,
                                  ),
                                ),
                              ),
                              pw.Expanded(
                                child: pw.Text(
                                  _dateFmt.format(generatedAt),
                                  textAlign: pw.TextAlign.right,
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(
                                    font: latin.regular,
                                    fontSize: 11,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8 * _ptPerPx),
                          pw.Divider(thickness: 0.5, color: _gridLine),
                          pw.SizedBox(height: 6 * _ptPerPx),
                        ],
                      ),
                    ),

                    // ── Table ──
                    pw.Table(
                      border: pw.TableBorder(
                        top: pw.BorderSide(color: _gridLine, width: 0.5),
                        horizontalInside: pw.BorderSide(
                          color: _gridLine,
                          width: 0.5,
                        ),
                      ),
                      columnWidths: {
                        0: pw.FlexColumnWidth(
                          LedgerLayout.colValueFlex.toDouble(),
                        ),
                        1: pw.FlexColumnWidth(
                          LedgerLayout.colValueFlex.toDouble(),
                        ),
                        2: pw.FlexColumnWidth(
                          LedgerLayout.colValueFlex.toDouble(),
                        ),
                        3: pw.FlexColumnWidth(
                          LedgerLayout.colValueFlex.toDouble(),
                        ),
                        4: pw.FlexColumnWidth(
                          LedgerLayout.colPartyFlex.toDouble(),
                        ),
                        5: pw.FixedColumnWidth(serialPt),
                      },
                      children: [
                        // Header row
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: _headerBand),
                          children: [
                            // Pending label: image if Urdu, text if Latin
                            _td(
                              pw.Align(
                                alignment: pw.Alignment.centerRight,
                                child: textOrImage(
                                  pendingLabel,
                                  'pendingLabel',
                                  fontSize: pendingHeaderSize,
                                  align: pw.TextAlign.right,
                                  bold: true,
                                  color: _textPrimary,
                                ),
                              ),
                              height: tableHeaderPt,
                            ),
                            _th(
                              value1Label,
                              latin.bold,
                              headerSize,
                              height: tableHeaderPt,
                            ),
                            _th(
                              value2Label,
                              latin.bold,
                              headerSize,
                              height: tableHeaderPt,
                            ),
                            _th(
                              value3Label,
                              latin.bold,
                              headerSize,
                              height: tableHeaderPt,
                            ),
                            // Party label: image if Urdu, text if Latin
                            _td(
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(
                                  right: pendingHeaderRightInsetPt,
                                ),
                                child: pw.Align(
                                  alignment: pw.Alignment.centerRight,
                                  child: textOrImage(
                                    partyLabel,
                                    'partyLabel',
                                    fontSize: partyHeaderSize,
                                    align: pw.TextAlign.right,
                                    bold: true,
                                    color: _textPrimary,
                                  ),
                                ),
                              ),
                              height: tableHeaderPt,
                            ),
                            _th(
                              '#',
                              latin.bold,
                              headerSize,
                              height: tableHeaderPt,
                              align: pw.TextAlign.center,
                            ),
                          ],
                        ),
                        // Data rows
                        ...slice.map(
                          (e) => pw.TableRow(
                            children: [
                              _td(
                                numText(formatDecimal(e.pendingPayment)),
                                height: rowPt,
                              ),
                              _td(
                                numText(formatDecimal(e.value1)),
                                height: rowPt,
                              ),
                              _td(
                                numText(formatDecimal(e.value2)),
                                height: rowPt,
                              ),
                              _td(
                                numText(formatDecimal(e.value3)),
                                height: rowPt,
                              ),
                              // Party name: image if Urdu, text if Latin
                              // Same right inset as party header so title and values align.
                              _td(
                                pw.Padding(
                                  padding: const pw.EdgeInsets.only(
                                    right: pendingHeaderRightInsetPt,
                                  ),
                                  child: pw.Align(
                                    alignment:
                                        _directionForMixedText(e.partyName) ==
                                            pw.TextDirection.rtl
                                        ? pw.Alignment.centerRight
                                        : pw.Alignment.centerLeft,
                                    child: textOrImage(
                                      e.partyName,
                                      'p:${e.partyName}',
                                      fontSize: partyNameSize,
                                    ),
                                  ),
                                ),
                                height: rowPt,
                              ),
                              _td(
                                numText(
                                  '${e.serialNumber}',
                                  align: pw.TextAlign.center,
                                ),
                                height: rowPt,
                              ),
                            ],
                          ),
                        ),
                        // Summary footer on last page
                        if (isLast)
                          pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: _headerBand,
                              border: pw.Border(
                                top: pw.BorderSide(
                                  color: _gridLine,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            children: [
                              _td(
                                pw.Text(
                                  formatDecimal(sumP),
                                  textAlign: pw.TextAlign.right,
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(
                                    font: latin.bold,
                                    fontSize: summarySize,
                                    color: _textPrimary,
                                  ),
                                ),
                                height: summaryFooterPt,
                              ),
                              _td(
                                pw.Text(
                                  formatDecimal(sumV1),
                                  textAlign: pw.TextAlign.right,
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(
                                    font: latin.bold,
                                    fontSize: summarySize,
                                    color: _textPrimary,
                                  ),
                                ),
                                height: summaryFooterPt,
                              ),
                              _td(
                                pw.Text(
                                  formatDecimal(sumV2),
                                  textAlign: pw.TextAlign.right,
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(
                                    font: latin.bold,
                                    fontSize: summarySize,
                                    color: _textPrimary,
                                  ),
                                ),
                                height: summaryFooterPt,
                              ),
                              _td(
                                pw.Text(
                                  formatDecimal(sumV3),
                                  textAlign: pw.TextAlign.right,
                                  textDirection: pw.TextDirection.ltr,
                                  style: pw.TextStyle(
                                    font: latin.bold,
                                    fontSize: summarySize,
                                    color: _textPrimary,
                                  ),
                                ),
                                height: summaryFooterPt,
                              ),
                              _td(
                                pw.Align(
                                  alignment: pw.Alignment.centerRight,
                                  child: pw.Padding(
                                    padding: const pw.EdgeInsets.only(
                                      right: pendingHeaderRightInsetPt,
                                    ),
                                    child: pw.Text(
                                      'TOTAL',
                                      textDirection: pw.TextDirection.ltr,
                                      style: pw.TextStyle(
                                        font: latin.bold,
                                        fontSize: summarySize,
                                        color: _borderStrong,
                                      ),
                                    ),
                                  ),
                                ),
                                height: summaryFooterPt,
                              ),
                              _td(pw.SizedBox(), height: summaryFooterPt),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return doc;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static pw.Widget _th(
    String t,
    pw.Font font,
    double fontSize, {
    required double height,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.SizedBox(
      height: height,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Align(
          alignment: align == pw.TextAlign.right
              ? pw.Alignment.centerRight
              : align == pw.TextAlign.left
              ? pw.Alignment.centerLeft
              : pw.Alignment.center,
          child: pw.Text(
            t,
            textAlign: align,
            textDirection: pw.TextDirection.ltr,
            style: pw.TextStyle(
              font: font,
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
              color: _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _td(pw.Widget child, {required double height}) {
    return pw.SizedBox(
      height: height,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Center(child: child),
      ),
    );
  }

  /// True when [text] contains Arabic/Urdu script codepoints.
  static String _pdfSheetHeaderTitle(List<LedgerEntry> slice) {
    if (slice.isEmpty) return 'Page Category';
    final raw = slice.first.pageCategory.trim();
    return raw.isEmpty ? 'Page Category' : raw;
  }

  static String _hdrImgKey(String title) => 'hdr:$title';

  static bool _isUrdu(String text) {
    for (final cp in text.runes) {
      if ((cp >= 0x0600 && cp <= 0x06FF) ||
          (cp >= 0x0750 && cp <= 0x077F) ||
          (cp >= 0x08A0 && cp <= 0x08FF) ||
          (cp >= 0xFB50 && cp <= 0xFDFF) ||
          (cp >= 0xFE70 && cp <= 0xFEFF)) {
        return true;
      }
    }
    return false;
  }

  static pw.TextDirection _directionForMixedText(String text) {
    if (text.isEmpty) return pw.TextDirection.ltr;
    return _isUrdu(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Print / Share
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> printLedger({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
  }) async {
    final entries = await database.ledgerDao.entriesForCompanyOnce(companyId);
    final format = _a4Format();
    final stem = _ledgerPdfStem(companyName);
    await Printing.layoutPdf(
      name: '$stem.pdf',
      onLayout: (f) => buildPdf(
        format: format,
        companyName: companyName,
        entries: entries,
        generatedAt: DateTime.now(),
        urduFont: urduFont,
        englishFont: englishFont,
        value1Label: value1Label,
        value2Label: value2Label,
        value3Label: value3Label,
      ),
    );
  }

  /// Print a single on-screen ledger page (same pagination as the full PDF).
  static Future<void> printLedgerPage({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
    required int pageIndex,
  }) async {
    final entries = await database.ledgerDao.entriesForCompanyOnce(companyId);
    final format = _a4Format();
    final stem = _ledgerPdfStem(companyName);
    await Printing.layoutPdf(
      name: '${stem}_page${pageIndex + 1}.pdf',
      onLayout: (f) => buildPdf(
        format: format,
        companyName: companyName,
        entries: entries,
        generatedAt: DateTime.now(),
        urduFont: urduFont,
        englishFont: englishFont,
        value1Label: value1Label,
        value2Label: value2Label,
        value3Label: value3Label,
        onlyPageIndex: pageIndex,
      ),
    );
  }

  static Future<void> sharePdf({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
  }) async {
    final entries = await database.ledgerDao.entriesForCompanyOnce(companyId);
    final format = _a4Format();
    final bytes = await buildPdf(
      format: format,
      companyName: companyName,
      entries: entries,
      generatedAt: DateTime.now(),
      urduFont: urduFont,
      englishFont: englishFont,
      value1Label: value1Label,
      value2Label: value2Label,
      value3Label: value3Label,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${companyName}_ledger.pdf'.replaceAll(
        RegExp(r'[^\w\-]+'),
        '_',
      ),
    );
  }

  static Future<File> savePdf({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
  }) async {
    final entries = await database.ledgerDao.entriesForCompanyOnce(companyId);
    final format = _a4Format();
    final bytes = await buildPdf(
      format: format,
      companyName: companyName,
      entries: entries,
      generatedAt: DateTime.now(),
      urduFont: urduFont,
      englishFont: englishFont,
      value1Label: value1Label,
      value2Label: value2Label,
      value3Label: value3Label,
    );

    final stem = _ledgerPdfStem(companyName);
    final fileName = '$stem.pdf';
    final dir = await _pdfSaveDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Save a PDF for one on-screen ledger page only.
  static Future<File> saveLedgerPagePdf({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
    required int pageIndex,
  }) async {
    final entries = await database.ledgerDao.entriesForCompanyOnce(companyId);
    final format = _a4Format();
    final bytes = await buildPdf(
      format: format,
      companyName: companyName,
      entries: entries,
      generatedAt: DateTime.now(),
      urduFont: urduFont,
      englishFont: englishFont,
      value1Label: value1Label,
      value2Label: value2Label,
      value3Label: value3Label,
      onlyPageIndex: pageIndex,
    );

    final stem = _ledgerPdfStem(companyName);
    final fileName = '${stem}_page${pageIndex + 1}.pdf';
    final dir = await _pdfSaveDirectory();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<void> openPdf({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
  }) async {
    final file = await savePdf(
      context: context,
      database: database,
      companyId: companyId,
      companyName: companyName,
      urduFont: urduFont,
      englishFont: englishFont,
      value1Label: value1Label,
      value2Label: value2Label,
      value3Label: value3Label,
    );
    await OpenFilex.open(file.path);
  }

  /// Build and open a one-page PDF for [pageIndex].
  static Future<void> openLedgerPagePdf({
    required BuildContext context,
    required AppDatabase database,
    required int companyId,
    required String companyName,
    required String urduFont,
    required String englishFont,
    String value1Label = 'Value 1',
    String value2Label = 'Value 2',
    String value3Label = 'Value 3',
    required int pageIndex,
  }) async {
    final file = await saveLedgerPagePdf(
      context: context,
      database: database,
      companyId: companyId,
      companyName: companyName,
      urduFont: urduFont,
      englishFont: englishFont,
      value1Label: value1Label,
      value2Label: value2Label,
      value3Label: value3Label,
      pageIndex: pageIndex,
    );
    await OpenFilex.open(file.path);
  }

  static String _ledgerPdfStem(String companyName) {
    return '${companyName}_ledger'.replaceAll(RegExp(r'[^\w\-]+'), '_');
  }

  static Future<Directory> _pdfSaveDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
    return getApplicationDocumentsDirectory();
  }
}
