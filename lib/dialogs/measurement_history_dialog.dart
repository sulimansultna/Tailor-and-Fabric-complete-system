import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';
import '../models/garment.dart';
import 'measurement_dialog.dart';

Future<void> showMeasurementHistoryDialog(
  BuildContext context,
  ShopDatabase db,
  Map<String, Object?> customer,
  Garment garment,
) async {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final rows = await db.measurements(customer['id'] as int, garment.key);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.measurementProfiles(localizedGarment(context, garment))),
      content: SizedBox(
        width: 440,
        child: rows.isEmpty
            ? Text(l10n.noProfiles)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final row in rows)
                    ListTile(
                      leading: Icon(
                        row['active'] == 1 ? Icons.check_circle : Icons.history,
                      ),
                      title: Text(row['profile_name'] as String),
                      subtitle: Text(
                        '${row['unit']} · ${formatDate(row['updated_at'] as String, locale: locale)}',
                      ),
                      trailing: TextButton(
                        onPressed: () => showMeasurementDialog(
                          context,
                          db,
                          customer,
                          garment,
                          existing: row,
                          onSaved: () async {},
                        ),
                        child: Text(l10n.duplicateEdit),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.close),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            showMeasurementDialog(
              context,
              db,
              customer,
              garment,
              onSaved: () async {},
            );
          },
          child: Text(l10n.newProfile),
        ),
      ],
    ),
  );
}
