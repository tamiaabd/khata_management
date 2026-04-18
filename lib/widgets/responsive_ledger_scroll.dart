import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Horizontal scale applied next to the scroll area (e.g. docked totals).
double responsiveA4LedgerScale(double viewportWidth) {
  final inset = LedgerLayout.viewportHorizontalPadding(viewportWidth);
  final innerMaxW = math.max(0.0, viewportWidth - 2 * inset);
  return math.min(1.0, innerMaxW / LedgerLayout.a4Width);
}

/// Scrollable A4-width ledger viewport with uniform horizontal scaling.
class ResponsiveA4Scroll extends StatelessWidget {
  const ResponsiveA4Scroll({
    super.key,
    required this.scrollController,
    required this.child,
  });

  final ScrollController scrollController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = LedgerLayout.viewportHorizontalPadding(
          constraints.maxWidth,
        );
        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: LedgerLayout.a4Width,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
