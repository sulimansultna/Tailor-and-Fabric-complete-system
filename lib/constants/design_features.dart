import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/garment.dart';

const Map<Garment, List<String>> garmentDesignFeatureKeys = {
  Garment.shalwar: [
    'cuff',
    'collar',
    'belt',
    'frontPlacket',
    'chestPocket',
    'sidePocket',
    'roundNeck',
    'straightNeck',
  ],
  Garment.waistcoat: [
    'collar',
    'buttons',
    'lining',
    'chestPocket',
    'sidePocket',
    'backBelt',
    'frontPlacket',
    'roundedHem',
  ],
  Garment.coat: [
    'collar',
    'cuff',
    'buttons',
    'lining',
    'chestPocket',
    'sidePocket',
    'vent',
    'lapels',
  ],
};

String designFeatureLabel(AppLocalizations l10n, String key) => switch (key) {
  'cuff' => l10n.designCuff,
  'collar' => l10n.designCollar,
  'belt' => l10n.designBelt,
  'frontPlacket' => l10n.designFrontPlacket,
  'chestPocket' => l10n.designChestPocket,
  'sidePocket' => l10n.designSidePocket,
  'roundNeck' => l10n.designRoundNeck,
  'straightNeck' => l10n.designStraightNeck,
  'buttons' => l10n.designButtons,
  'lining' => l10n.designLining,
  'backBelt' => l10n.designBackBelt,
  'roundedHem' => l10n.designRoundedHem,
  'vent' => l10n.designVent,
  'lapels' => l10n.designLapels,
  _ => key,
};

IconData designFeatureIcon(String key) => switch (key) {
  'cuff' => Icons.dry_cleaning_outlined,
  'collar' || 'roundNeck' || 'straightNeck' => Icons.checkroom_outlined,
  'belt' || 'backBelt' => Icons.straighten_outlined,
  'frontPlacket' || 'buttons' => Icons.radio_button_checked_outlined,
  'chestPocket' || 'sidePocket' => Icons.inventory_2_outlined,
  'lining' => Icons.layers_outlined,
  'roundedHem' || 'vent' => Icons.gesture_outlined,
  'lapels' => Icons.style_outlined,
  _ => Icons.checkroom_outlined,
};

Map<String, bool> decodeDesignFeatureChoices(Object? raw) {
  Object? decoded = raw;
  if (decoded is String) {
    try {
      decoded = jsonDecode(decoded);
    } on FormatException {
      return {};
    }
  }
  if (decoded is! Map) return {};
  return {
    for (final entry in decoded.entries)
      entry.key.toString(): entry.value == true || entry.value == 'true',
  };
}

Widget designFeaturePicker(
  BuildContext context, {
  required AppLocalizations l10n,
  required Garment garment,
  required Map<String, bool> choices,
  required void Function(String key, bool value) onChanged,
}) {
  final keys = garmentDesignFeatureKeys[garment] ?? const <String>[];
  if (keys.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l10n.designChoices, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, constraints) {
          final tileWidth = constraints.maxWidth >= 640
              ? (constraints.maxWidth - 8) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in keys)
                Container(
                  width: tileWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(designFeatureIcon(key), size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          designFeatureLabel(l10n, key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: Text(l10n.optionNo),
                        selected: !(choices[key] ?? false),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => onChanged(key, false),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: Text(l10n.optionYes),
                        selected: choices[key] ?? false,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => onChanged(key, true),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
