import 'package:flutter/material.dart';

import '../../../commands/app_commands.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../dashboard_strings.dart';
import 'dashboard_panel.dart';
import 'premium_illustration.dart';

class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({
    super.key,
    required this.strings,
    required this.onNewOrder,
    required this.onFindCustomer,
    required this.onReceivePayment,
    required this.onPurchaseFabric,
    required this.onSellFabric,
    required this.onAddCustomer,
  });

  final DashboardStrings strings;
  final VoidCallback onNewOrder;
  final VoidCallback onFindCustomer;
  final VoidCallback onReceivePayment;
  final VoidCallback onPurchaseFabric;
  final VoidCallback onSellFabric;
  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final actions = [
      (
        l10n.newOrder,
        PremiumMark.orders,
        const Color(0xff2563eb),
        onNewOrder,
        true,
      ),
      (
        l10n.dashFindCustomer,
        PremiumMark.customers,
        const Color(0xff0f766e),
        onFindCustomer,
        false,
      ),
      (
        strings.get('receivePayment'),
        PremiumMark.payments,
        const Color(0xff15803d),
        onReceivePayment,
        false,
      ),
      (
        l10n.dashPurchaseFabric,
        PremiumMark.fabric,
        const Color(0xff7c3aed),
        onPurchaseFabric,
        false,
      ),
      (
        strings.get('sellFabric'),
        PremiumMark.fabric,
        const Color(0xffea580c),
        onSellFabric,
        false,
      ),
      (
        strings.get('addCustomer'),
        PremiumMark.customers,
        const Color(0xff0f766e),
        onAddCustomer,
        false,
      ),
    ];
    return DashboardPanel(
      title: strings.get('quickActions'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 560
              ? 1
              : constraints.maxWidth < 900
              ? 2
              : 3;
          final width =
              (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final action in actions)
                SizedBox(
                  width: width,
                  child: action.$5
                      ? CommandButton(
                          register: false,
                          aliases: const ['action.new'],
                          id: 'orders.add',
                          child: FilledButton.icon(
                            onPressed: action.$4,
                            icon: PremiumMarkIcon(
                              mark: action.$2,
                              accent: Colors.white,
                              size: 28,
                            ),
                            label: Text(
                              action.$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 46),
                              backgroundColor: action.$3,
                              alignment: AlignmentDirectional.centerStart,
                            ),
                          ),
                        )
                      : _ActionButton(
                          label: action.$1,
                          mark: action.$2,
                          accent: action.$3,
                          onPressed: action.$4,
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.mark,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final PremiumMark mark;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: PremiumMarkIcon(mark: mark, accent: accent, size: 28),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 46),
        foregroundColor: scheme.onSurface,
        alignment: AlignmentDirectional.centerStart,
        side: BorderSide(color: scheme.outlineVariant),
      ),
    );
  }
}
