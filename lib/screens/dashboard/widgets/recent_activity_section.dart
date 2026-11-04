import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../dashboard_strings.dart';

class RecentActivitySection extends StatelessWidget {
  const RecentActivitySection({
    super.key,
    required this.rows,
    required this.strings,
  });

  final List<Map<String, Object?>> rows;
  final DashboardStrings strings;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffe3e8ee)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('activity'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xff17253b),
              ),
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text(strings.get('emptyActivity'))),
              )
            else
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_icon(row['description'] as String?)),
                  title: Text(
                    strings.l10n.activityEntry(
                      strings.get(_activityKey(row['description'] as String?)),
                      '${row['customer_name']}',
                    ),
                  ),
                  subtitle: Text(
                    strings.l10n.referenceAndDate(
                      '${row['reference'] ?? ''}',
                      _time(context, row['happened_at'] as String?),
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  trailing: row['amount'] is int
                      ? Text(
                          formatMoney(row['amount'] as int, locale: locale),
                          textDirection: TextDirection.ltr,
                        )
                      : null,
                ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String? type) => switch (type) {
    'Payment received' => Icons.payments_outlined,
    'Order ready' => Icons.check_circle_outline,
    'Order delivered' => Icons.local_shipping_outlined,
    _ => Icons.receipt_long_outlined,
  };

  String _time(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) {
      return formatDate(
        raw,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
    }
    final date = MaterialLocalizations.of(context).formatShortDate(parsed);
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$date · $hour:$minute';
  }

  String _activityKey(String? type) => switch (type) {
    'Payment received' => 'paymentActivity',
    'Order ready' => 'readyActivity',
    'Order delivered' => 'deliveredActivity',
    _ => 'newOrderActivity',
  };
}
