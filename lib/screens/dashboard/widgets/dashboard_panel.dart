import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

enum DashboardTone { good, warning, due, neutral }

Color dashboardToneColor(BuildContext context, DashboardTone tone) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (tone) {
    DashboardTone.good =>
      dark ? const Color(0xff4ade80) : const Color(0xff15803d),
    DashboardTone.warning =>
      dark ? const Color(0xfffdba74) : const Color(0xffc2410c),
    DashboardTone.due =>
      dark ? const Color(0xfffca5a5) : const Color(0xffb42318),
    DashboardTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

DashboardTone toneForStatus(String status, {bool overdue = false}) {
  if (overdue) return DashboardTone.due;
  return switch (status) {
    'Ready' || 'Delivered' => DashboardTone.good,
    'Cancelled' => DashboardTone.due,
    _ => DashboardTone.warning,
  };
}

String dashboardBillLabel(Map<String, Object?> order, AppLocalizations l10n) {
  final bill = '${order['bill_number'] ?? ''}'.trim();
  if (bill.isNotEmpty) return '${l10n.billNumber} $bill';
  final number = '${order['number'] ?? ''}'.trim();
  if (number.isNotEmpty) return number;
  return l10n.billNotAssigned;
}

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .22 : .05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accent != null) ...[
                  Container(
                    width: 4,
                    height: 28,
                    margin: const EdgeInsetsDirectional.only(end: 8, top: 2),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
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
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});

  final String label;
  final DashboardTone tone;

  @override
  Widget build(BuildContext context) {
    final color = dashboardToneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DashboardOrderTile extends StatelessWidget {
  const DashboardOrderTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.tone,
    this.amount,
    this.amountCaption,
    this.amountTone,
    this.onTap,
    this.actions,
  });

  final String title;
  final String subtitle;
  final String statusLabel;
  final DashboardTone tone;
  final String? amount;
  final String? amountCaption;
  final DashboardTone? amountTone;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = dashboardToneColor(context, tone);
    final moneyTone = amountTone ?? tone;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      margin: const EdgeInsetsDirectional.only(end: 8, top: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(label: statusLabel, tone: tone),
                        if (amount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            amount!,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              color: dashboardToneColor(context, moneyTone),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (amountCaption != null)
                            Text(
                              amountCaption!,
                              style: TextStyle(
                                color: dashboardToneColor(context, moneyTone),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (actions != null) ...[
                  const SizedBox(height: 4),
                  actions!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
