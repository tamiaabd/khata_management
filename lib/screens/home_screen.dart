import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/settings_provider.dart';
import '../services/pdf_service.dart';
import '../services/update_service.dart';
import '../utils/constants.dart';

import '../widgets/ledger_table.dart';
import '../widgets/page_header.dart';
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
  final _updateService = UpdateService();
  int? _partyFocusEntryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    final info = await _updateService.checkForUpdate();
    if (!mounted || info == null) return;
    final shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: !AppUpdateConfig.forceUpdate,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: Text(
          'Current: ${info.currentVersion}+${info.currentBuild}\nLatest: ${info.latestVersion}+${info.latestBuild}\n\nDo you want to download and install the latest version?',
        ),
        actions: [
          if (!AppUpdateConfig.forceUpdate)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update now'),
          ),
        ],
      ),
    );
    if (shouldUpdate != true) return;
    final started = await _runUpdateWithProgress(info);
    if (!mounted || started) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not start update installer.')),
    );
  }

  Future<bool> _runUpdateWithProgress(UpdateInfo info) async {
    final progress = ValueNotifier<double>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Downloading update'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, value, _) {
              final percent = (value * 100).toStringAsFixed(0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: value > 0 ? value : null),
                  const SizedBox(height: 12),
                  Text('Progress: $percent%'),
                ],
              );
            },
          ),
        ),
      ),
    );

    final started = await _updateService.downloadAndInstall(
      info,
      onProgress: (value) => progress.value = value,
    );
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    progress.dispose();
    return started;
  }

  LedgerTotals _totals(List<LedgerEntry> entries) {
    var p = 0.0;
    for (final e in entries) {
      p += e.pendingPayment;
    }
    return LedgerTotals(pending: p);
  }



  Future<void> _addRow(AppDatabase db) async {
    final serial = await db.ledgerDao.nextSerialNumber(_companyId);
    final id = await db.ledgerDao.insertEntry(
      LedgerEntriesCompanion.insert(
        companyId: _companyId,
        serialNumber: serial,
      ),
    );
    await db.companyDao.touchCompanyUpdatedAt(_companyId);
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        title: const Text('Virtual Manager'),
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
                  partyLabel: s.partyLabel,
                  value1Label: s.value1Label,
                  value2Label: s.value2Label,
                  value3Label: s.value3Label,
                  pendingLabel: s.pendingLabel,
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Save PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              final company = await (db.select(
                db.companies,
              )..where((t) => t.id.equals(_companyId))).getSingle();
              if (context.mounted) {
                final s = context.read<SettingsProvider>();
                await PdfService.sharePdf(
                  context: context,
                  database: db,
                  companyId: _companyId,
                  companyName: company.companyName,
                  urduFont: s.urduFont,
                  partyLabel: s.partyLabel,
                  value1Label: s.value1Label,
                  value2Label: s.value2Label,
                  value3Label: s.value3Label,
                  pendingLabel: s.pendingLabel,
                );
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

          return StreamBuilder<Company>(
            stream: (db.select(
              db.companies,
            )..where((t) => t.id.equals(_companyId))).watchSingle(),
            builder: (context, companySnap) {
              final company = companySnap.data;
              final pages = LedgerLayout.paginate(entries);
              final totalPages = pages.length;

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
                                  PageHeader(
                                    companyName: company?.companyName ?? '',
                                    date: DateTime.now(),
                                    pageLabel:
                                        'Page ${p + 1} of $totalPages',
                                  ),
                                  const LedgerTableHeaderRow(),
                                  LedgerTable(
                                    db: db,
                                    companyId: _companyId,
                                    entries: pages[p],
                                    partyFocusEntryId:
                                        p == pages.length - 1
                                            ? _partyFocusEntryId
                                            : null,
                                  ),
                                  if (p == pages.length - 1)
                                    SummaryFooter(totals: totals)
                                  else
                                    const SizedBox(
                                        height: LedgerLayout
                                            .summaryFooterHeight),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    ),
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
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => _addRow(db),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Row'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

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
