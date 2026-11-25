import 'package:flutter/widgets.dart';

import '../models/garment.dart';
import 'generated/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

String localizedGarment(BuildContext context, Garment garment) =>
    context.l10n.garmentName(garment);

String localizedStatus(BuildContext context, String value) => switch (value) {
  'Received' => context.l10n.received,
  'Cutting' => context.l10n.cutting,
  'Stitching' => context.l10n.stitching,
  'Ready' => context.l10n.ready,
  'Delivered' => context.l10n.delivered,
  'Cancelled' => context.l10n.cancelled,
  _ => value,
};

String localizedGarmentKey(BuildContext context, String value) =>
    switch (value) {
      'shalwar' => context.l10n.shalwar,
      'waistcoat' => context.l10n.waistcoat,
      'coat' => context.l10n.coat,
      _ => value,
    };

String localizedMeasurementLabel(BuildContext context, String value) =>
    context.l10n.measurementLabel(value);

extension AppLocalizationsLabels on AppLocalizations {
  String garmentName(Garment garment) => switch (garment) {
    Garment.shalwar => shalwar,
    Garment.waistcoat => waistcoat,
    Garment.coat => coat,
  };

  String measurementLabel(String value) => switch (value) {
    'Kameez length' => kameezLength,
    'Shoulder width' => shoulderWidth,
    'Sleeve length' => sleeveLength,
    'Chest' => chest,
    'Hem width' => hemWidth,
    'Waist' => waist,
    'Hip / seat' => hipSeat,
    'Neck / collar' => neckCollar,
    'Neck' => neck,
    'Upper arm' => upperArm,
    'Cuff / wrist' => cuffWrist,
    'Shalwar length' => shalwarLength,
    'Shalwar waist' => shalwarWaist,
    'Thigh' => thigh,
    'Bottom opening' => bottomOpening,
    'Waistcoat length' => waistcoatLength,
    'Armhole' => armhole,
    'Coat length' => coatLength,
    'Wrist / sleeve opening' => wristSleeveOpening,
    'Additional notes' => additionalNotes,
    _ => value,
  };
}

String localizedMeasurementHint(BuildContext context, String value) =>
    switch (value) {
      'Finished garment length' => context.l10n.finishedGarmentLength,
      'Finished sleeve length' => context.l10n.finishedSleeveLength,
      'Width' => context.l10n.width,
      'Circumference' => context.l10n.circumference,
      _ => value,
    };

String localizedPaymentMethod(BuildContext context, String value) =>
    switch (value) {
      'Cash' => context.l10n.cash,
      'Bank transfer' => context.l10n.bankTransfer,
      'Other' => context.l10n.other,
      _ => value,
    };
