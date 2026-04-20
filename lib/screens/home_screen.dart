import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/settings_provider.dart';
import '../services/app_update_service.dart';
import '../services/pdf_service.dart';
import '../utils/constants.dart';
import '../utils/ledger_pagination.dart';

import '../widgets/ledger_table.dart';
import '../widgets/page_header.dart';
import '../widgets/sheet_page_category_field.dart';
import '../widgets/responsive_ledger_scroll.dart';
import '../widgets/summary_footer.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _companyId = 1;
  final _scroll = ScrollController();
  final _rightLedgerKeys = <int, GlobalKey<LedgerTableState>>{};
  String _appVersion = '';
  int? _partyFocusEntryId;
  Company? _company;

  GlobalKey<LedgerTableState> _rightLedgerKeyForPage(int pageIndex) =>
      _rightLedgerKeys.putIfAbsent(
        pageIndex,
        GlobalKey<LedgerTableState>.new,
      );

  Future<void> _printLedgerPage(
    BuildContext context,
    AppDatabase db,
    String companyName,
    int pageIndex,
  ) async {
    if (companyName.isEmpty || !context.mounted) return;
    final s = context.read<SettingsProvider>();
    await PdfService.printLedgerPage(
      context: context,
      database: db,
      companyId: _companyId,
      companyName: companyName,
      urduFont: s.urduFont,
      englishFont: s.englishFont,
      value1Label: s.value1Label,
      value2Label: s.value2Label,
      value3Label: s.value3Label,
      pageIndex: pageIndex,
    );
  }

  Future<void> _exportLedgerPagePdf(
    BuildContext context,
    AppDatabase db,
    String companyName,
    int pageIndex,
  ) async {
    if (companyName.isEmpty) return;
    final action = await _showPdfOptions();
    if (action == null || !context.mounted) return;
    final s = context.read<SettingsProvider>();
    if (action == _PdfAction.save) {
      final file = await PdfService.saveLedgerPagePdf(
        context: context,
        database: db,
        companyId: _companyId,
        companyName: companyName,
        urduFont: s.urduFont,
        englishFont: s.englishFont,
        value1Label: s.value1Label,
        value2Label: s.value2Label,
        value3Label: s.value3Label,
        pageIndex: pageIndex,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved PDF: ${file.path}')));
    } else {
      await PdfService.openLedgerPagePdf(
        context: context,
        database: db,
        companyId: _companyId,
        companyName: companyName,
        urduFont: s.urduFont,
        englishFont: s.englishFont,
        value1Label: s.value1Label,
        value2Label: s.value2Label,
        value3Label: s.value3Label,
        pageIndex: pageIndex,
      );
    }
  }

  Future<_PdfAction?> _showPdfOptions() {
    return showModalBottomSheet<_PdfAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt_outlined),
              title: const Text('Save PDF'),
              onTap: () => Navigator.of(context).pop(_PdfAction.save),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_outlined),
              title: const Text('Open PDF'),
              onTap: () => Navigator.of(context).pop(_PdfAction.open),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAppTitle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = AppUpdateService.instance.takePostUpdateSuccessMessage();
      if (msg != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('App updated successfully to v$msg')),
        );
      }
      final err = AppUpdateService.instance.takePostUpdateErrorMessage();
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Last update failed. $err'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      _loadCompany();
    });
  }

  Future<void> _loadCompany() async {
    final db = context.read<AppDatabase>();
    final company = await (db.select(
      db.companies,
    )..where((t) => t.id.equals(_companyId))).getSingleOrNull();
    if (!mounted) return;
    setState(() => _company = company);
  }

  Future<void> _loadAppTitle() async {
    final current = await AppUpdateService.instance.resolveCurrentVersion();
    if (!mounted) return;
    setState(() => _appVersion = current.version);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  LedgerTotals _totals(List<LedgerEntry> entries) {
    var p = 0.0;
    var v1 = 0.0;
    var v2 = 0.0;
    var v3 = 0.0;
    for (final e in entries) {
      p += e.pendingPayment;
      v1 += e.value1;
      v2 += e.value2;
      v3 += e.value3;
    }
    return LedgerTotals(pending: p, value1: v1, value2: v2, value3: v3);
  }

  Future<void> _addRow(AppDatabase db) async {
    final serial = await db.ledgerDao.nextSerialNumber(_companyId);
    final id = await db.ledgerDao.insertEntry(
      LedgerEntriesCompanion.insert(
        companyId: _companyId,
        serialNumber: serial,
      ),
    );
    if (!mounted) return;
    setState(() => _partyFocusEntryId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      // Clear on the *next* frame so [LedgerTable] / [_LedgerRow] can mount and
      // schedule party focus before this id is nulled out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _partyFocusEntryId = null);
      });
    });
  }

  Future<void> _startNewPage(AppDatabase db) async {
    final existing = await db.ledgerDao.entriesForCompanyOnce(_companyId);
    final pages = LedgerPagination.pagesWithBreaks(existing);
    var copied = '';
    if (pages.isNotEmpty) {
      final last = pages.last;
      if (last.isNotEmpty) {
        copied = last.first.pageCategory;
      }
    }
    final serial = await db.ledgerDao.nextSerialNumber(_companyId);
    await db.ledgerDao.insertEntry(
      LedgerEntriesCompanion.insert(
        companyId: _companyId,
        serialNumber: serial,
        startsNewPage: const Value(true),
        pageCategory: Value(copied),
      ),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New page started. The previous sheet is unchanged.'),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
            if (mounted) await _loadCompany();
          },
        ),
        title: Text.rich(
          TextSpan(
            text: 'Virtual Manager',
            children: [
              if (_appVersion.isNotEmpty)
                TextSpan(
                  text: '  v$_appVersion',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final company = await (db.select(
                db.companies,
              )..where((t) => t.id.equals(_companyId))).getSingle();
              if (context.mounted) {
                final s = context.read<SettingsProvider>();
                await PdfService.printLedger(
                  context: context,
                  database: db,
                  companyId: _companyId,
                  companyName: company.companyName,
                  urduFont: s.urduFont,
                  englishFont: s.englishFont,
                  value1Label: s.value1Label,
                  value2Label: s.value2Label,
                  value3Label: s.value3Label,
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Save PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final action = await _showPdfOptions();
              if (action == null || !context.mounted) return;
              final company = await (db.select(
                db.companies,
              )..where((t) => t.id.equals(_companyId))).getSingle();
              if (context.mounted) {
                final s = context.read<SettingsProvider>();
                if (action == _PdfAction.save) {
                  final file = await PdfService.savePdf(
                    context: context,
                    database: db,
                    companyId: _companyId,
                    companyName: company.companyName,
                    urduFont: s.urduFont,
                    englishFont: s.englishFont,
                    value1Label: s.value1Label,
                    value2Label: s.value2Label,
                    value3Label: s.value3Label,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Saved PDF: ${file.path}')),
                  );
                } else {
                  await PdfService.openPdf(
                    context: context,
                    database: db,
                    companyId: _companyId,
                    companyName: company.companyName,
                    urduFont: s.urduFont,
                    englishFont: s.englishFont,
                    value1Label: s.value1Label,
                    value2Label: s.value2Label,
                    value3Label: s.value3Label,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<LedgerEntry>>(
        stream: db.ledgerDao.watchEntriesForCompany(_companyId),
        builder: (context, entrySnap) {
          final entries = entrySnap.data ?? [];
          final totals = _totals(entries);
          final company = _company;
          final pages = LedgerPagination.pagesWithBreaks(entries);
          final totalPages = pages.length;
          _rightLedgerKeys.removeWhere((k, _) => k >= pages.length);

          return Column(
                children: [
                  Expanded(
                    child: ResponsiveA4Scroll(
                      scrollController: _scroll,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var p = 0; p < pages.length; p++) ...[
                            _PaperSheet(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      4,
                                      4,
                                      0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          tooltip: 'Print page ${p + 1}',
                                          icon: const Icon(
                                            Icons.print_outlined,
                                            size: 22,
                                          ),
                                          onPressed: company == null
                                              ? null
                                              : () => _printLedgerPage(
                                                    context,
                                                    db,
                                                    company.companyName,
                                                    p,
                                                  ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            company?.companyName ?? '',
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textDirection: TextDirection.ltr,
                                            style: TextStyle(
                                              fontSize:
                                                  LedgerLayout.headerFontSize,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              fontFamily: context.select<
                                                SettingsProvider,
                                                String
                                              >((s) => s.englishFont),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'PDF page ${p + 1}',
                                          icon: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            size: 22,
                                          ),
                                          onPressed: company == null
                                              ? null
                                              : () => _exportLedgerPagePdf(
                                                    context,
                                                    db,
                                                    company.companyName,
                                                    p,
                                                  ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PageHeader(
                                    centerSection: pages[p].isEmpty
                                        ? Center(
                                            child: Text(
                                              'Page Category',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize:
                                                    LedgerLayout.headerFontSize,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                                fontFamily: context.select<
                                                  SettingsProvider,
                                                  String
                                                >((s) => s.englishFont),
                                              ),
                                            ),
                                          )
                                        : SheetPageCategoryField(
                                            anchor: pages[p].first,
                                            db: db,
                                          ),
                                    date: DateTime.now(),
                                    pageLabel: 'Page ${p + 1} of $totalPages',
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final (left, right) =
                                          LedgerLayout.splitSheetColumns(
                                        pages[p],
                                      );
                                      final isLastPage =
                                          p == pages.length - 1;
                                      final rightKey = _rightLedgerKeyForPage(
                                        p,
                                      );
                                      final bridgeToRightParty =
                                          right.isNotEmpty
                                          ? rightKey.currentState
                                                ?.partyFocusForEntryId(
                                                  right.first.id,
                                                )
                                          : null;
                                      final onAdd = isLastPage
                                          ? () => _addRow(db)
                                          : null;
                                      // RTL sheet: first serial block on the right,
                                      // second block on the left (Row is LTR).
                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const LedgerTableHeaderRow(),
                                                LedgerTable(
                                                  key: rightKey,
                                                  db: db,
                                                  companyId: _companyId,
                                                  entries: right,
                                                  partyFocusEntryId: isLastPage
                                                      ? _partyFocusEntryId
                                                      : null,
                                                  onAddRow: right.isNotEmpty
                                                      ? onAdd
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                const LedgerTableHeaderRow(),
                                                LedgerTable(
                                                  db: db,
                                                  companyId: _companyId,
                                                  entries: left,
                                                  partyFocusEntryId: isLastPage
                                                      ? _partyFocusEntryId
                                                      : null,
                                                  focusAfterLastRowPending:
                                                      bridgeToRightParty,
                                                  onAddRow: right.isEmpty
                                                      ? onAdd
                                                      : null,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (p != pages.length - 1)
                                    const SizedBox(
                                      height:
                                          LedgerLayout.summaryFooterHeight,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, c) {
                      final hPad = LedgerLayout.viewportHorizontalPadding(
                        c.maxWidth,
                      );
                      final scale = responsiveA4LedgerScale(c.maxWidth);
                      return Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 0),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Transform.scale(
                              scale: scale,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: LedgerLayout.a4Width,
                                child: SummaryFooter(totals: totals),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final hPad = LedgerLayout.viewportHorizontalPadding(
                          constraints.maxWidth,
                        );
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                          decoration: const BoxDecoration(
                            color: AppColors.paper,
                            border: Border(
                              top: BorderSide(color: AppColors.gridLine),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message:
                                      'Starts a new sheet after the current one. '
                                      'Earlier pages stay exactly as they are.',
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed: () => _startNewPage(db),
                                    icon: const Icon(Icons.post_add_outlined),
                                    label: const Text('Next page'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () => _addRow(db),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add Row'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
        },
      ),
    );
  }
}

enum _PdfAction { save, open }

class _PaperSheet extends StatelessWidget {
  const _PaperSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.gridLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}





