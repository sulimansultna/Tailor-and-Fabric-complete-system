import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../dashboard_strings.dart';
import 'dashboard_panel.dart';

class OrdersAttentionSection extends StatefulWidget {
  const OrdersAttentionSection({
    super.key,
    required this.dueToday,
    required this.overdue,
    required this.ready,
    required this.strings,
    required this.onViewAll,
    required this.onOpenCustomer,
    required this.onReceivePayment,
    required this.onMarkDelivered,
  });

  final List<Map<String, Object?>> dueToday;
  final List<Map<String, Object?>> overdue;
  final List<Map<String, Object?>> ready;
  final DashboardStrings strings;
  final VoidCallback onViewAll;
  final ValueChanged<Map<String, Object?>> onOpenCustomer;
  final ValueChanged<Map<String, Object?>> onReceivePayment;
  final ValueChanged<Map<String, Object?>> onMarkDelivered;

  @override
  State<OrdersAttentionSection> createState() => _OrdersAttentionSectionState();
}

class _OrdersAttentionSectionState extends State<OrdersAttentionSection> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final tabs = [
      (widget.strings.get('dueToday'), widget.dueToday, DashboardTone.warning),
      (widget.strings.get('overdue'), widget.overdue, DashboardTone.due),
      (widget.strings.get('ready'), widget.ready, DashboardTone.good),
    ];
    final rows = tabs[selectedTab].$2;
    return DashboardPanel(
      title: widget.strings.get('attention'),
      accent: dashboardToneColor(context, tabs[selectedTab].$3),
      trailing: TextButton(
        onPressed: widget.onViewAll,
        child: Text(widget.strings.get('viewAll')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < tabs.length; i++)
                ChoiceChip(
                  label: Text('${tabs[i].$1} (${tabs[i].$2.length})'),
                  selected: selectedTab == i,
                  onSelected: (_) => setState(() => selectedTab = i),
                  selectedColor: dashboardToneColor(
                    context,
                    tabs[i].$3,
                  ).withValues(alpha: .16),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selectedTab == i
                        ? dashboardToneColor(context, tabs[i].$3)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  side: BorderSide(
                    color: selectedTab == i
                        ? dashboardToneColor(context, tabs[i].$3)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(widget.strings.get('emptyOrders'))),
            )
          else
            for (final order in rows.take(5))
              _AttentionOrderRow(
                order: order,
                overdue: selectedTab == 1,
                ready: selectedTab == 2,
                strings: widget.strings,
                locale: locale,
                l10n: l10n,
                onOpen: () => widget.onOpenCustomer(order),
                onPayment: () => widget.onReceivePayment(order),
                onDelivered: () => widget.onMarkDelivered(order),
              ),
        ],
      ),
    );
  }
}

class _AttentionOrderRow extends StatelessWidget {
  const _AttentionOrderRow({
    required this.order,
    required this.overdue,
    required this.ready,
    required this.strings,
    required this.locale,
    required this.l10n,
    required this.onOpen,
    required this.onPayment,
    required this.onDelivered,
  });

  final Map<String, Object?> order;
  final bool overdue;
  final bool ready;
  final DashboardStrings strings;
  final String locale;
  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final VoidCallback onPayment;
  final VoidCallback onDelivered;

  @override
  Widget build(BuildContext context) {
    final remaining =
        ((order['total'] as int?) ?? 0) - ((order['paid'] as int?) ?? 0);
    final status = '${order['status'] ?? ''}';
    final garment = strings.garmentSummary('${order['garment_summary'] ?? ''}');
    final date = '${order['due_date'] ?? '—'}';
    final paid = remaining <= 0;
    return DashboardOrderTile(
      title:
          '${dashboardBillLabel(order, l10n)} · ${order['customer_name'] ?? ''}',
      subtitle: [
        if (garment.isNotEmpty) garment,
        date,
      ].join(' · '),
      statusLabel: strings.get(status),
      tone: toneForStatus(status, overdue: overdue),
      amount: formatMoney(remaining < 0 ? 0 : remaining, locale: locale),
      amountCaption: paid ? l10n.dashPaid : l10n.dashAmountDue,
      amountTone: paid ? DashboardTone.good : DashboardTone.due,
      onTap: onOpen,
      actions: Wrap(
        spacing: 4,
        children: [
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(strings.get('openOrder')),
          ),
          if (remaining > 0)
            TextButton.icon(
              onPressed: onPayment,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: Text(strings.get('receivePayment')),
            ),
          if (ready)
            TextButton.icon(
              onPressed: onDelivered,
              icon: const Icon(Icons.check_circle_outline, size: 16),
              label: Text(strings.get('markDelivered')),
            ),
        ],
      ),
    );
  }
}
