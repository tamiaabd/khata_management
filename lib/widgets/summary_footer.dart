import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/formatters.dart';

const int _flexParty = LedgerLayout.colPartyFlex;
const int _flexNum = LedgerLayout.colValueFlex;
const double _wSerial = LedgerLayout.colSerialFixed;
const double _wAction = LedgerLayout.colActionFixed;

class LedgerTotals {
  const LedgerTotals({
    required this.pending,
    required this.value1,
    required this.value2,
    required this.value3,
  });

  final double pending;
  final double value1;
  final double value2;
  final double value3;
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.gridLine)),
          ),
          child: Row(
            children: [
              const SizedBox(width: _wSerial),
              Expanded(
                flex: _flexNum,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
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
              ),
              Expanded(
                flex: _flexNum,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    formatDecimal(totals.value1),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: LedgerLayout.summaryFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _flexNum,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    formatDecimal(totals.value2),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: LedgerLayout.summaryFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _flexNum,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    formatDecimal(totals.value3),
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: LedgerLayout.summaryFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _flexParty,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: const Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: LedgerLayout.summaryFontSize,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _wAction),
            ],
          ),
        ),
      ),
    );
  }
}
