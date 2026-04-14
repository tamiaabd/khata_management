import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/formatters.dart';

class LedgerTotals {
  const LedgerTotals({required this.pending});

  final double pending;
}

class SummaryFooter extends StatelessWidget {
  const SummaryFooter({super.key, required this.totals});

  final LedgerTotals totals;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: AppColors.primaryLight,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.gridLine)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 44),
              const Expanded(
                flex: 3,
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: LedgerLayout.summaryFontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Expanded(flex: 2, child: SizedBox.shrink()),
              const Expanded(flex: 2, child: SizedBox.shrink()),
              const Expanded(flex: 2, child: SizedBox.shrink()),
              Expanded(
                flex: 2,
                child: Text(
                  formatDecimal(totals.pending),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: LedgerLayout.summaryFontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }
}
