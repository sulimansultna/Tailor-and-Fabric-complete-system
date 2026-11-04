import 'package:flutter/material.dart';
import '../../../commands/app_commands.dart';

import '../../../widgets/shop_logo.dart';
import '../dashboard_strings.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.shopName,
    required this.now,
    required this.strings,
    required this.onNewOrder,
    required this.onRefresh,
    this.logoPath,
  });

  final String shopName;
  final String? logoPath;
  final DateTime now;
  final DashboardStrings strings;
  final VoidCallback onNewOrder;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final date = MaterialLocalizations.of(context).formatMediumDate(now);
      final logoSize = constraints.maxWidth < 560 ? 44.0 : 56.0;
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: strings.get('refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          CommandButton(register: false, aliases: const ['action.new'], id: 'orders.add', child: FilledButton.icon(
            onPressed: onNewOrder,
            icon: const Icon(Icons.add_rounded),
            label: Text(strings.get('newOrder')),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          )),
        ],
      );
      final heading = Row(
        children: [
          ShopLogo(path: logoPath, size: logoSize),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.get('dashboard'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.get('greeting')}, $shopName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${strings.get('today')} · $date',
                  textDirection: Directionality.of(context),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

      if (constraints.maxWidth < 560) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd, child: actions),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: heading),
          const SizedBox(width: 8),
          actions,
        ],
      );
    },
  );
}
