import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/shop_database.dart';
import '../../../dialogs/measurement_dialog.dart';
import '../../../dialogs/measurement_history_dialog.dart';
import '../../../dialogs/order_dialog.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../../../models/garment.dart';

class GarmentCard extends StatefulWidget {
  const GarmentCard({
    super.key,
    required this.database,
    required this.customer,
    required this.garment,
  });
  final ShopDatabase database;
  final Map<String, Object?> customer;
  final Garment garment;

  @override
  State<GarmentCard> createState() => _GarmentCardState();
}

class _GarmentCardState extends State<GarmentCard> {
  List<Map<String, Object?>> profiles = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.database.measurements(
      widget.customer['id'] as int,
      widget.garment.key,
    );
    if (!mounted) return;
    setState(() {
      profiles = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final active = profiles
        .where((profile) => profile['active'] == 1)
        .firstOrNull;
    final profileCount = profiles.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 66,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Image.asset(
                    widget.garment.imageAsset,
                    fit: BoxFit.contain,
                    semanticLabel: localizedGarment(context, widget.garment),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    localizedGarment(context, widget.garment),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (loading)
              const LinearProgressIndicator(minHeight: 2)
            else ...[
              Row(
                children: [
                  Icon(
                    active == null
                        ? Icons.info_outline
                        : Icons.check_circle_outline,
                    size: 17,
                    color: active == null
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      active == null
                          ? l10n.noMeasurementsYet
                          : l10n.measurementsSaved,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (active != null) ...[
                const SizedBox(height: 5),
                Text(
                  '${active['profile_name']} · ${l10n.profileCount(profileCount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.updatedDate(
                    formatDate(active['updated_at'] as String, locale: locale),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 2,
              children: [
                TextButton.icon(
                  onPressed: () => showMeasurementHistoryDialog(
                    context,
                    widget.database,
                    widget.customer,
                    widget.garment,
                  ),
                  icon: const Icon(Icons.straighten_outlined, size: 18),
                  label: Text(l10n.viewMeasurements),
                ),
                TextButton.icon(
                  onPressed: () => showMeasurementDialog(
                    context,
                    widget.database,
                    widget.customer,
                    widget.garment,
                    existing: active,
                    onSaved: _load,
                  ),
                  icon: Icon(
                    active == null ? Icons.add : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: Text(
                    active == null ? l10n.addMeasurements : l10n.edit,
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => showOrderDialog(
                  context,
                  widget.database,
                  widget.customer,
                  garment: widget.garment,
                ),
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: Text(l10n.newOrder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
