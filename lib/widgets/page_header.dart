import 'package:flutter/material.dart';

import '../utils/constants.dart';
import '../utils/formatters.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.centerSection,
    required this.date,
    this.pageLabel,
  });

  /// Middle of the header row (page category field or read-only label).
  final Widget centerSection;
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
          LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final centerW = totalW * 0.34;
              final sideW = (totalW - centerW) / 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: sideW,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: pageLabel != null
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                pageLabel!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                textDirection: TextDirection.ltr,
                                maxLines: 1,
                                softWrap: false,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  SizedBox(width: centerW, child: centerSection),
                  SizedBox(
                    width: sideW,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.gridLine),
        ],
      ),
    );
  }
}
