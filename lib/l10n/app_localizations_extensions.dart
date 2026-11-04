import 'package:flutter/widgets.dart';

import '../models/garment.dart';
import 'generated/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

String localizedGarment(BuildContext context, Garment garment) =>
    switch (garment) {
      Garment.shalwar => context.l10n.shalwar,
      Garment.waistcoat => context.l10n.waistcoat,
      Garment.coat => context.l10n.coat,
    };

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
    switch (value) {
      'Kameez length' => context.l10n.kameezLength,
      'Shoulder width' => context.l10n.shoulderWidth,
      'Sleeve length' => context.l10n.sleeveLength,
      'Chest' => context.l10n.chest,
      'Waist' => context.l10n.waist,
      'Hip / seat' => context.l10n.hipSeat,
      'Neck / collar' => context.l10n.neckCollar,
      'Neck' => context.l10n.neck,
      'Upper arm' => context.l10n.upperArm,
      'Cuff / wrist' => context.l10n.cuffWrist,
      'Shalwar length' => context.l10n.shalwarLength,
      'Shalwar waist' => context.l10n.shalwarWaist,
      'Thigh' => context.l10n.thigh,
      'Bottom opening' => context.l10n.bottomOpening,
      'Waistcoat length' => context.l10n.waistcoatLength,
      'Armhole' => context.l10n.armhole,
      'Coat length' => context.l10n.coatLength,
      'Wrist / sleeve opening' => context.l10n.wristSleeveOpening,
      'Additional notes' => context.l10n.additionalNotes,
      _ => value,
    };

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
