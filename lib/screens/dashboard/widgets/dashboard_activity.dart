import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../dashboard_strings.dart';
import 'dashboard_panel.dart';

class TodayDeliveriesSection extends StatelessWidget {
  const TodayDeliveriesSection({
    super.key,
    required this.rows,
    required this.strings,
    required this.onOpen,
    required this.onViewAll,
  });

  final List<Map<String, Object?>> rows;
  final DashboardStrings strings;
  final ValueChanged<Map<String, Object?>> onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DashboardPanel(
      title: l10n.dashTodayDeliveries,
      subtitle: l10n.toHandOverToday,
      accent: const Color(0xffea580c),
      trailing: TextButton(onPressed: onViewAll, child: Text(l10n.viewAll)),
      child: rows.isEmpty
          ? _EmptyNote(text: l10n.dashEmptyToday)
          : Column(
              children: [
                for (final row in rows.take(5))
                  _WorkRow(
                    order: row,
                    strings: strings,
                    locale: locale,
                    overdue: false,
                    onOpen: () => onOpen(row),
                  ),
              ],
            ),
    );
  }
}

class RecentOrdersSection extends StatelessWidget {
  const RecentOrdersSection({
    super.key,
    required this.rows,
    required this.strings,
    required this.onOpen,
    required this.onViewAll,
  });

  final List<Map<String, Object?>> rows;
  final DashboardStrings strings;
  final ValueChanged<Map<String, Object?>> onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DashboardPanel(
      title: l10n.dashRecentOrders,
      accent: const Color(0xff2563eb),
      trailing: TextButton(onPressed: onViewAll, child: Text(l10n.viewAll)),
      child: rows.isEmpty
          ? _EmptyNote(text: l10n.dashEmptyRecent)
          : Column(
              children: [
                for (final row in rows)
                  _WorkRow(
                    order: row,
                    strings: strings,
                    locale: locale,
                    overdue: false,
                    onOpen: () => onOpen(row),
                  ),
              ],
            ),
    );
  }
}

class LowStockSection extends StatelessWidget {
  const LowStockSection({
    super.key,
    required this.rows,
    required this.onOpenFabric,
  });

  final List<Map<String, Object?>> rows;
  final VoidCallback onOpenFabric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tone = dashboardToneColor(context, DashboardTone.warning);
    return DashboardPanel(
      title: l10n.dashLowFabric,
      accent: const Color(0xffea580c),
      trailing: TextButton(onPressed: onOpenFabric, child: Text(l10n.fabric)),
      child: rows.isEmpty
          ? _EmptyNote(text: l10n.dashEmptyLowFabric)
          : Column(
              children: [
                for (final row in rows.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: InkWell(
                        onTap: onOpenFabric,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: tone),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${row['name'] ?? ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${row['code'] ?? ''} · ${_meters(row['available'])} / ${_meters(row['low_stock'])} ${l10n.fabricFormMeter}',
                                      textDirection: TextDirection.ltr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              StatusChip(
                                label: l10n.dashLowLabel,
                                tone: DashboardTone.warning,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WorkRow extends StatelessWidget {
  const _WorkRow({
    required this.order,
    required this.strings,
    required this.locale,
    required this.overdue,
    required this.onOpen,
  });

  final Map<String, Object?> order;
  final DashboardStrings strings;
  final String locale;
  final bool overdue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = '${order['status'] ?? ''}';
    final remaining =
        ((order['total'] as int?) ?? 0) - ((order['paid'] as int?) ?? 0);
    final garment = strings.garmentSummary('${order['garment_summary'] ?? ''}');
    final customer = '${order['customer_name'] ?? ''}';
    final paid = remaining <= 0;
    return DashboardOrderTile(
      title: dashboardBillLabel(order, l10n),
      subtitle: [
        if (customer.isNotEmpty) customer,
        if (garment.isNotEmpty) garment,
      ].join(' · '),
      statusLabel: strings.get(status),
      tone: toneForStatus(status, overdue: overdue),
      amount: formatMoney(remaining < 0 ? 0 : remaining, locale: locale),
      amountCaption: paid ? l10n.dashPaid : l10n.dashAmountDue,
      amountTone: paid ? DashboardTone.good : DashboardTone.due,
      onTap: onOpen,
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}

String _meters(Object? value) {
  final quantity = (value as num? ?? 0).toDouble();
  if (quantity == quantity.roundToDouble()) {
    return quantity.toStringAsFixed(0);
  }
  return quantity
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String dashboardMeters(double value) => _meters(value);
