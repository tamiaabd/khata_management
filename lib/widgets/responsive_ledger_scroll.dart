import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/constants.dart';

/// Horizontal scale applied next to the scroll area (e.g. docked totals).
double responsiveA4LedgerScale(double viewportWidth) {
  final inset = LedgerLayout.viewportHorizontalPadding(viewportWidth);
  final innerMaxW = math.max(0.0, viewportWidth - 2 * inset);
  return math.max(0.01, math.min(1.0, innerMaxW / LedgerLayout.a4Width));
}

typedef ResponsiveA4PageBuilder =
    Widget Function(BuildContext context, int index);

/// Scrollable A4-width ledger viewport with page-level lazy building.
class ResponsiveA4PageList extends StatelessWidget {
  const ResponsiveA4PageList({
    super.key,
    required this.scrollController,
    required this.itemCount,
    required this.itemBuilder,
    this.itemSpacing = 16,
  });

  final ScrollController scrollController;
  final int itemCount;
  final ResponsiveA4PageBuilder itemBuilder;
  final double itemSpacing;

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
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(inset, 8, inset, 0),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final scale = responsiveA4LedgerScale(constraints.maxWidth);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == itemCount - 1 ? 0 : itemSpacing,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: LedgerLayout.a4Width * scale,
                    child: _ScaledLayout(
                      scale: scale,
                      child: SizedBox(
                        width: LedgerLayout.a4Width,
                        child: Builder(
                          builder: (context) => itemBuilder(context, index),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ScaledLayout extends SingleChildRenderObjectWidget {
  const _ScaledLayout({required this.scale, required super.child});

  final double scale;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderScaledLayout(scale);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderScaledLayout renderObject,
  ) {
    renderObject.scale = scale;
  }
}

class _RenderScaledLayout extends RenderProxyBox {
  _RenderScaledLayout(double scale) : _scale = scale;

  double _scale;

  double get scale => _scale;

  set scale(double value) {
    if (_scale == value) return;
    _scale = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }

    final childConstraints = BoxConstraints(
      minWidth: constraints.minWidth / scale,
      maxWidth: constraints.maxWidth / scale,
      minHeight: constraints.minHeight / scale,
      maxHeight: constraints.maxHeight.isFinite
          ? constraints.maxHeight / scale
          : double.infinity,
    );
    child.layout(childConstraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width * scale, child.size.height * scale),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(scale, scale, 1),
      super.paint,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: Matrix4.diagonal3Values(scale, scale, 1),
      position: position,
      hitTest: (result, position) {
        return child.hitTest(result, position: position);
      },
    );
  }
}
