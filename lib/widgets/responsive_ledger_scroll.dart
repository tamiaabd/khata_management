import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Scrollable area that lays out ledger content at [LedgerLayout.a4Width] logical
/// pixels (matching PDF column math), then scales uniformly with the viewport
/// so the whole page resizes when the window size changes while keeping A4 proportions.
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
        final inset =
            LedgerLayout.viewportHorizontalPadding(constraints.maxWidth);
        return Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
            child: FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: LedgerLayout.a4Width,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
