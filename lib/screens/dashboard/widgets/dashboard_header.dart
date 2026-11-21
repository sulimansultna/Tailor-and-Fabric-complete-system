import 'package:flutter/material.dart';

import '../../../commands/app_commands.dart';
import '../dashboard_strings.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.now,
    required this.strings,
    required this.onNewOrder,
    required this.onRefresh,
  });

  final DateTime now;
  final DashboardStrings strings;
  final VoidCallback onNewOrder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final date = MaterialLocalizations.of(context).formatMediumDate(now);
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: strings.get('refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
          CommandButton(
            register: false,
            aliases: const ['action.new'],
            id: 'orders.add',
            child: FilledButton.icon(
              onPressed: onNewOrder,
              icon: const Icon(Icons.add_rounded),
              label: Text(strings.get('newOrder')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ),
        ],
      );
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.get('dashboard'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${strings.get('greeting')} · ${strings.get('today')} · $date',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      if (constraints.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: 8),
            Align(alignment: AlignmentDirectional.centerEnd, child: actions),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: heading),
          const SizedBox(width: 8),
          actions,
        ],
      );
    },
  );
}
