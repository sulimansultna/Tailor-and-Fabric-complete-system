import 'package:flutter/material.dart';

/// Constrains horizontal scrolling to the table and exposes its scrollbar.
class HorizontalTable extends StatefulWidget {
  const HorizontalTable({super.key, required this.child, this.controller});

  final Widget child;
  final ScrollController? controller;

  @override
  State<HorizontalTable> createState() => _HorizontalTableState();
}

class _HorizontalTableState extends State<HorizontalTable> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Scrollbar(
      controller: widget.controller ?? _controller,
      thumbVisibility: true,
      trackVisibility: true,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.horizontal,
      child: SingleChildScrollView(
        controller: widget.controller ?? _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: widget.child,
        ),
      ),
    ),
  );
}

class FixedTableHeader extends SliverPersistentHeaderDelegate {
  FixedTableHeader({required this.child, required this.height});
  final Widget child;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);
  @override
  bool shouldRebuild(covariant FixedTableHeader oldDelegate) =>
      oldDelegate.height != height || oldDelegate.child != child;
}
