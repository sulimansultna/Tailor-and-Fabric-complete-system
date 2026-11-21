import 'package:flutter/material.dart';

import '../../../l10n/app_localizations_extensions.dart';
import '../dashboard_strings.dart';
import 'dashboard_panel.dart';

class UpcomingDeliveriesSection extends StatelessWidget {
  const UpcomingDeliveriesSection({
    super.key,
    required this.rows,
    required this.now,
    required this.strings,
    required this.onOpenCustomer,
    required this.onViewAll,
  });

  final List<Map<String, Object?>> rows;
  final DateTime now;
  final DashboardStrings strings;
  final ValueChanged<Map<String, Object?>> onOpenCustomer;
  final VoidCallback onViewAll;

  String _label(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = DateUtils.dateOnly(parsed.toLocal());
    final today = DateUtils.dateOnly(now);
    if (day == today) return strings.get('today');
    if (day == today.add(const Duration(days: 1))) {
      return strings.get('tomorrow');
    }
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DashboardPanel(
      title: strings.get('upcoming'),
      accent: const Color(0xff0f766e),
      trailing: TextButton(
        onPressed: onViewAll,
        child: Text(strings.get('viewAll')),
      ),
      child: rows.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  strings.get('emptyDeliveries'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (final row in rows)
                  DashboardOrderTile(
                    title: dashboardBillLabel(row, l10n),
                    subtitle:
                        '${row['customer_name'] ?? ''} · ${strings.garmentSummary('${row['garment_summary'] ?? ''}')}',
                    statusLabel: _label(context, row['due_date'] as String?),
                    tone: _tone(row['due_date'] as String?),
                    onTap: () => onOpenCustomer(row),
                  ),
              ],
            ),
    );
  }

  DashboardTone _tone(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return DashboardTone.neutral;
    final day = DateUtils.dateOnly(parsed.toLocal());
    final today = DateUtils.dateOnly(now);
    if (day == today) return DashboardTone.warning;
    if (day.isBefore(today)) return DashboardTone.due;
    return DashboardTone.good;
  }
}
