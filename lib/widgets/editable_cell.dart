import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';

class LedgerDecimalInputFormatter extends TextInputFormatter {
  LedgerDecimalInputFormatter();

  static final _validNumber = RegExp(r'^-?(?:\d+)?(?:\.\d*)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || _validNumber.hasMatch(newValue.text)) {
      return newValue;
    }
    return oldValue;
  }
}

/// Compact numeric cell; keeps LTR for digits.
class NumericLedgerField extends StatelessWidget {
  const NumericLedgerField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.textAlign = TextAlign.right,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final TextAlign textAlign;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [LedgerDecimalInputFormatter()],
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      style: const TextStyle(
        fontSize: LedgerLayout.tableBodyFontSize,
        color: AppColors.textPrimary,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
    );
  }
}
