import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../dashboard_strings.dart';

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
    final tabs = [
      (widget.strings.get('dueToday'), widget.dueToday),
      (widget.strings.get('overdue'), widget.overdue),
      (widget.strings.get('ready'), widget.ready),
    ];
    final rows = tabs[selectedTab].$2;
    return _SectionCard(
      title: widget.strings.get('attention'),
      trailing: TextButton(
        onPressed: widget.onViewAll,
        child: Text(widget.strings.get('viewAll')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < tabs.length; i++)
                ChoiceChip(
                  label: Text('${tabs[i].$1} (${tabs[i].$2.length})'),
                  selected: selectedTab == i,
                  onSelected: (_) => setState(() => selectedTab = i),
                  selectedColor: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .14),
                  side: BorderSide(
                    color: selectedTab == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(child: Text(widget.strings.get('emptyOrders'))),
            )
          else
            for (final order in rows.take(5))
              _AttentionOrderRow(
                order: order,
                tab: selectedTab,
                strings: widget.strings,
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
    required this.tab,
    required this.strings,
    required this.onOpen,
    required this.onPayment,
    required this.onDelivered,
  });

  final Map<String, Object?> order;
  final int tab;
  final DashboardStrings strings;
  final VoidCallback onOpen;
  final VoidCallback onPayment;
  final VoidCallback onDelivered;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final remaining =
        ((order['total'] as int?) ?? 0) - ((order['paid'] as int?) ?? 0);
    final date = (order['due_date'] as String?) ?? '—';
    final status = (order['status'] as String?) ?? '';
    final colors = Theme.of(context).colorScheme;
    final accent = tab == 1
        ? colors.error
        : tab == 0
        ? colors.tertiary
        : colors.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${order['number'] ?? 'Order'}  ·  ${order['customer_name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${strings.garmentSummary('${order['garment_summary'] ?? ''}')}  ·  $date',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatMoney(remaining, locale: locale),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      strings.get(status),
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 0,
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
                if (tab == 2)
                  TextButton.icon(
                    onPressed: onDelivered,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(strings.get('markDelivered')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}
