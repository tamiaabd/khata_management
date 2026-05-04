import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/ledger_totals.dart';
import 'editable_cell.dart';

const int _flexParty = LedgerLayout.colPartyFlex;
const int _flexPending = LedgerLayout.colPendingFlex;
const int _flexValue = LedgerLayout.colValueFlex;
const int _flexSerial = LedgerLayout.colSerialFlex;
const double _wAction = LedgerLayout.colActionFixed;

class SummaryFooter extends StatelessWidget {
  const SummaryFooter({
    super.key,
    required this.pageTotals,
    this.totalTotals,
    this.godamTotals = LedgerTotals.zero,
    this.onGodamChanged,
  });

  final LedgerTotals pageTotals;
  final LedgerTotals? totalTotals;
  final LedgerTotals godamTotals;
  final ValueChanged<LedgerTotals>? onGodamChanged;

  @override
  Widget build(BuildContext context) {
    final total = totalTotals;
    return Material(
      elevation: 0,
      color: AppColors.paper,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SummaryTotalsRow(
            label: 'PAGE TOTAL',
            totals: pageTotals,
            fillColor: AppColors.primaryLight,
            labelColor: AppColors.primary,
          ),
          if (total != null) ...[
            const SizedBox(height: LedgerLayout.finalSummaryGap),
            _SummaryTotalsRow(
              label: 'TOTAL',
              totals: total,
              fillColor: AppColors.gridLineLight,
              labelColor: AppColors.primary,
            ),
            _GodamTotalsRow(totals: godamTotals, onChanged: onGodamChanged),
            _SummaryTotalsRow(
              label: 'GRAND TOTAL',
              totals: total + godamTotals,
              fillColor: AppColors.primaryLight,
              labelColor: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }
}

class LedgerColumnTotalsRow extends StatelessWidget {
  const LedgerColumnTotalsRow({
    super.key,
    required this.totals,
    this.label = 'TOTAL',
  });

  final LedgerTotals totals;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _SummaryTotalsRow(
      label: label,
      totals: totals,
      fillColor: AppColors.gridLineLight,
      labelColor: AppColors.primary,
    );
  }
}

class _SummaryTotalsRow extends StatelessWidget {
  const _SummaryTotalsRow({
    required this.label,
    required this.totals,
    required this.fillColor,
    required this.labelColor,
  });

  final String label;
  final LedgerTotals totals;
  final Color fillColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return _SummaryRowShell(
      fillColor: fillColor,
      children: [
        _TextSummaryCell(formatDecimal(totals.pending), flex: _flexPending),
        _TextSummaryCell(formatDecimal(totals.value1), flex: _flexValue),
        _TextSummaryCell(formatDecimal(totals.value2), flex: _flexValue),
        _TextSummaryCell(formatDecimal(totals.value3), flex: _flexValue),
        _LabelSummaryCell(label: label, color: labelColor),
        const _BlankSummaryCell(flex: _flexSerial),
        const _BlankSummaryCell(width: _wAction),
      ],
    );
  }
}

class _GodamTotalsRow extends StatefulWidget {
  const _GodamTotalsRow({required this.totals, required this.onChanged});

  final LedgerTotals totals;
  final ValueChanged<LedgerTotals>? onChanged;

  @override
  State<_GodamTotalsRow> createState() => _GodamTotalsRowState();
}

class _GodamTotalsRowState extends State<_GodamTotalsRow> {
  late final TextEditingController _pending;
  late final TextEditingController _value1;
  late final TextEditingController _value2;
  late final TextEditingController _value3;

  final _pendingFocus = FocusNode(debugLabel: 'godamPending');
  final _value1Focus = FocusNode(debugLabel: 'godamValue1');
  final _value2Focus = FocusNode(debugLabel: 'godamValue2');
  final _value3Focus = FocusNode(debugLabel: 'godamValue3');

  @override
  void initState() {
    super.initState();
    _pending = TextEditingController(
      text: formatDecimal(widget.totals.pending),
    );
    _value1 = TextEditingController(text: formatDecimal(widget.totals.value1));
    _value2 = TextEditingController(text: formatDecimal(widget.totals.value2));
    _value3 = TextEditingController(text: formatDecimal(widget.totals.value3));
  }

  @override
  void didUpdateWidget(covariant _GodamTotalsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_pending, _pendingFocus, widget.totals.pending);
    _sync(_value1, _value1Focus, widget.totals.value1);
    _sync(_value2, _value2Focus, widget.totals.value2);
    _sync(_value3, _value3Focus, widget.totals.value3);
  }

  @override
  void dispose() {
    _pending.dispose();
    _value1.dispose();
    _value2.dispose();
    _value3.dispose();
    _pendingFocus.dispose();
    _value1Focus.dispose();
    _value2Focus.dispose();
    _value3Focus.dispose();
    super.dispose();
  }

  void _sync(TextEditingController c, FocusNode f, double value) {
    if (f.hasFocus) return;
    final next = formatDecimal(value);
    if (c.text != next) c.text = next;
  }

  void _emitChange() {
    widget.onChanged?.call(
      LedgerTotals(
        pending: _parseDouble(_pending.text),
        value1: _parseDouble(_value1.text),
        value2: _parseDouble(_value2.text),
        value3: _parseDouble(_value3.text),
      ),
    );
  }

  double _parseDouble(String value) => double.tryParse(value.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    return _SummaryRowShell(
      fillColor: AppColors.paper,
      children: [
        _EditableSummaryCell(
          controller: _pending,
          focusNode: _pendingFocus,
          onChanged: _emitChange,
          flex: _flexPending,
        ),
        _EditableSummaryCell(
          controller: _value1,
          focusNode: _value1Focus,
          onChanged: _emitChange,
          flex: _flexValue,
        ),
        _EditableSummaryCell(
          controller: _value2,
          focusNode: _value2Focus,
          onChanged: _emitChange,
          flex: _flexValue,
        ),
        _EditableSummaryCell(
          controller: _value3,
          focusNode: _value3Focus,
          onChanged: _emitChange,
          flex: _flexValue,
        ),
        const _LabelSummaryCell(label: 'GODAM', color: AppColors.primary),
        const _BlankSummaryCell(flex: _flexSerial),
        const _BlankSummaryCell(width: _wAction),
      ],
    );
  }
}

class _SummaryRowShell extends StatelessWidget {
  const _SummaryRowShell({required this.fillColor, required this.children});

  final Color fillColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LedgerLayout.summaryRowHeight,
      decoration: BoxDecoration(
        color: fillColor,
        border: const Border(left: BorderSide(color: AppColors.gridLine)),
      ),
      child: Row(children: children),
    );
  }
}

class _TextSummaryCell extends StatelessWidget {
  const _TextSummaryCell(this.text, {required this.flex});

  final String text;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return _SummaryCell(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          fontSize: LedgerLayout.summaryFontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _EditableSummaryCell extends StatelessWidget {
  const _EditableSummaryCell({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.flex,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return _SummaryCell(
      flex: flex,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (_) => onChanged(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: [LedgerDecimalInputFormatter()],
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          fontSize: LedgerLayout.summaryFontSize,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        ),
      ),
    );
  }
}

class _LabelSummaryCell extends StatelessWidget {
  const _LabelSummaryCell({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SummaryCell(
      flex: _flexParty,
      child: Text(
        label,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: LedgerLayout.summaryFontSize,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _BlankSummaryCell extends StatelessWidget {
  const _BlankSummaryCell({this.flex, this.width});

  final int? flex;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return _SummaryCell(
      flex: flex,
      width: width,
      child: const SizedBox.shrink(),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.child, this.flex, this.width});

  final Widget child;
  final int? flex;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final cell = Container(
      height: LedgerLayout.summaryRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.centerRight,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.gridLine),
          right: BorderSide(color: AppColors.gridLine),
          bottom: BorderSide(color: AppColors.gridLine),
        ),
      ),
      child: child,
    );

    if (width != null) return SizedBox(width: width, child: cell);
    return Expanded(flex: flex ?? 1, child: cell);
  }
}
