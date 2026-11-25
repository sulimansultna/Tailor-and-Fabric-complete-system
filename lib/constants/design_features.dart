import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/garment.dart';
import '../widgets/design_feature_drawing.dart';

const Map<Garment, List<String>> garmentDesignFeatureKeys = {
  Garment.shalwar: [
    'roundHem',
    'straightHem',
    'plainSleeve',
    'cuff',
    'collar',
    'halfBand',
    'fullBand',
    'frontPlacket',
    'chestPocket',
    'sidePocket',
    'roundNeck',
    'straightNeck',
    'indianNeck',
    'shalwarPocket',
    'plainStitch',
    'doubleStitch',
    'specialStitch',
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
  'roundHem' => l10n.designRoundHem,
  'straightHem' => l10n.designStraightHem,
  'plainSleeve' => l10n.designPlainSleeve,
  'halfBand' => l10n.designHalfBand,
  'fullBand' => l10n.designFullBand,
  'indianNeck' => l10n.designIndianNeck,
  'shalwarPocket' => l10n.designShalwarPocket,
  'plainStitch' => l10n.designPlainStitch,
  'doubleStitch' => l10n.designDoubleStitch,
  'specialStitch' => l10n.designSpecialStitch,
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

// Selecting an alternative clears only the other choices in that same group.
// Unchecking a choice leaves the group empty rather than inventing a default.
void setDesignFeatureChoice(Map<String, bool> choices, String key, bool value) {
  if (value) {
    for (final group in const [
      ['roundHem', 'straightHem'],
      ['plainSleeve', 'cuff'],
      ['collar', 'halfBand', 'fullBand'],
      ['roundNeck', 'straightNeck', 'indianNeck'],
      ['plainStitch', 'doubleStitch', 'specialStitch'],
    ]) {
      if (group.contains(key)) {
        for (final other in group) {
          if (other != key) choices[other] = false;
        }
      }
    }
  }
  choices[key] = value;
}

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
          final tileWidth = constraints.maxWidth >= 260
              ? (constraints.maxWidth - 8) / 2
              : constraints.maxWidth;
          return Wrap(
            textDirection: TextDirection.ltr,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in keys)
                Semantics(
                  label: designFeatureLabel(l10n, key),
                  checked: choices[key] ?? false,
                  child: InkWell(
                    key: ValueKey('design-choice-$key'),
                    onTap: () => onChanged(key, !(choices[key] ?? false)),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
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
                      child: Column(
                        children: [
                          Row(
                            textDirection: TextDirection.ltr,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: FittedBox(
                                    child: DesignFeatureDrawing(feature: key),
                                  ),
                                ),
                              ),
                              Checkbox(
                                value: choices[key] ?? false,
                                onChanged: (value) =>
                                    onChanged(key, value ?? false),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              designFeatureLabel(l10n, key),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
