import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.companyName,
    required this.date,
    this.pageLabel,
  });

  final String companyName;
  final DateTime date;
  final String? pageLabel;

  @override
  Widget build(BuildContext context) {
    final dateStr = ledgerDateFormat.format(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: pageLabel != null
                      ? Text(
                          pageLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textDirection: TextDirection.ltr,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  companyName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: LedgerLayout.headerFontSize,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamilyFallback: [
                      context.select<SettingsProvider, String>((s) => s.urduFont),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.gridLine),
        ],
      ),
    );
  }
}
