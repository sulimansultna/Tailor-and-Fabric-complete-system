import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../commands/app_commands.dart';

import '../widgets/responsive_layout.dart';
import '../widgets/measurement_form_layout.dart';

import '../core/app_date_picker.dart';
import '../core/calendar_service.dart';

import '../core/formatters.dart';
import '../constants/measurement_fields.dart';
import '../constants/design_features.dart';
import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/garment.dart';
import '../reports/order_document_service.dart';

Future<void> showOrderDialog(
  BuildContext context,
  ShopDatabase db,
  Map<String, Object?> customer, {
  Garment? garment,
  int? draftId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  Map<String, Object?> draftPayload = const {};
  if (draftId != null) {
    final draft = await db.orderDraft(draftId);
    final raw = draft?['payload']?.toString();
    if (raw == null) throw StateError('Draft not found.');
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      draftPayload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
  }
  final selectedCustomer = Map<String, Object?>.from(customer);
  final customerChoices = await db.searchCustomers('', includeArchived: true);
  if (!customerChoices.any((row) => row['id'] == selectedCustomer['id'])) {
    customerChoices.insert(0, selectedCustomer);
  }
  final advance = TextEditingController(
    text: draftPayload['advance']?.toString() ?? '0',
  );
  final manualBillNumber = TextEditingController(
    text: draftPayload['billNumber']?.toString() ?? '',
  );
  final extra = TextEditingController(
    text: draftPayload['extra']?.toString() ?? '0',
  );
  final discount = TextEditingController(
    text: draftPayload['discount']?.toString() ?? '0',
  );
  final due = TextEditingController(
    text: draftPayload['due']?.toString() ?? '',
  );
  final notes = TextEditingController(
    text: draftPayload['notes']?.toString() ?? '',
  );
  final advanceFocus = FocusNode();
  final dueFocus = FocusNode();
  final notesFocus = FocusNode();
  final lines = <_OrderEntry>[];
  String? formError;
  String? billNumberError;
  bool saving = false;
  final savedLines =
      (draftPayload['lines'] as List?)
          ?.whereType<Map>()
          .map(
            (row) => row.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList() ??
      const <Map<String, Object?>>[];
  final first = _OrderEntry(
    savedLines.isNotEmpty
        ? (garmentFromKey(savedLines.first['garment']) ?? Garment.shalwar)
        : (garment ?? Garment.shalwar),
  );
  lines.add(first);
  first.profiles = await db.measurements(
    selectedCustomer['id'] as int,
    first.garment.key,
  );
  if (first.profiles.isNotEmpty) {
    final active =
        first.profiles.where((e) => e['active'] == 1).firstOrNull ??
        first.profiles.first;
    first.profile = (active['profile_name'] as String).trim();
    first.snapshot = _measurementSnapshot(active['data'] as String);
    first.designChoices.addAll(
      _measurementDesignChoices(active['data'] as String),
    );
    first.measurementUnit = active['unit']?.toString() ?? 'in';
  }
  void hydrateEntry(_OrderEntry row, Map<String, Object?> saved) {
    row.count.text = saved['count']?.toString() ?? '1';
    row.price.text = saved['price']?.toString() ?? '0';
    row.profile = saved['profile']?.toString();
    row.measurementUnit = saved['measurementUnit']?.toString() ?? 'in';
    final snapshot = saved['snapshot'];
    row.snapshot = snapshot is Map
        ? snapshot.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : const {};
    row.designChoices
      ..clear()
      ..addAll(
        (saved['designChoices'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value == true),
            ) ??
            const <String, bool>{},
      );
    row.stitchingInstructions.text = saved['instructions']?.toString() ?? '';
    row.ownership = saved['ownership']?.toString() ?? 'customer';
    row.fabricId = (saved['fabricId'] as num?)?.toInt();
    row.fabricQuantity.text = saved['fabricQuantity']?.toString() ?? '';
    row.outsideDescription.text = saved['outsideDescription']?.toString() ?? '';
  }

  if (savedLines.isNotEmpty) {
    hydrateEntry(first, savedLines.first);
    for (final saved in savedLines.skip(1)) {
      final row = _OrderEntry(
        garmentFromKey(saved['garment']) ?? Garment.shalwar,
      );
      row.profiles = await db.measurements(
        selectedCustomer['id'] as int,
        row.garment.key,
      );
      hydrateEntry(row, saved);
      lines.add(row);
    }
  }
  var fabrics = await db.fabrics();
  if (!context.mounted) return;

  int cents(TextEditingController c) =>
      ((double.tryParse(normalizeLocalizedDigits(c.text)) ?? 0) * 100).round();
  double quantityValue(TextEditingController c) =>
      double.tryParse(normalizeLocalizedDigits(c.text)) ?? 0;
  int fabricCharge(_OrderEntry row) {
    if (row.ownership != 'shop' || row.fabricId == null) return 0;
    final fabric = fabrics.where((f) => f['id'] == row.fabricId).firstOrNull;
    if (fabric == null) return 0;
    final price = fabric['selling_price'] as int? ?? 0;
    final quantityMilli = (quantityValue(row.fabricQuantity) * 1000).round();
    return (price * quantityMilli + 500) ~/ 1000;
  }

  int garmentTotal() => lines.fold(
    0,
    (sum, row) =>
        sum +
        cents(row.price) *
            (int.tryParse(normalizeLocalizedDigits(row.count.text)) ?? 0),
  );
  int extraValue() => cents(extra);
  int discountValue() => cents(discount);
  int subtotalValue() =>
      garmentTotal() +
      extraValue() +
      lines.fold(0, (sum, row) => sum + fabricCharge(row));
  int totalValue() => math.max(0, subtotalValue() - discountValue()).toInt();
  int paidValue() => cents(advance);
  Map<String, Object?> draftData() => {
    'billNumber': manualBillNumber.text.trim(),
    'advance': advance.text,
    'extra': extra.text,
    'discount': discount.text,
    'due': due.text,
    'notes': notes.text,
    'lines': [
      for (final row in lines)
        {
          'garment': row.garment.key,
          'count': row.count.text,
          'price': row.price.text,
          'profile': row.profile,
          'measurementUnit': row.measurementUnit,
          'snapshot': Map<String, String>.from(row.snapshot),
          'designChoices': Map<String, bool>.from(row.designChoices),
          'instructions': row.stitchingInstructions.text,
          'ownership': row.ownership,
          'fabricId': row.fabricId,
          'fabricQuantity': row.fabricQuantity.text,
          'outsideDescription': row.outsideDescription.text,
        },
    ],
  };

  final detailsScroll = ScrollController();
  final summaryScroll = ScrollController();
  final initialDraftData = jsonEncode(draftData());
  await showResponsiveDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> closeOrder() async {
          if (saving) return;
          if (jsonEncode(draftData()) != initialDraftData && !await confirmCommandDiscard(dialogContext)) return;
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        }
        final dialogSize = ResponsiveLayout.dialogSize(dialogContext);
        final width = dialogSize.width;
        final height = dialogSize.height;
        final locale = Localizations.localeOf(dialogContext).toLanguageTag();
        final total = totalValue();
        final fabricTotal = lines.fold<int>(
          0,
          (sum, row) => sum + fabricCharge(row),
        );
        final paid = paidValue();
        final remaining = total - paid;
        final wide = width >= 960 * ResponsiveLayout.textFactor(dialogContext);
        final lang = Localizations.localeOf(dialogContext).languageCode;
        String word(String key) => _orderWord(lang, key);
        void refresh() => setState(() {});
        void moveTextFocus(int direction) {
          final fields = <FocusNode>[
            for (final row in lines) ...[
              row.countFocus,
              row.priceFocus,
              if (row.ownership == 'customer') row.outsideDescriptionFocus,
              row.fabricQuantityFocus,
            ],
            dueFocus,
            notesFocus,
            advanceFocus,
          ];
          final current = fields.indexWhere((node) => node.hasFocus);
          final next = current < 0
              ? (direction > 0 ? 0 : fields.length - 1)
              : (current + direction + fields.length) % fields.length;
          fields[next].requestFocus();
        }

        List<Map<String, Object?>> fabricsFor(Garment garment) {
          final category = _fabricCategoryForGarment(garment).toLowerCase();
          return fabrics
              .where(
                (fabric) =>
                    fabric['unit'] == 'meter' &&
                    (fabric['category'] as String?)?.trim().toLowerCase() ==
                        category,
              )
              .toList();
        }

        Future<void> loadProfiles(_OrderEntry row) async {
          row.profiles = await db.measurements(
            selectedCustomer['id'] as int,
            row.garment.key,
          );
          if (row.profiles.isEmpty) {
            row.profile = null;
            row.snapshot = {};
            row.designChoices.clear();
          } else {
            final active =
                row.profiles.where((e) => e['active'] == 1).firstOrNull ??
                row.profiles.first;
            row.profile = (active['profile_name'] as String).trim();
            row.snapshot = _measurementSnapshot(active['data'] as String);
            row.designChoices
              ..clear()
              ..addAll(_measurementDesignChoices(active['data'] as String));
            row.measurementUnit = active['unit']?.toString() ?? 'in';
          }
        }

        Future<void> pickDueDate() async {
          final selected = await showAppDatePicker(
            context: dialogContext,
            initialDate:
                DateTime.tryParse(due.text) ?? CalendarService.shopToday(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (selected == null) return;
          due.text = selected.toIso8601String().substring(0, 10);
          refresh();
        }

        Widget orderLine(_OrderEntry row, int index) {
          final selectedFabric = fabrics
              .where((f) => f['id'] == row.fabricId)
              .firstOrNull;
          final unit = selectedFabric?['unit'] == 'meter'
              ? l10n.fabricFormMeter
              : l10n.fabricFormUnitReview(
                  selectedFabric?['unit']?.toString() ?? '',
                );
          final profileNames = row.profiles
              .map((profile) => (profile['profile_name'] as String).trim())
              .where((name) => name.isNotEmpty)
              .toSet()
              .toList();
          if (row.profile != null && !profileNames.contains(row.profile)) {
            row.profile = null;
          }
          final profileItems = [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.noProfileDraftOrder),
            ),
            ...profileNames.map(
              (profileName) => DropdownMenuItem<String?>(
                value: profileName,
                child: Text(profileName),
              ),
            ),
          ];
          return Card(
            key: ObjectKey(row),
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${word('garment')} ${index + 1}',
                          style: Theme.of(dialogContext).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (lines.length > 1)
                        IconButton(
                          tooltip: word('removeGarment'),
                          onPressed: () {
                            setState(() => lines.remove(row));
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => row.dispose(),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  DropdownButtonFormField<Garment>(
                    isExpanded: true,
                    initialValue: row.garment,
                    decoration: InputDecoration(labelText: l10n.garment),
                    items: Garment.values
                        .map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 38,
                                  height: 42,
                                  child: Image.asset(
                                    g.imageAsset,
                                    fit: BoxFit.contain,
                                    semanticLabel: localizedGarment(
                                      dialogContext,
                                      g,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    localizedGarment(dialogContext, g),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (g) async {
                      if (g == null) return;
                      row.garment = g;
                      final garmentFabrics = fabricsFor(g);
                      if (!garmentFabrics.any((f) => f['id'] == row.fabricId)) {
                        row.fabricId =
                            row.ownership == 'shop' && garmentFabrics.isNotEmpty
                            ? garmentFabrics.first['id'] as int
                            : null;
                      }
                      await loadProfiles(row);
                      if (dialogContext.mounted) refresh();
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    key: ValueKey('profiles-$index-${row.garment.key}'),
                    initialValue: row.profile,
                    decoration: InputDecoration(
                      labelText: l10n.measurementProfile,
                    ),
                    items: profileItems,
                    onChanged: (value) {
                      row.profile = value;
                      final p = row.profiles
                          .where((e) => e['profile_name'] == value)
                          .firstOrNull;
                      row.snapshot = p == null
                          ? {}
                          : _measurementSnapshot(p['data'] as String);
                      row.designChoices
                        ..clear()
                        ..addAll(
                          p == null
                              ? const <String, bool>{}
                              : _measurementDesignChoices(p['data'] as String),
                        );
                      row.measurementUnit = p?['unit']?.toString() ?? 'in';
                      refresh();
                    },
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await _reviewOrderMeasurements(
                          dialogContext,
                          db,
                          selectedCustomer,
                          row.garment,
                          profileName: row.profile,
                          measurementUnit: row.measurementUnit,
                          values: row.snapshot,
                          initialDesignChoices: row.designChoices,
                          billNumber: l10n.automaticBillNumber,
                          dueDate: due.text,
                        );
                        if (result == null) return;
                        row.snapshot = result.values;
                        row.measurementUnit = result.unit;
                        row.designChoices
                          ..clear()
                          ..addAll(result.designChoices);
                        refresh();
                      },
                      icon: const Icon(Icons.straighten_outlined),
                      label: Text(l10n.reviewMeasurements),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.count,
                          focusNode: row.countFocus,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: l10n.quantity),
                          onChanged: (_) => refresh(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: row.price,
                          focusNode: row.priceFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.pricePerItem,
                          ),
                          onChanged: (_) => refresh(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: row.stitchingInstructions,
                    maxLines: 1,
                    decoration: InputDecoration(
                      labelText: l10n.stitchingInstructions,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: row.ownership,
                    decoration: InputDecoration(
                      labelText: word('fabricSource'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'shop',
                        child: Text(word('shopFabric')),
                      ),
                      DropdownMenuItem(
                        value: 'customer',
                        child: Text(word('customerFabric')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      row.ownership = value;
                      if (value == 'shop' &&
                          row.fabricId == null &&
                          fabricsFor(row.garment).isNotEmpty) {
                        row.fabricId =
                            fabricsFor(row.garment).first['id'] as int;
                      }
                      refresh();
                    },
                  ),
                  if (row.ownership == 'shop') ...[
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(word('selectFabric')),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: fabricsFor(row.garment).isEmpty
                                ? null
                                : () async {
                                    final id = await _pickOrderFabric(
                                      dialogContext,
                                      fabricsFor(row.garment),
                                      title:
                                          '${localizedGarment(dialogContext, row.garment)} · ${word('shopFabric')}',
                                      searchLabel: word('searchFabric'),
                                      emptyLabel: word('noFabricMatch'),
                                    );
                                    if (id == null) return;
                                    row.fabricId = id;
                                    refresh();
                                  },
                            icon: const Icon(Icons.search),
                            label: Text(
                              selectedFabric == null
                                  ? word('searchFabric')
                                  : '${selectedFabric['code']} · ${selectedFabric['name']} (${(selectedFabric['available'] as num? ?? 0).toStringAsFixed(3)} $unit)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (fabricsFor(row.garment).isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 6),
                        child: Text(
                          word('noCategoryFabric'),
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.fabricQuantity,
                            focusNode: row.fabricQuantityFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '${word('fabricQuantity')} ($unit)',
                              helperText: word('fabricDefaultHint'),
                            ),
                            onChanged: (_) => refresh(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _moneySummaryLine(
                            dialogContext,
                            word('fabricCharge'),
                            formatMoney(fabricCharge(row), locale: locale),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.outsideDescription,
                            focusNode: row.outsideDescriptionFocus,
                            decoration: InputDecoration(
                              labelText: word('outsideFabricName'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: row.fabricQuantity,
                            focusNode: row.fabricQuantityFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: '${word('fabricQuantity')} (Meter)',
                              helperText: word('fabricDefaultHint'),
                            ),
                            onChanged: (_) => refresh(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        Widget details() => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey('draft-customer-${selectedCustomer['id']}'),
              initialValue: selectedCustomer['id'] as int,
              decoration: InputDecoration(labelText: l10n.customer),
              isExpanded: true,
              items: [
                for (final candidate in customerChoices)
                  DropdownMenuItem(
                    value: candidate['id'] as int,
                    child: Text('${candidate['name']} · ${candidate['phone']}'),
                  ),
              ],
              onChanged: saving
                  ? null
                  : (id) async {
                      if (id == null) return;
                      final next = customerChoices
                          .where((candidate) => candidate['id'] == id)
                          .first;
                      selectedCustomer
                        ..clear()
                        ..addAll(next);
                      for (final row in lines) {
                        await loadProfiles(row);
                      }
                      if (dialogContext.mounted) refresh();
                    },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _fieldHeading(
                    dialogContext,
                    l10n.orderDetails,
                    Icons.edit_note_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final row = _OrderEntry(Garment.shalwar);
                    lines.add(row);
                    await loadProfiles(row);
                    if (dialogContext.mounted) refresh();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(word('addGarment')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < lines.length; i++) orderLine(lines[i], i),
            TextField(
              controller: due,
              focusNode: dueFocus,
              readOnly: true,
              onTap: pickDueDate,
              decoration: InputDecoration(
                labelText: l10n.deliveryDate,
                suffixIcon: IconButton(
                  onPressed: pickDueDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              focusNode: notesFocus,
              maxLines: 3,
              decoration: InputDecoration(labelText: l10n.styleOrderNotes),
            ),
          ],
        );

        Widget summary() => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldHeading(
                dialogContext,
                l10n.orderSummary,
                Icons.receipt_long_outlined,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manualBillNumber,
                enabled: !saving,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.billNumber,
                  helperText: l10n.manualBillNumberHelp,
                  errorText: billNumberError,
                  prefixIcon: const Icon(Icons.confirmation_number_outlined),
                ),
                onChanged: (_) => setState(() => billNumberError = null),
              ),
              const SizedBox(height: 10),
              _moneySummaryLine(
                dialogContext,
                word('stitchingTotal'),
                formatMoney(garmentTotal(), locale: locale),
              ),
              _moneySummaryLine(
                dialogContext,
                l10n.fabricAmount,
                formatMoney(fabricTotal, locale: locale),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: extra,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.extraCharge),
                onChanged: (_) => refresh(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: discount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.discount),
                onChanged: (_) => refresh(),
              ),
              _moneySummaryLine(
                dialogContext,
                l10n.discount,
                '-${formatMoney(discountValue(), locale: locale)}',
              ),
              const Divider(height: 24),
              _moneySummaryLine(
                dialogContext,
                l10n.total,
                formatMoney(total, locale: locale),
                prominent: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: advance,
                focusNode: advanceFocus,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.advancePayment,
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
                onChanged: (_) => refresh(),
              ),
              const SizedBox(height: 16),
              _moneySummaryLine(
                dialogContext,
                l10n.remainingBalance,
                formatMoney(math.max(0, remaining).toInt(), locale: locale),
                prominent: true,
                color: remaining < 0
                    ? Theme.of(dialogContext).colorScheme.error
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.advancePaymentLedgerHint,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              if (formError != null) ...[
                const SizedBox(height: 12),
                Text(
                  formError!,
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );

        final appTheme = Theme.of(dialogContext);
        final dialogTheme = appTheme.copyWith(
          inputDecorationTheme: appTheme.inputDecorationTheme.copyWith(
            filled: true,
            fillColor: appTheme.colorScheme.surfaceContainerLow,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: appTheme.colorScheme.outlineVariant,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: appTheme.colorScheme.primary,
                width: 1.8,
              ),
            ),
          ),
        );
        return Theme(
          data: dialogTheme,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: width,
              height: height,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            Icons.content_cut,
                            color: Theme.of(dialogContext)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                draftId == null
                                    ? l10n.newOrderFor(
                                        selectedCustomer['name']?.toString() ??
                                            '',
                                      )
                                    : l10n.editInvoiceTitle(
                                        manualBillNumber.text.trim().isEmpty
                                            ? l10n.automaticBillNumber
                                            : manualBillNumber.text.trim(),
                                      ),
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedCustomer['phone']?.toString() ?? '',
                                textDirection: TextDirection.ltr,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(dialogContext)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: word('previousField'),
                          onPressed: () => moveTextFocus(-1),
                          icon: const Icon(Icons.keyboard_arrow_up),
                        ),
                        IconButton(
                          tooltip: word('nextField'),
                          onPressed: () => moveTextFocus(1),
                          icon: const Icon(Icons.keyboard_arrow_down),
                        ),
                        IconButton(
                          tooltip: l10n.close,
                          onPressed: saving
                              ? null
                              : closeOrder,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SingleChildScrollView(
                                    key: const PageStorageKey('order-details'),
                                    controller: detailsScroll,
                                    child: details(),
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 2,
                                  child: SingleChildScrollView(
                                    key: const PageStorageKey('order-summary'),
                                    controller: summaryScroll,
                                    child: summary(),
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              key: const PageStorageKey('order-details'),
                              controller: detailsScroll,
                              child: Column(
                                children: [
                                  details(),
                                  const SizedBox(height: 20),
                                  summary(),
                                ],
                              ),
                            ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      14,
                      20,
                      14,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        CommandButton(id: 'action.cancel', child: TextButton(
                          onPressed: saving
                              ? null
                              : closeOrder,
                          child: Text(l10n.cancel),
                        )),
                        TextButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  setState(() {
                                    saving = true;
                                    formError = null;
                                  });
                                  try {
                                    await db.saveOrderDraft(
                                      customerId: selectedCustomer['id'] as int,
                                      payload: draftData(),
                                      draftId: draftId,
                                    );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                  } catch (error) {
                                    if (dialogContext.mounted) {
                                      setState(() {
                                        saving = false;
                                        final duplicate = error
                                            .toString()
                                            .toLowerCase()
                                            .contains(
                                              'bill number already in use',
                                            );
                                        billNumberError = duplicate
                                            ? l10n.billNumberAlreadyUsed
                                            : null;
                                        formError = duplicate
                                            ? null
                                            : error.toString();
                                      });
                                    }
                                  }
                                },
                          icon: const Icon(Icons.save_as_outlined),
                          label: Text(l10n.workerSaveDraft),
                        ),
                        CommandButton(id: 'action.save', child: FilledButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (saving) return;
                                  final orderTotal = totalValue();
                                  final advanceAmount = paidValue();
                                  if (orderTotal <= 0 ||
                                      advanceAmount < 0 ||
                                      advanceAmount > orderTotal ||
                                      extraValue() < 0 ||
                                      discountValue() < 0 ||
                                      discountValue() > subtotalValue() ||
                                      lines.any(
                                        (row) =>
                                            (int.tryParse(
                                                      normalizeLocalizedDigits(
                                                        row.count.text,
                                                      ),
                                                    ) ??
                                                    0) <=
                                                0 ||
                                            cents(row.price) < 0,
                                      )) {
                                    setState(
                                      () => formError = l10n.checkOrderAmounts,
                                    );
                                    return;
                                  }
                                  if (lines.any((row) {
                                    final quantity = quantityValue(
                                      row.fabricQuantity,
                                    );
                                    final milli = quantity * 1000;
                                    return quantity < 0 ||
                                        (quantity > 0 &&
                                            (milli - milli.round()).abs() >
                                                .000001) ||
                                        (row.ownership == 'shop' &&
                                            (quantity <= 0 ||
                                                row.fabricId == null));
                                  })) {
                                    setState(
                                      () => formError = word(
                                        'checkFabricAmounts',
                                      ),
                                    );
                                    return;
                                  }
                                  if (!dialogContext.mounted) return;
                                  setState(() => saving = true);
                                  final enteredBillNumber = manualBillNumber
                                      .text
                                      .trim();
                                  if (enteredBillNumber.isNotEmpty &&
                                      await db.billNumberExists(
                                        enteredBillNumber,
                                      )) {
                                    if (dialogContext.mounted) {
                                      setState(() {
                                        saving = false;
                                        billNumberError =
                                            l10n.billNumberAlreadyUsed;
                                      });
                                    }
                                    return;
                                  }
                                  if (!dialogContext.mounted) return;
                                  final choice = await _showOrderConfirmation(
                                    dialogContext,
                                    database: db,
                                    customer: selectedCustomer,
                                    lines: lines,
                                    billNumber: enteredBillNumber.isEmpty
                                        ? l10n.automaticBillNumber
                                        : enteredBillNumber,
                                    dueDate: due.text,
                                    locale: locale,
                                    stitching: garmentTotal(),
                                    fabric: fabricTotal,
                                    extra: extraValue(),
                                    discount: discountValue(),
                                    total: orderTotal,
                                    paid: advanceAmount,
                                  );
                                  if (!dialogContext.mounted) {
                                    return;
                                  }
                                  if (choice == null) {
                                    setState(() => saving = false);
                                    return;
                                  }
                                  setState(() => formError = null);
                                  int orderId;
                                  try {
                                    orderId = await db.createOrderWithId(
                                      customerId: selectedCustomer['id'] as int,
                                      billNumber: enteredBillNumber.isEmpty
                                          ? null
                                          : enteredBillNumber,
                                      total: orderTotal,
                                      stitchingTotal: garmentTotal(),
                                      extra: extraValue(),
                                      discount: discountValue(),
                                      advance: advanceAmount,
                                      dueDate: due.text.isEmpty
                                          ? null
                                          : due.text,
                                      notes: notes.text.trim(),
                                      draftId: draftId,
                                      lines: lines
                                          .map(
                                            (row) => <String, Object?>{
                                              'garment': row.garment.key,
                                              'quantity':
                                                  int.tryParse(
                                                    normalizeLocalizedDigits(
                                                      row.count.text,
                                                    ),
                                                  ) ??
                                                  1,
                                              'measurement_profile':
                                                  row.profile,
                                              'measurement_snapshot':
                                                  jsonEncode(row.snapshot),
                                              'measurement_unit':
                                                  row.measurementUnit,
                                              'price_each': cents(row.price),
                                              'style': jsonEncode({
                                                'stitching': row
                                                    .stitchingInstructions
                                                    .text
                                                    .trim(),
                                                'features': {
                                                  for (final key
                                                      in garmentDesignFeatureKeys[row
                                                              .garment] ??
                                                          const <String>[])
                                                    key:
                                                        row.designChoices[key] ??
                                                        false,
                                                },
                                              }),
                                            },
                                          )
                                          .toList(),
                                      fabricLines: [
                                        for (var i = 0; i < lines.length; i++)
                                          if (quantityValue(
                                                lines[i].fabricQuantity,
                                              ) >
                                              0)
                                            <String, Object?>{
                                              'line_index': i,
                                              'ownership': lines[i].ownership,
                                              'fabric_id':
                                                  lines[i].ownership == 'shop'
                                                  ? lines[i].fabricId
                                                  : null,
                                              'description':
                                                  lines[i].ownership ==
                                                      'customer'
                                                  ? lines[i]
                                                        .outsideDescription
                                                        .text
                                                        .trim()
                                                  : null,
                                              'quantity': quantityValue(
                                                lines[i].fabricQuantity,
                                              ),
                                              'unit_price':
                                                  lines[i].ownership == 'shop'
                                                  ? (fabrics
                                                                .where(
                                                                  (f) =>
                                                                      f['id'] ==
                                                                      lines[i]
                                                                          .fabricId,
                                                                )
                                                                .firstOrNull?['selling_price']
                                                            as int? ??
                                                        0)
                                                  : 0,
                                            },
                                      ],
                                    );
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    if (context.mounted) {
                                      String? initialPrintError;
                                      var retryDocuments =
                                          const <OrderDocumentKind>[];
                                      final autoPrintDocuments =
                                          choice == _OrderSaveChoice.printBoth
                                          ? OrderDocumentKind.values
                                          : const <OrderDocumentKind>[];
                                      if (autoPrintDocuments.isNotEmpty) {
                                        final printResult =
                                            await _printOrderDocuments(
                                              db,
                                              orderId,
                                              autoPrintDocuments,
                                              locale: locale,
                                              l10n: l10n,
                                            );
                                        initialPrintError = printResult.error;
                                        retryDocuments =
                                            printResult.failedDocuments;
                                      }
                                      if (context.mounted) {
                                        await showSavedOrderPrintOptions(
                                          context,
                                          db,
                                          orderId,
                                          locale: locale,
                                          initialPrintError: initialPrintError,
                                          initialRetryDocuments: retryDocuments,
                                        );
                                      }
                                    }
                                  } catch (error, stackTrace) {
                                    debugPrint(
                                      'Order save failed: $error\n$stackTrace',
                                    );
                                    if (dialogContext.mounted) {
                                      final duplicate = error
                                          .toString()
                                          .toLowerCase()
                                          .contains('unique');
                                      setState(() {
                                        saving = false;
                                        billNumberError = duplicate
                                            ? l10n.billNumberAlreadyUsed
                                            : null;
                                        formError = duplicate
                                            ? null
                                            : error.toString().contains(
                                                'Not enough available fabric',
                                              )
                                            ? word('notEnoughFabric')
                                            : l10n.errorGeneric;
                                      });
                                    }
                                  }
                                },
                          icon: saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(l10n.reviewOrder),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  for (final row in lines) {
    row.dispose();
  }
  detailsScroll.dispose();
  summaryScroll.dispose();
  manualBillNumber.dispose();
  advance.dispose();
  extra.dispose();
  discount.dispose();
  due.dispose();
  notes.dispose();
  advanceFocus.dispose();
  dueFocus.dispose();
  notesFocus.dispose();
}

enum _OrderSaveChoice { save, printBoth }

class _OrderMeasurementsResult {
  const _OrderMeasurementsResult(this.values, this.unit, this.designChoices);

  final Map<String, String> values;
  final String unit;
  final Map<String, bool> designChoices;
}

Future<_OrderMeasurementsResult?> _reviewOrderMeasurements(
  BuildContext context,
  ShopDatabase database,
  Map<String, Object?> customer,
  Garment garment, {
  required String? profileName,
  required String measurementUnit,
  required Map<String, String> values,
  required Map<String, bool> initialDesignChoices,
  String? billNumber,
  String? dueDate,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final fields = measurementFields[garment] ?? const <(String, String)>[];
  final names = [
    ...fields.map((entry) => entry.$1),
    ...values.keys.where((key) => !fields.any((entry) => entry.$1 == key)),
  ];
  if (!names.contains('Additional notes')) names.add('Additional notes');
  final controllers = <String, TextEditingController>{
    for (final name in names)
      name: TextEditingController(text: values[name] ?? ''),
  };
  var unit = measurementUnit == 'cm' ? 'cm' : 'in';
  final choices = Map<String, bool>.from(initialDesignChoices);
  final customerId =
      customer['customer_code']?.toString() ??
      customer['id']?.toString() ??
      '-';
  final orderDate = CalendarService.format(
    CalendarService.shopToday(),
    calendar: CalendarService.activeCalendar,
    locale: Localizations.localeOf(context).toLanguageTag(),
  );
  final deliveryDate = dueDate == null || dueDate.isEmpty
      ? '-'
      : CalendarService.format(
          DateTime.tryParse(dueDate) ?? CalendarService.shopToday(),
          calendar: CalendarService.activeCalendar,
          locale: Localizations.localeOf(context).toLanguageTag(),
        );
  Map<String, String> currentValues() => {
    for (final entry in controllers.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.value.text.trim(),
  };
  Map<String, Object?> profileData() => {
    ...currentValues(),
    'Design choices': Map<String, bool>.from(choices),
  };
  _OrderMeasurementsResult result() => _OrderMeasurementsResult(
    currentValues(),
    unit,
    Map<String, bool>.from(choices),
  );
  try {
    return await showResponsiveDialog<_OrderMeasurementsResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final colors = Theme.of(dialogContext).colorScheme;
          Widget measurementPanel() => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.measurementsHeading,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                for (final name in names)
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
                            _localizedMeasurementLabel(l10n, name),
                            style: Theme.of(dialogContext).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: name == 'Additional notes' ? 150 : 104,
                          child: TextField(
                            controller: controllers[name],
                            minLines: name == 'Additional notes' ? 1 : null,
                            maxLines: name == 'Additional notes' ? 2 : 1,
                            keyboardType: name == 'Additional notes'
                                ? TextInputType.multiline
                                : const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              isDense: true,
                              suffixText: name == 'Additional notes'
                                  ? null
                                  : unit,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 9,
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
          return AlertDialog(
            insetPadding: const EdgeInsets.all(16),
            title: Text(
              '${l10n.reviewMeasurements}: ${_localizedGarment(l10n, garment)}',
            ),
            content: SizedBox(
              width: (MediaQuery.sizeOf(dialogContext).width - 64).clamp(
                340.0,
                920.0,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${customer['name'] ?? ''}',
                                  style: Theme.of(dialogContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                billNumber?.isNotEmpty == true
                                    ? billNumber!
                                    : l10n.billNotAssigned,
                                textDirection: TextDirection.ltr,
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${l10n.mobileNumber}: ${customer['phone'] ?? '-'}',
                              ),
                              Text('${l10n.customerId}: $customerId'),
                              Text('${l10n.orderDate}: $orderDate'),
                              Text('${l10n.deliveryDate}: $deliveryDate'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: unit,
                      decoration: InputDecoration(
                        labelText: l10n.measurementUnit,
                      ),
                      items: [
                        DropdownMenuItem(value: 'in', child: Text(l10n.inches)),
                        DropdownMenuItem(
                          value: 'cm',
                          child: Text(l10n.centimeters),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => unit = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    MeasurementFormLayout(
                      garment: garment,
                      measurements: measurementPanel(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              CommandButton(id: 'action.cancel', child: TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.cancel),
              )),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showResponsiveDialog<bool>(
                    context: dialogContext,
                    builder: (confirmContext) => AlertDialog(
                      title: Text(l10n.updateSavedMeasurements),
                      content: Text(l10n.confirmUpdateSavedMeasurements),
                      actions: [
                        CommandButton(id: 'action.cancel', child: TextButton(
                          onPressed: () => Navigator.pop(confirmContext, false),
                          child: Text(l10n.cancel),
                        )),
                        FilledButton(
                          onPressed: () => Navigator.pop(confirmContext, true),
                          child: Text(l10n.updateSavedMeasurements),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !dialogContext.mounted) return;
                  try {
                    await database.saveMeasurement(
                      customerId: customer['id'] as int,
                      garment: garment.key,
                      name: profileName?.trim().isNotEmpty == true
                          ? profileName!.trim()
                          : 'Default',
                      unit: unit,
                      json: jsonEncode(profileData()),
                    );
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.savedMeasurementsUpdated)),
                    );
                    Navigator.pop(dialogContext, result());
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(content: Text('${l10n.errorGeneric}: $error')),
                    );
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.updateSavedMeasurements),
              ),
              CommandButton(id: 'action.save', child: FilledButton(
                onPressed: () => Navigator.pop(dialogContext, result()),
                child: Text(l10n.useMeasurementsForOrder),
              )),
            ],
          );
        },
      ),
    );
  } finally {
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

Future<_OrderSaveChoice?> _showOrderConfirmation(
  BuildContext context, {
  required ShopDatabase database,
  required Map<String, Object?> customer,
  required List<_OrderEntry> lines,
  required String billNumber,
  required String dueDate,
  required String locale,
  required int stitching,
  required int fabric,
  required int extra,
  required int discount,
  required int total,
  required int paid,
}) => showResponsiveDialog<_OrderSaveChoice>(
  context: context,
  builder: (dialogContext) {
    final l10n = AppLocalizations.of(dialogContext)!;
    return StatefulBuilder(
      builder: (dialogContext, setState) {
        final balance = (total - paid).clamp(0, 1 << 60).toInt();
        final compact = MediaQuery.sizeOf(dialogContext).width < 760;
        final orderDateText = CalendarService.format(
          CalendarService.shopToday(),
          calendar: CalendarService.activeCalendar,
          locale: locale,
        );
        final deliveryDateText = dueDate.isEmpty
            ? '—'
            : CalendarService.format(
                DateTime.tryParse(dueDate) ?? DateTime.now(),
                calendar: CalendarService.activeCalendar,
                locale: locale,
              );
        Widget measurementPreview(_OrderEntry line, int index) => Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_localizedGarment(l10n, line.garment)} · ${l10n.quantity}: ${line.count.text}',
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final result = await _reviewOrderMeasurements(
                          dialogContext,
                          // Saved measurements are deliberately edited only from
                          // the explicit choice inside the measurement review.
                          database,
                          customer,
                          line.garment,
                          profileName: line.profile,
                          measurementUnit: line.measurementUnit,
                          values: line.snapshot,
                          initialDesignChoices: line.designChoices,
                          billNumber: billNumber,
                          dueDate: dueDate,
                        );
                        if (result == null || !dialogContext.mounted) return;
                        setState(() {
                          line.snapshot = result.values;
                          line.measurementUnit = result.unit;
                          line.designChoices
                            ..clear()
                            ..addAll(result.designChoices);
                        });
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l10n.editForThisOrder),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final entry in line.snapshot.entries)
                      if (entry.key == 'Additional notes')
                        Text(
                          '${_localizedMeasurementLabel(l10n, entry.key)}: ${entry.value}',
                        )
                      else
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${_localizedMeasurementLabel(l10n, entry.key)}: ${entry.value} ${line.measurementUnit}',
                          ),
                        ),
                    if (line.snapshot.isEmpty) Text(l10n.noMeasurementsYet),
                  ],
                ),
                if (line.stitchingInstructions.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${l10n.stitchingInstructions}: ${line.stitchingInstructions.text}',
                    ),
                  ),
              ],
            ),
          ),
        );
        Widget documentCard({
          required IconData icon,
          required String title,
          required String subtitle,
          required Widget child,
        }) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(dialogContext).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                const Divider(height: 20),
                child,
              ],
            ),
          ),
        );
        return AlertDialog(
          title: Text(l10n.orderConfirmation),
          content: SizedBox(
            width: 900,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.reviewOrderBeforeSaving),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: compact ? double.infinity : 410,
                        child: documentCard(
                          icon: Icons.straighten_outlined,
                          title: l10n.measurementWorkSlip,
                          subtitle:
                              '$billNumber · ${l10n.orderDate}: $orderDateText · ${l10n.deliveryDate}: $deliveryDateText',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.customer}: ${customer['name'] ?? ''}',
                              ),
                              const SizedBox(height: 8),
                              for (var index = 0; index < lines.length; index++)
                                measurementPreview(lines[index], index),
                              if (lines.any(
                                (line) => line.stitchingInstructions.text
                                    .trim()
                                    .isNotEmpty,
                              ))
                                Text(l10n.orderInstructions),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: compact ? double.infinity : 410,
                        child: documentCard(
                          icon: Icons.receipt_long_outlined,
                          title: l10n.customerBill,
                          subtitle: '$billNumber · AFN',
                          child: Column(
                            children: [
                              _moneySummaryLine(
                                dialogContext,
                                l10n.customer,
                                customer['name']?.toString() ?? '',
                              ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.mobileNumber,
                                customer['phone']?.toString() ?? '',
                              ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.orderDate,
                                orderDateText,
                              ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.deliveryDate,
                                deliveryDateText,
                              ),
                              for (final line in lines)
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    '${_localizedGarment(l10n, line.garment)} · ${l10n.quantity}: ${line.count.text}',
                                  ),
                                ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.stitchingAmount,
                                formatMoney(stitching, locale: locale),
                              ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.fabricAmount,
                                formatMoney(fabric, locale: locale),
                              ),
                              if (extra > 0)
                                _moneySummaryLine(
                                  dialogContext,
                                  l10n.extraCharge,
                                  formatMoney(extra, locale: locale),
                                ),
                              if (discount > 0)
                                _moneySummaryLine(
                                  dialogContext,
                                  l10n.discount,
                                  '-${formatMoney(discount, locale: locale)}',
                                ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.total,
                                formatMoney(total, locale: locale),
                                prominent: true,
                              ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.advancePayment,
                                formatMoney(paid, locale: locale),
                              ),
                              _moneySummaryLine(
                                dialogContext,
                                l10n.remainingBalance,
                                formatMoney(balance, locale: locale),
                                prominent: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            )),
            CommandButton(id: 'action.save', child: OutlinedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _OrderSaveChoice.save),
              child: Text(l10n.saveOrder),
            )),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, _OrderSaveChoice.printBoth),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.saveOrderPrintBoth),
            ),
          ],
        );
      },
    );
  },
);

class _PrintDocumentsResult {
  const _PrintDocumentsResult(this.error, this.failedDocuments);

  final String? error;
  final List<OrderDocumentKind> failedDocuments;
}

Future<_PrintDocumentsResult> _printOrderDocuments(
  ShopDatabase database,
  int orderId,
  Iterable<OrderDocumentKind> documents, {
  required String locale,
  required AppLocalizations l10n,
}) async {
  final failed = await printOrderDocumentBatch(
    documents,
    printDocument: (kind) =>
        printOrderDocument(database, orderId, kind: kind, locale: locale),
    onError: (kind, error) =>
        debugPrint('Order document print failed ($kind): $error'),
  );
  return _PrintDocumentsResult(
    failed.isEmpty ? null : l10n.printFailedRetry,
    failed,
  );
}

Future<void> showSavedOrderPrintOptions(
  BuildContext context,
  ShopDatabase database,
  int orderId, {
  required String locale,
  String? initialPrintError,
  List<OrderDocumentKind> initialRetryDocuments = const [],
  bool focusPrintBoth = false,
}) async {
  final savedOrder = await database.orderDetailsById(orderId);
  final savedBillNumber = savedOrder?['bill_number']?.toString() ?? '';
  if (!context.mounted) return;
  await showResponsiveDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext)!;
      var busy = false;
      var error = initialPrintError;
      var retryDocuments = List<OrderDocumentKind>.from(initialRetryDocuments);
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> printDocuments(List<OrderDocumentKind> documents) async {
            if (busy) return;
            setState(() => busy = true);
            final result = await _printOrderDocuments(
              database,
              orderId,
              documents,
              locale: locale,
              l10n: l10n,
            );
            if (!dialogContext.mounted) return;
            setState(() {
              busy = false;
              error = result.error;
              retryDocuments = result.failedDocuments;
            });
          }

          Widget documentAction(OrderDocumentKind kind, String title) =>
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => previewOrderDocument(
                                    dialogContext,
                                    database,
                                    orderId,
                                    kind: kind,
                                    locale: locale,
                                  ),
                            icon: const Icon(Icons.preview_outlined),
                            label: Text(l10n.preview),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    try {
                                      await exportOrderDocumentPdf(
                                        dialogContext,
                                        database,
                                        orderId,
                                        kind: kind,
                                        locale: locale,
                                      );
                                    } catch (exception) {
                                      if (dialogContext.mounted) {
                                        setState(() => error = '$exception');
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(l10n.saveAsPdf),
                          ),
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => printDocuments([kind]),
                            icon: const Icon(Icons.print_outlined),
                            label: Text(
                              kind == OrderDocumentKind.measurements
                                  ? l10n.printMeasurements
                                  : l10n.printCustomerBill,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
          return AlertDialog(
            title: Text(l10n.orderSaved),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.savedOrderPrintOptions),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(l10n.billNumber)),
                          SelectableText(
                            savedBillNumber,
                            textDirection: TextDirection.ltr,
                            style: Theme.of(dialogContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    documentAction(
                      OrderDocumentKind.measurements,
                      l10n.measurementWorkSlip,
                    ),
                    documentAction(
                      OrderDocumentKind.customerBill,
                      l10n.customerBill,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                      if (retryDocuments.isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => printDocuments(retryDocuments),
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              CommandButton(id: 'action.cancel', child: TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: Text(l10n.close),
              )),
              CommandButton(id: 'action.printBoth', child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => printDocuments(OrderDocumentKind.values),
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
                label: Text(l10n.printBoth),
                autofocus: focusPrintBoth,
              )),
            ],
          );
        },
      );
    },
  );
}

String _localizedGarment(AppLocalizations l10n, Garment garment) =>
    switch (garment) {
      Garment.shalwar => l10n.shalwar,
      Garment.waistcoat => l10n.waistcoat,
      Garment.coat => l10n.coat,
    };

String _localizedMeasurementLabel(AppLocalizations l10n, String name) =>
    switch (name) {
      'Kameez length' => l10n.kameezLength,
      'Shoulder width' => l10n.shoulderWidth,
      'Sleeve length' => l10n.sleeveLength,
      'Chest' => l10n.chest,
      'Waist' => l10n.waist,
      'Hip / seat' => l10n.hipSeat,
      'Neck / collar' => l10n.neckCollar,
      'Neck' => l10n.neck,
      'Upper arm' => l10n.upperArm,
      'Cuff / wrist' => l10n.cuffWrist,
      'Shalwar length' => l10n.shalwarLength,
      'Shalwar waist' => l10n.shalwarWaist,
      'Thigh' => l10n.thigh,
      'Bottom opening' => l10n.bottomOpening,
      'Waistcoat length' => l10n.waistcoatLength,
      'Armhole' => l10n.armhole,
      'Coat length' => l10n.coatLength,
      'Wrist / sleeve opening' => l10n.wristSleeveOpening,
      'Additional notes' => l10n.additionalNotes,
      _ => name,
    };

class _OrderEntry {
  _OrderEntry(this.garment) {
    count = TextEditingController(text: '1');
    price = TextEditingController(text: '0');
    fabricQuantity = TextEditingController(text: '4');
  }
  Garment garment;
  late final TextEditingController count;
  late final TextEditingController price;
  late final TextEditingController fabricQuantity;
  final outsideDescription = TextEditingController();
  final countFocus = FocusNode();
  final priceFocus = FocusNode();
  final fabricQuantityFocus = FocusNode();
  final outsideDescriptionFocus = FocusNode();
  String ownership = 'customer';
  int? fabricId;
  String? profile;
  String measurementUnit = 'in';
  Map<String, String> snapshot = {};
  List<Map<String, Object?>> profiles = [];
  final stitchingInstructions = TextEditingController();
  final Map<String, bool> designChoices = {};
  void dispose() {
    count.dispose();
    price.dispose();
    fabricQuantity.dispose();
    outsideDescription.dispose();
    stitchingInstructions.dispose();
    countFocus.dispose();
    priceFocus.dispose();
    fabricQuantityFocus.dispose();
    outsideDescriptionFocus.dispose();
  }
}

String _fabricCategoryForGarment(Garment garment) => switch (garment) {
  Garment.shalwar => 'Clothing Fabric',
  Garment.waistcoat || Garment.coat => 'Waistcoat / Coat Fabric',
};

Future<int?> _pickOrderFabric(
  BuildContext context,
  List<Map<String, Object?>> fabrics, {
  required String title,
  required String searchLabel,
  required String emptyLabel,
}) {
  final search = TextEditingController();
  return showResponsiveDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        final query = search.text.trim().toLowerCase();
        final matches = fabrics.where((fabric) {
          final searchable = [
            fabric['code']?.toString() ?? '',
            fabric['name']?.toString() ?? '',
            fabric['color']?.toString() ?? '',
          ].join(' ').toLowerCase();
          return query.isEmpty || searchable.contains(query);
        }).toList();
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            height: 460,
            child: Column(
              children: [
                TextField(
                  controller: search,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: searchLabel,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: matches.isEmpty
                      ? Center(child: Text(emptyLabel))
                      : ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final fabric = matches[index];
                            final unit = fabric['unit'] == 'meter'
                                ? context.l10n.fabricFormMeter
                                : context.l10n.fabricFormUnitReview(
                                    fabric['unit']?.toString() ?? '',
                                  );
                            final available = (fabric['available'] as num? ?? 0)
                                .toStringAsFixed(3);
                            final color = fabric['color']?.toString().trim();
                            return ListTile(
                              title: Text(
                                '${fabric['name']} · ${fabric['code']}',
                              ),
                              subtitle: Text(
                                '${color?.isNotEmpty == true ? '$color · ' : ''}$available $unit available',
                              ),
                              onTap: () => Navigator.pop(
                                dialogContext,
                                fabric['id'] as int,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ],
        );
      },
    ),
  ).whenComplete(search.dispose);
}

String _orderWord(String locale, String key) {
  final isPashto = locale == 'ps';
  final isDari = locale == 'fa';
  final words = <String, List<String>>{
    'garment': ['Garment', 'لباس', 'لباس'],
    'removeGarment': ['Remove garment', 'لباس حذف', 'حذف لباس'],
    'addGarment': ['Add garment', 'لباس اضافه کړئ', 'افزودن لباس'],
    'fabricSource': ['Fabric source', 'د ټوکر سرچینه', 'منبع پارچه'],
    'shopFabric': ['Shop fabric', 'د دوکان ټوکر', 'پارچه فروشگاه'],
    'customerFabric': [
      'Customer fabric (outside)',
      'د پېرودونکي ټوکر',
      'پارچه مشتری',
    ],
    'selectFabric': ['Select fabric', 'ټوکر وټاکئ', 'انتخاب پارچه'],
    'searchFabric': ['Search fabric', 'ټوکر ولټوئ', 'جستجوی پارچه'],
    'noFabricMatch': [
      'No matching fabric found.',
      'مناسب ټوکر ونه موندل شو.',
      'پارچه‌ای پیدا نشد.',
    ],
    'noCategoryFabric': [
      'Add fabric in this garment category to select it.',
      'د دې کټګورۍ ټوکر اضافه کړئ.',
      'برای انتخاب، پارچه را در این دسته ثبت کنید.',
    ],
    'fabricQuantity': ['Fabric quantity', 'د ټوکر اندازه', 'مقدار پارچه'],
    'fabricDefaultHint': [
      'Default: 4 meters; adjust for each customer.',
      'اصلي اندازه ۴ متره ده؛ د هر پېرودونکي لپاره یې بدله کړئ.',
      'پیش‌فرض ۴ متر است؛ برای هر مشتری تغییر دهید.',
    ],
    'fabricCharge': ['Fabric charge', 'د ټوکر بیه', 'هزینه پارچه'],
    'stitchingTotal': ['Stitching', 'ګنډل', 'دوخت'],
    'outsideFabricName': [
      'Outside fabric description',
      'د بهرني ټوکر نوم',
      'شرح پارچه بیرونی',
    ],
    'previousField': ['Previous field', 'مخکینی خانه', 'فیلد قبلی'],
    'nextField': ['Next field', 'راتلونکې خانه', 'فیلد بعدی'],
    'checkFabricAmounts': [
      'Select shop fabric and enter a valid fabric quantity.',
      'د دوکان ټوکر وټاکئ او سمه اندازه ولیکئ.',
      'پارچه فروشگاه و مقدار معتبر را انتخاب کنید.',
    ],
    'notEnoughFabric': [
      'Not enough fabric available for this order.',
      'د دې فرمایش لپاره ټوکر کافي نه دی.',
      'پارچه کافی برای این سفارش موجود نیست.',
    ],
  };
  final values = words[key]!;
  return values[isPashto
      ? 1
      : isDari
      ? 2
      : 0];
}

Map<String, Object?> _measurementProfileData(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map) return const {};
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

Map<String, String> _measurementSnapshot(String json) {
  final profile = _measurementProfileData(json);
  return {
    for (final entry in profile.entries)
      if (entry.key != 'Design choices' &&
          entry.value is! Map &&
          entry.value != null)
        entry.key: entry.value.toString(),
  };
}

Map<String, bool> _measurementDesignChoices(String json) =>
    decodeDesignFeatureChoices(_measurementProfileData(json)['Design choices']);

Widget _fieldHeading(BuildContext context, String label, IconData icon) => Row(
  children: [
    Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
    const SizedBox(width: 8),
    Text(label, style: Theme.of(context).textTheme.titleSmall),
  ],
);

Widget _moneySummaryLine(
  BuildContext context,
  String label,
  String amount, {
  bool prominent = false,
  Color? color,
}) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Text(
        label,
        style: prominent
            ? Theme.of(context).textTheme.titleSmall
            : Theme.of(context).textTheme.bodyMedium,
      ),
    ),
    Text(
      amount,
      textDirection: TextDirection.ltr,
      style:
          (prominent
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(fontWeight: FontWeight.w700, color: color),
    ),
  ],
);
