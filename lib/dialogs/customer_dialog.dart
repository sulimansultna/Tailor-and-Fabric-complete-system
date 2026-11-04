import 'package:flutter/material.dart';
import '../commands/app_commands.dart';

import '../widgets/responsive_layout.dart';

import '../core/formatters.dart';
import '../core/phone.dart';
import '../data/shop_database.dart';
import '../l10n/generated/app_localizations.dart';

Future<bool> showCustomerDialog(
  BuildContext context,
  ShopDatabase db, {
  String initialPhone = '',
  Map<String, Object?>? customer,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: customer?['name'] as String? ?? '');
  final phone = TextEditingController(
    text: customer?['phone'] as String? ?? initialPhone,
  );
  final phone2 = TextEditingController(
    text: customer?['phone2'] as String? ?? '',
  );
  final address = TextEditingController(
    text: customer?['address'] as String? ?? '',
  );
  final notes = TextEditingController(
    text: customer?['notes'] as String? ?? '',
  );
  final opening = TextEditingController();
  var openingIsCredit = false;
  var showOptional = false;
  var saving = false;
  String? formError;
  final original = [
    name.text,
    phone.text,
    phone2.text,
    address.text,
    notes.text,
  ];
  bool changed() =>
      [
        name.text,
        phone.text,
        phone2.text,
        address.text,
        notes.text,
      ].asMap().entries.any((entry) => entry.value != original[entry.key]) ||
      opening.text.isNotEmpty;
  Future<bool> askDiscard(BuildContext dialogContext) async {
    if (!changed()) return true;
    return await showResponsiveDialog<bool>(
          context: dialogContext,
          builder: (confirmContext) => AlertDialog(
            title: Text(l10n.unsavedChanges),
            content: Text(l10n.discardChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmContext, false),
                child: Text(l10n.goBack),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(confirmContext, true),
                child: Text(l10n.discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  final saved = await showResponsiveDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        Future<void> close() async {
          if (saving || !await askDiscard(dialogContext)) return;
          if (dialogContext.mounted) Navigator.pop(dialogContext, false);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) close();
          },
          child: AlertDialog(
            title: Text(
              customer == null ? l10n.addCustomerTitle : l10n.editCustomer,
            ),
            content: SizedBox(
              width: 540,
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: name,
                        enabled: !saving,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: '${l10n.fullName} *',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? l10n.enterCustomerName
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: phone,
                        enabled: !saving,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: '${l10n.mobileNumber} *',
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                        validator: (value) =>
                            value == null || normalizePhone(value).isEmpty
                            ? l10n.enterMobile
                            : null,
                      ),
                      ExpansionTile(
                        key: const PageStorageKey('customer-optional-details'),
                        initiallyExpanded: showOptional,
                        onExpansionChanged: (value) => showOptional = value,
                        tilePadding: EdgeInsets.zero,
                        title: Text(l10n.optionalDetails),
                        children: [
                          TextField(
                            controller: phone2,
                            enabled: !saving,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText: l10n.secondNumber,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: address,
                            enabled: !saving,
                            decoration: InputDecoration(
                              labelText: l10n.address,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: notes,
                            enabled: !saving,
                            decoration: InputDecoration(
                              labelText: l10n.additionalNotes,
                            ),
                            maxLines: 2,
                          ),
                          if (customer == null) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: opening,
                              enabled: !saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: l10n.openingBalance,
                                prefixIcon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                helperText: l10n.openingBalanceHelp,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment(
                                  value: false,
                                  label: Text(l10n.debt),
                                  icon: const Icon(Icons.arrow_upward),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text(l10n.credit),
                                  icon: const Icon(Icons.arrow_downward),
                                ),
                              ],
                              selected: {openingIsCredit},
                              onSelectionChanged: saving
                                  ? null
                                  : (value) => setState(
                                      () => openingIsCredit = value.first,
                                    ),
                            ),
                          ],
                        ],
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          formError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              CommandButton(id: 'action.cancel', child: TextButton(onPressed: close, child: Text(l10n.cancel))),
              CommandButton(id: 'action.save', child: FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() {
                          saving = true;
                          formError = null;
                        });
                        final primary = normalizePhone(phone.text);
                        final secondary = normalizePhone(phone2.text);
                        final matches = [
                          ...await db.searchCustomers(primary),
                          if (secondary.isNotEmpty)
                            ...await db.searchCustomers(secondary),
                        ];
                        final duplicate = matches.any((other) {
                          if (customer != null &&
                              other['id'] == customer['id']) {
                            return false;
                          }
                          final numbers = [
                            other['phone'],
                            other['phone2'],
                          ].whereType<String>();
                          return numbers.any((value) {
                            final normalized = normalizePhone(value);
                            return normalized == primary ||
                                (secondary.isNotEmpty &&
                                    normalized == secondary);
                          });
                        });
                        if (duplicate && dialogContext.mounted) {
                          setState(() => saving = false);
                          final allow = await showResponsiveDialog<bool>(
                            context: dialogContext,
                            builder: (confirmContext) => AlertDialog(
                              title: Text(l10n.numberAlreadyUsed),
                              content: Text(l10n.duplicatePhoneQuestion),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: Text(l10n.goBack),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: Text(l10n.saveAnyway),
                                ),
                              ],
                            ),
                          );
                          if (allow != true) return;
                          setState(() => saving = true);
                        }
                        try {
                          if (customer == null) {
                            final amount =
                                ((double.tryParse(
                                              normalizeLocalizedDigits(
                                                opening.text,
                                              ),
                                            ) ??
                                            0) *
                                        100)
                                    .round();
                            await db.addCustomer(
                              name: name.text,
                              phone: phone.text,
                              phone2: phone2.text,
                              address: address.text,
                              notes: notes.text,
                              opening: openingIsCredit
                                  ? -amount.abs()
                                  : amount.abs(),
                            );
                          } else {
                            await db.updateCustomer(
                              id: customer['id'] as int,
                              name: name.text,
                              phone: phone.text,
                              phone2: phone2.text,
                              address: address.text,
                              notes: notes.text,
                            );
                          }
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  customer == null
                                      ? l10n.customerAdded
                                      : l10n.customerUpdated,
                                ),
                              ),
                            );
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setState(() {
                              saving = false;
                              formError = l10n.errorGeneric;
                            });
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.saveCustomer),
              )),
            ],
          ),
        );
      },
    ),
  );
  for (final controller in [name, phone, phone2, address, notes, opening]) {
    controller.dispose();
  }
  return saved == true;
}
