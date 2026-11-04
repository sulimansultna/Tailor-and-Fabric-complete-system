import 'package:flutter/material.dart';

import '../dashboard_strings.dart';

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
    if (raw == null || raw.isEmpty) {
      return '—';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final day = DateUtils.dateOnly(parsed.toLocal());
    final today = DateUtils.dateOnly(now);
    if (day == today) return strings.get('today');
    if (day == today.add(const Duration(days: 1))) {
      return strings.get('tomorrow');
    }
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }

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
                  strings.get('upcoming'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: Text(strings.get('viewAll')),
              ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(child: Text(strings.get('emptyDeliveries'))),
            )
          else
            for (final row in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .tertiaryContainer,
                  child: Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
                title: Text('${row['customer_name']}  ·  ${row['number']}'),
                subtitle: Text(
                  '${strings.garmentSummary('${row['garment_summary'] ?? ''}')}  ·  ${_label(context, row['due_date'] as String?)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenCustomer(row),
              ),
        ],
      ),
    ),
  );
}
