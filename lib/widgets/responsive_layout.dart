import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Await unmounting before callers dispose controllers owned by a dialog.
Future<T?> showResponsiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    barrierDismissible: barrierDismissible,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

/// Breakpoints are measured in logical pixels and allow room for larger text.
abstract final class ResponsiveLayout {
  static double textFactor(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.5);

  static int columns(
    BuildContext context,
    double width, {
    required double minWidth,
    required int maxColumns,
    double gap = 12,
  }) => ((width + gap) / (minWidth * textFactor(context) + gap)).floor().clamp(
    1,
    maxColumns,
  );

  static Size dialogSize(
    BuildContext context, {
    double maxWidth = 1100,
    double maxHeight = 850,
    double inset = 16,
  }) {
    final media = MediaQuery.of(context);
    return Size(
      math.min(maxWidth, math.max(0, media.size.width - inset * 2)),
      math.min(
        maxHeight,
        math.max(
          0,
          media.size.height -
              media.viewInsets.vertical -
              media.padding.vertical -
              inset * 2,
        ),
      ),
    );
  }
}

/// A stable Wrap keeps field state and focus as columns change during resize.
class ResponsiveFormColumns extends StatelessWidget {
  const ResponsiveFormColumns({
    super.key,
    required this.children,
    this.minColumnWidth = 320,
    this.maxColumns = 2,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = ResponsiveLayout.columns(
        context,
        constraints.maxWidth,
        minWidth: minColumnWidth,
        maxColumns: maxColumns,
        gap: spacing,
      );
      final width = (constraints.maxWidth - spacing * (count - 1)) / count;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (var index = 0; index < children.length; index++)
            SizedBox(
              key: ValueKey(index),
              width: width,
              child: children[index],
            ),
        ],
      );
    },
  );
}
