import 'dart:convert';

import 'package:flutter/material.dart';
import '../commands/app_commands.dart';

import '../widgets/responsive_layout.dart';
import '../widgets/measurement_form_layout.dart';

import '../data/shop_database.dart';
import '../models/garment.dart';
import '../constants/measurement_fields.dart';
import '../constants/design_features.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/app_localizations_extensions.dart';

Future<void> showMeasurementDialog(
  BuildContext context,
  ShopDatabase db,
  Map<String, Object?> customer,
  Garment garment, {
  Map<String, Object?>? existing,
  required Future<void> Function() onSaved,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final profileData = existing == null
      ? <String, Object?>{}
      : (jsonDecode(existing['data'] as String) as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
  final values = <String, String>{
    for (final entry in profileData.entries)
      if (entry.key != 'Design choices' && entry.value is! Map)
        entry.key: entry.value?.toString() ?? '',
  };
  final designChoices = decodeDesignFeatureChoices(
    profileData['Design choices'],
  );
  final controllers = <String, TextEditingController>{
    for (final field in measurementFields[garment]!)
      field.$1: TextEditingController(text: values[field.$1] ?? ''),
  };
  final name = TextEditingController(
    text: existing == null ? 'Standard' : existing['profile_name'] as String,
  );
  final notes = TextEditingController(text: values['Additional notes'] ?? '');
  String unit = existing == null ? 'in' : existing['unit'] as String;
  final originalValues = [name.text, notes.text, unit, for (final value in controllers.values) value.text, jsonEncode(designChoices)].join('|');
  Future<void> closeMeasurements(BuildContext ctx) async {
    final current = [name.text, notes.text, unit, for (final value in controllers.values) value.text, jsonEncode(designChoices)].join('|');
    if (current != originalValues && !await confirmCommandDiscard(ctx)) return;
    if (ctx.mounted) Navigator.pop(ctx);
  }
  await showResponsiveDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.straighten_rounded,
                color: Theme.of(ctx).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l10n.measurementsTitle(
                  existing == null ? l10n.add : l10n.edit,
                  localizedGarment(context, garment),
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        content: SizedBox(
          width: (MediaQuery.sizeOf(ctx).width - 96).clamp(0.0, 1040.0),
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 520;
                final colors = Theme.of(context).colorScheme;
                Widget measurementsPanel() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.measurementsHeading,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      for (final field in measurementFields[garment]!)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: colors.outlineVariant),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  localizedMeasurementLabel(context, field.$1),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 106,
                                child: TextField(
                                  controller: controllers[field.$1],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.center,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    suffixText: unit,
                                    isDense: true,
                                    filled: true,
                                    fillColor: colors.surfaceContainerLow,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 10,
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
                Widget designPanel() => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: designFeaturePicker(
                    context,
                    l10n: l10n,
                    garment: garment,
                    choices: designChoices,
                    onChanged: (key, value) =>
                        setState(() => designChoices[key] = value),
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${l10n.customer}: ${customer['name'] ?? ''}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${l10n.mobileNumber}: ${customer['phone'] ?? '-'}',
                          ),
                          Text(
                            '${l10n.customerId}: ${customer['customer_code'] ?? customer['id'] ?? '-'}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isWide)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: name,
                              textInputAction: TextInputAction.next,
                              decoration: _measurementInputDecoration(
                                context,
                                label: l10n.profileName,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 190,
                            child: _unitSelector(
                              context,
                              unit: unit,
                              inches: l10n.inches,
                              centimeters: l10n.centimeters,
                              onChanged: (value) =>
                                  setState(() => unit = value),
                            ),
                          ),
                        ],
                      )
                    else ...[
                      TextField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: _measurementInputDecoration(
                          context,
                          label: l10n.profileName,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _unitSelector(
                        context,
                        unit: unit,
                        inches: l10n.inches,
                        centimeters: l10n.centimeters,
                        onChanged: (value) => setState(() => unit = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: .42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: .16),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.measurementInstructions,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    MeasurementFormLayout(
                      garment: garment,
                      measurements: measurementsPanel(),
                      design: designPanel(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: _measurementInputDecoration(
                        context,
                        label: l10n.additionalNotes,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => closeMeasurements(ctx),
            child: Text(l10n.cancel),
          )),
          CommandButton(id: 'action.save', child: FilledButton(
            onPressed: () async {
              final data = <String, String>{
                for (final e in controllers.entries)
                  if (e.value.text.trim().isNotEmpty)
                    e.key: e.value.text.trim(),
                'Additional notes': notes.text.trim(),
              };
              final savedData = <String, Object?>{
                ...data,
                'Design choices': Map<String, bool>.from(designChoices),
              };
              await db.saveMeasurement(
                customerId: customer['id'] as int,
                garment: garment.key,
                name: name.text.trim().isEmpty ? 'Standard' : name.text.trim(),
                unit: unit,
                json: jsonEncode(savedData),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await onSaved();
            },
            child: Text(l10n.saveMeasurements),
          )),
        ],
      ),
    ),
  );
  for (final c in controllers.values) {
    c.dispose();
  }
  name.dispose();
  notes.dispose();
}

InputDecoration _measurementInputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? suffix,
}) {
  final colors = Theme.of(context).colorScheme;
  final borderRadius = BorderRadius.circular(12);
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    filled: true,
    fillColor: colors.surfaceContainerLow,
    border: border(colors.outlineVariant),
    enabledBorder: border(colors.outlineVariant),
    focusedBorder: border(colors.primary, 1.8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  );
}

Widget _unitSelector(
  BuildContext context, {
  required String unit,
  required String inches,
  required String centimeters,
  required ValueChanged<String> onChanged,
}) => DropdownButtonFormField<String>(
  isExpanded: true,
  initialValue: unit,
  decoration: _measurementInputDecoration(
    context,
    label: context.l10n.measurementUnit,
  ),
  items: [
    DropdownMenuItem(value: 'in', child: Text(inches)),
    DropdownMenuItem(value: 'cm', child: Text(centimeters)),
  ],
  onChanged: (value) {
    if (value != null) onChanged(value);
  },
);
