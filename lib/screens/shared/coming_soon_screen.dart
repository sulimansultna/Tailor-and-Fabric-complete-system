import 'package:flutter/material.dart';

import '../../l10n/app_localizations_extensions.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.construction_outlined,
          size: 42,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(context.l10n.modulePlanned),
      ],
    ),
  );
}
