import 'package:flutter/material.dart';

/// Lets a page's controls scroll away when a short window needs room for its list.
class ResponsiveListPage extends StatelessWidget {
  const ResponsiveListPage({
    super.key,
    required this.header,
    required this.body,
  });

  final List<Widget> header;
  final Widget body;

  @override
  Widget build(BuildContext context) => NestedScrollView(
    headerSliverBuilder: (context, innerBoxIsScrolled) => [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: header,
        ),
      ),
    ],
    body: body,
  );
}
