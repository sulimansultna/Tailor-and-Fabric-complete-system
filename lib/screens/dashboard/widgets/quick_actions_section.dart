import 'package:flutter/material.dart';
import '../../../commands/app_commands.dart';

import '../dashboard_strings.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.strings,
    required this.onNewOrder,
    required this.onAddCustomer,
    required this.onReceivePayment,
    required this.onSellFabric,
  });

  final DashboardStrings strings;
  final VoidCallback onNewOrder;
  final VoidCallback onAddCustomer;
  final VoidCallback onReceivePayment;
  final VoidCallback onSellFabric;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        strings.get('addCustomer'),
        Icons.person_add_alt_1_outlined,
        onAddCustomer,
      ),
      (
        strings.get('receivePayment'),
        Icons.payments_outlined,
        onReceivePayment,
      ),
      (strings.get('sellFabric'), Icons.inventory_2_outlined, onSellFabric),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.get('quickActions'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            CommandButton(register: false, aliases: const ['action.new'], id: 'orders.add', child: FilledButton.icon(
              onPressed: onNewOrder,
              icon: const Icon(Icons.add_shopping_cart_outlined),
              label: Text(strings.get('newOrder')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )),
            for (final action in actions)
              OutlinedButton.icon(
                onPressed: action.$3,
                icon: Icon(action.$2),
                label: Text(action.$1),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
