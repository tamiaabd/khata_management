import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/debouncer.dart';

/// Editable page title for one ledger sheet; persisted on [anchor] (first row of the sheet).
class SheetPageCategoryField extends StatefulWidget {
  const SheetPageCategoryField({
    super.key,
    required this.anchor,
    required this.db,
  });

  final LedgerEntry anchor;
  final AppDatabase db;

  @override
  State<SheetPageCategoryField> createState() => _SheetPageCategoryFieldState();
}

class _SheetPageCategoryFieldState extends State<SheetPageCategoryField> {
  late final TextEditingController _controller;
  final _debouncer = Debouncer(duration: const Duration(milliseconds: 300));
  final _focus = FocusNode(debugLabel: 'sheetPageCategory');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.anchor.pageCategory);
  }

  @override
  void didUpdateWidget(covariant SheetPageCategoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anchor.id != widget.anchor.id) {
      _controller.text = widget.anchor.pageCategory;
      return;
    }
    final next = widget.anchor.pageCategory;
    if (_controller.text != next && !_focus.hasFocus) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _debouncer.flush();
    _debouncer.dispose();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _persist(String value) {
    _debouncer.run(() async {
      if (!mounted) return;
      final next = widget.anchor.copyWith(pageCategory: value);
      await widget.db.ledgerDao.updateEntry(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final font = context.select<SettingsProvider, String>((s) => s.englishFont);
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        fontSize: LedgerLayout.headerFontSize,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFamily: font,
      ),
      decoration: const InputDecoration(
        hintText: 'Page Category',
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      onChanged: _persist,
    );
  }
}
