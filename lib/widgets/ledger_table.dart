import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/debouncer.dart';
import '../utils/formatters.dart';
import '../utils/text_direction_helper.dart';

import 'editable_cell.dart';

const int _flexParty = LedgerLayout.colPartyFlex;
const int _flexNum = LedgerLayout.colValueFlex;
const double _wSerial = LedgerLayout.colSerialFixed;
const double _wAction = LedgerLayout.colActionFixed;

class LedgerTableHeaderRow extends StatefulWidget {
  const LedgerTableHeaderRow({super.key});

  @override
  State<LedgerTableHeaderRow> createState() => _LedgerTableHeaderRowState();
}

class _LedgerTableHeaderRowState extends State<LedgerTableHeaderRow> {
  late final TextEditingController _v1Label;
  late final TextEditingController _v2Label;
  late final TextEditingController _v3Label;

  late final FocusNode _focusV1Label;
  late final FocusNode _focusV2Label;
  late final FocusNode _focusV3Label;

  @override
  void initState() {
    super.initState();
    final p = context.read<SettingsProvider>();
    _v1Label = TextEditingController(text: p.value1Label);
    _v2Label = TextEditingController(text: p.value2Label);
    _v3Label = TextEditingController(text: p.value3Label);
    _focusV1Label = FocusNode(debugLabel: 'headerV1');
    _focusV2Label = FocusNode(debugLabel: 'headerV2');
    _focusV3Label = FocusNode(debugLabel: 'headerV3');
  }

  @override
  void dispose() {
    _v1Label.dispose();
    _v2Label.dispose();
    _v3Label.dispose();
    _focusV1Label.dispose();
    _focusV2Label.dispose();
    _focusV3Label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    return SizedBox(
      height: LedgerLayout.tableHeaderHeight,
      child: Container(
        color: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            SizedBox(
              width: _wSerial,
              child: Text(
                '#',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: LedgerLayout.tableHeaderFontSize,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: _flexParty,
              child: const _StaticUrduHeaderText(
                text: LedgerLayout.partyHeaderText,
                fontFamily: 'BombayBlackUnicode',
                fontSize: LedgerLayout.partyHeaderFontSize,
                contentPadding: EdgeInsets.fromLTRB(4, 0, 4, 4),
              ),
            ),
            Expanded(
              flex: _flexNum,
              child: _HeaderField(
                controller: _v1Label,
                align: TextAlign.right,
                focusNode: _focusV1Label,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _focusV2Label.requestFocus(),
                onChanged: settings.setValue1Label,
              ),
            ),
            Expanded(
              flex: _flexNum,
              child: _HeaderField(
                controller: _v2Label,
                align: TextAlign.right,
                focusNode: _focusV2Label,
                textInputAction: TextInputAction.next,
                onEditingComplete: () => _focusV3Label.requestFocus(),
                onChanged: settings.setValue2Label,
              ),
            ),
            Expanded(
              flex: _flexNum,
              child: _HeaderField(
                controller: _v3Label,
                align: TextAlign.right,
                focusNode: _focusV3Label,
                textInputAction: TextInputAction.done,
                onEditingComplete: () => _focusV3Label.unfocus(),
                onChanged: settings.setValue3Label,
              ),
            ),
            Expanded(
              flex: _flexNum,
              child: const _StaticUrduHeaderText(
                text: LedgerLayout.pendingHeaderText,
                fontFamily: 'BombayBlackUnicode',
                fontSize: LedgerLayout.pendingHeaderFontSize,
                contentPadding: EdgeInsets.fromLTRB(4, 0, 4, 4),
              ),
            ),
            const SizedBox(width: _wAction),
          ],
        ),
      ),
    );
  }
}

class _HeaderField extends StatelessWidget {
  const _HeaderField({
    required this.controller,
    this.align = TextAlign.right,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onEditingComplete,
    required this.onChanged,
  });

  final TextEditingController controller;
  final TextAlign align;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: align,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: LedgerLayout.tableHeaderFontSize,
        color: AppColors.textPrimary,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
      onChanged: onChanged,
    );
  }
}

class _StaticUrduHeaderText extends StatelessWidget {
  const _StaticUrduHeaderText({
    required this.text,
    required this.fontFamily,
    required this.fontSize,
    this.contentPadding = const EdgeInsets.fromLTRB(4, 2, 4, 8),
  });

  final String text;
  final String fontFamily;
  final double fontSize;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: contentPadding,
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: fontSize,
            fontFamily: fontFamily,
            color: AppColors.textPrimary,
            height: 1.0,
          ),
          strutStyle: StrutStyle(
            fontSize: fontSize,
            height: 1.0,
            forceStrutHeight: true,
          ),
        ),
      ),
    );
  }
}

class LedgerTable extends StatefulWidget {
  const LedgerTable({
    super.key,
    required this.db,
    required this.companyId,
    required this.entries,
    this.partyFocusEntryId,
  });

  final AppDatabase db;
  final int companyId;
  final List<LedgerEntry> entries;
  final int? partyFocusEntryId;

  @override
  State<LedgerTable> createState() => _LedgerTableState();
}

class _LedgerTableState extends State<LedgerTable> {
  final Map<int, FocusNode> _partyFocusByEntryId = {};

  @override
  void initState() {
    super.initState();
    _syncPartyFocusNodes(widget.entries);
  }

  @override
  void didUpdateWidget(LedgerTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameEntryIdSequence(oldWidget.entries, widget.entries)) return;
    _syncPartyFocusNodes(widget.entries);
  }

  /// Same ids in the same order — skip focus-node map work on every stream tick.
  static bool _sameEntryIdSequence(List<LedgerEntry> a, List<LedgerEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final n in _partyFocusByEntryId.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// Keeps one party [FocusNode] per entry id. Never disposes during [build]
  /// (deferred to the next frame when removing ids).
  void _syncPartyFocusNodes(List<LedgerEntry> entries) {
    final ids = entries.map((e) => e.id).toSet();
    final toDispose = <FocusNode>[];
    _partyFocusByEntryId.removeWhere((id, node) {
      if (!ids.contains(id)) {
        toDispose.add(node);
        return true;
      }
      return false;
    });
    if (toDispose.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final n in toDispose) {
          n.dispose();
        }
      });
    }
    for (final e in entries) {
      _partyFocusByEntryId.putIfAbsent(
        e.id,
        () => FocusNode(debugLabel: 'party ${e.id}'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < entries.length; i++)
          _LedgerRow(
            key: ValueKey(entries[i].id),
            db: widget.db,
            companyId: widget.companyId,
            entry: entries[i],
            requestPartyFocus: widget.partyFocusEntryId == entries[i].id,
            partyFocus: _partyFocusByEntryId[entries[i].id]!,
            nextPartyFocus: i + 1 < entries.length
                ? _partyFocusByEntryId[entries[i + 1].id]
                : null,
          ),
        if (entries.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48),
            alignment: Alignment.center,
            child: Text(
              'No entries yet. Tap Add Row to start.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class _LedgerRow extends StatefulWidget {
  const _LedgerRow({
    super.key,
    required this.db,
    required this.companyId,
    required this.entry,
    required this.requestPartyFocus,
    required this.partyFocus,
    this.nextPartyFocus,
  });

  final AppDatabase db;
  final int companyId;
  final LedgerEntry entry;
  final bool requestPartyFocus;
  final FocusNode partyFocus;
  final FocusNode? nextPartyFocus;

  @override
  State<_LedgerRow> createState() => _LedgerRowState();
}

class _LedgerRowState extends State<_LedgerRow> {
  late final TextEditingController _party;
  late final TextEditingController _v1;
  late final TextEditingController _v2;
  late final TextEditingController _v3;
  late final TextEditingController _pending;

  final _v1Focus = FocusNode();
  final _v2Focus = FocusNode();
  final _v3Focus = FocusNode();
  final _pendingFocus = FocusNode();
  late final FocusNode _deleteFocus;

  /// Coalesces DB writes; avoids overlapping [replace] calls with stale [widget.entry] snapshots.
  final _persistDebouncer = Debouncer(
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _deleteFocus = FocusNode(
      debugLabel: 'delete ${widget.entry.id}',
      skipTraversal: true,
    );
    final e = widget.entry;
    _party = TextEditingController(text: e.partyName);
    _v1 = TextEditingController(text: formatDecimal(e.value1));
    _v2 = TextEditingController(text: formatDecimal(e.value2));
    _v3 = TextEditingController(text: formatDecimal(e.value3));
    _pending = TextEditingController(text: formatDecimal(e.pendingPayment));
    if (widget.requestPartyFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.partyFocus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _LedgerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final e = widget.entry;
    if (oldWidget.entry.id != e.id) return;
    if (widget.requestPartyFocus && !oldWidget.requestPartyFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.partyFocus.requestFocus();
      });
    }
    void sync(TextEditingController c, String next, FocusNode? f) {
      if (f?.hasFocus ?? false) return;
      if (c.text != next) c.text = next;
    }

    sync(_party, e.partyName, widget.partyFocus);
    if (!_v1Focus.hasFocus) sync(_v1, formatDecimal(e.value1), null);
    if (!_v2Focus.hasFocus) sync(_v2, formatDecimal(e.value2), null);
    if (!_v3Focus.hasFocus) sync(_v3, formatDecimal(e.value3), null);
    if (!_pendingFocus.hasFocus) {
      sync(_pending, formatDecimal(e.pendingPayment), null);
    }
  }

  @override
  void dispose() {
    _persistDebouncer.flush();
    _persistDebouncer.dispose();
    _party.dispose();
    _v1.dispose();
    _v2.dispose();
    _v3.dispose();
    _pending.dispose();
    _deleteFocus.dispose();
    _v1Focus.dispose();
    _v2Focus.dispose();
    _v3Focus.dispose();
    _pendingFocus.dispose();
    super.dispose();
  }

  Future<void> _persist(LedgerEntry next) async {
    await widget.db.ledgerDao.updateEntry(next);
    await widget.db.companyDao.touchCompanyUpdatedAt(widget.companyId);
  }

  /// Single source of truth for persistence — prevents out-of-order async replaces
  /// from clobbering fields when using `widget.entry.copyWith(singleField: ...)`.
  LedgerEntry _entryFromControllers() {
    return widget.entry.copyWith(
      partyName: _party.text,
      value1: _parseDouble(_v1.text),
      value2: _parseDouble(_v2.text),
      value3: _parseDouble(_v3.text),
      pendingPayment: _parseDouble(_pending.text),
    );
  }

  void _schedulePersist() {
    _persistDebouncer.run(() {
      if (!mounted) return;
      _persist(_entryFromControllers());
    });
  }

  double _parseDouble(String s) => double.tryParse(s.trim()) ?? 0;

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete row?'),
        content: const Text('This row will be removed from the ledger.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.delete),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await widget.db.ledgerDao.deleteEntry(widget.entry.id);
      await widget.db.companyDao.touchCompanyUpdatedAt(widget.companyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final urduFont = context.select<SettingsProvider, String>(
      (s) => s.urduFont,
    );
    final dir = directionForMixedText(_party.text);
    final englishPartyStyle =
        Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: LedgerLayout.partyNameFontSize,
          height: 1,
          color: AppColors.textPrimary,
        ) ??
        const TextStyle(
          fontSize: LedgerLayout.partyNameFontSize,
          height: 1,
          color: AppColors.textPrimary,
        );
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gridLine)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: _confirmDelete,
          hoverColor: AppColors.gridLineLight.withValues(alpha: 0.5),
          splashColor: AppColors.primaryLight.withValues(alpha: 0.3),
          child: SizedBox(
            height: LedgerLayout.rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: _wSerial,
                    child: Text(
                      '${widget.entry.serialNumber}',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: LedgerLayout.tableBodyFontSize,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flexParty,
                    child: Directionality(
                      textDirection: dir,
                      child: TextField(
                        controller: _party,
                        focusNode: widget.partyFocus,
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () => _v1Focus.requestFocus(),
                        style: dir == TextDirection.rtl
                            ? TextStyle(
                                fontSize: LedgerLayout.partyNameFontSize,
                                fontFamily: urduFont,
                                height: 1,
                                color: AppColors.textPrimary,
                              )
                            : englishPartyStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _schedulePersist();
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flexNum,
                    child: NumericLedgerField(
                      focusNode: _v1Focus,
                      controller: _v1,
                      onEditingComplete: () => _v2Focus.requestFocus(),
                      onChanged: (_) => _schedulePersist(),
                    ),
                  ),
                  Expanded(
                    flex: _flexNum,
                    child: NumericLedgerField(
                      focusNode: _v2Focus,
                      controller: _v2,
                      onEditingComplete: () => _v3Focus.requestFocus(),
                      onChanged: (_) => _schedulePersist(),
                    ),
                  ),
                  Expanded(
                    flex: _flexNum,
                    child: NumericLedgerField(
                      focusNode: _v3Focus,
                      controller: _v3,
                      onEditingComplete: () => _pendingFocus.requestFocus(),
                      onChanged: (_) => _schedulePersist(),
                    ),
                  ),
                  Expanded(
                    flex: _flexNum,
                    child: NumericLedgerField(
                      focusNode: _pendingFocus,
                      controller: _pending,
                      textInputAction: widget.nextPartyFocus != null
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onEditingComplete: () {
                        final next = widget.nextPartyFocus;
                        if (next != null) {
                          next.requestFocus();
                        } else {
                          _pendingFocus.unfocus();
                        }
                      },
                      onChanged: (_) => _schedulePersist(),
                    ),
                  ),
                  SizedBox(
                    width: _wAction,
                    child: IconButton(
                      focusNode: _deleteFocus,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete row',
                      onPressed: _confirmDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.delete,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
