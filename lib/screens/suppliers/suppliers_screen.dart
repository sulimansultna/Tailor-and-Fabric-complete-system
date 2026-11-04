import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../widgets/responsive_list_page.dart';
import '../../widgets/horizontal_table.dart';

import '../../core/app_date_picker.dart';
import '../../core/calendar_service.dart';
import '../../core/formatters.dart';
import '../../data/shop_database.dart';
import '../../l10n/app_localizations_extensions.dart';
import 'fabric_purchase_screen.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key, required this.database});
  final ShopDatabase database;

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _search = TextEditingController();
  List<Map<String, Object?>> _rows = [];
  bool _loading = true;
  Object? _error;
  String _filter = 'active';

  String get _lang => Localizations.localeOf(context).languageCode;
  bool get _rtl => _lang == 'ps' || _lang == 'fa';
  String _t(String key) =>
      _supplierWords[_lang]?[key] ?? _supplierWords['en']![key] ?? key;
  String _money(int value) => formatMoney(
    value.abs(),
    locale: Localizations.localeOf(context).toLanguageTag(),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await widget.database.suppliers(
        query: _search.text.trim(),
        includeArchived: true,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<Map<String, Object?>> get _visible => _rows.where((row) {
    final archived = (row['archived'] as num? ?? 0) == 1;
    final balance = (row['balance'] as num? ?? 0).toInt();
    return switch (_filter) {
      'archived' => archived,
      'owing' => !archived && balance > 0,
      'credit' => !archived && balance < 0,
      _ => !archived,
    };
  }).toList();

  Future<void> _supplierForm([Map<String, Object?>? supplier]) async {
    final name = TextEditingController(text: '${supplier?['name'] ?? ''}');
    final company = TextEditingController(
      text: '${supplier?['company'] ?? ''}',
    );
    final phone = TextEditingController(text: '${supplier?['phone'] ?? ''}');
    final phone2 = TextEditingController(text: '${supplier?['phone2'] ?? ''}');
    final address = TextEditingController(
      text: '${supplier?['address'] ?? ''}',
    );
    final notes = TextEditingController(text: '${supplier?['notes'] ?? ''}');
    final opening = TextEditingController();
    var balanceKind = 'payable';
    var openingDate = CalendarService.shopToday();
    var saving = false;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text(
            supplier == null ? _t('addSupplier') : _t('editSupplier'),
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (supplier != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('${_t('supplierId')}: ${supplier['code']}'),
                    ),
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '${_t('name')} *',
                      errorText: name.text.trim().isEmpty ? null : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: company,
                    decoration: InputDecoration(labelText: _t('company')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: _t('mobile')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone2,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: _t('mobile2')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: address,
                    decoration: InputDecoration(labelText: _t('address')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: _t('notes')),
                  ),
                  if (supplier == null) ...[
                    const Divider(height: 26),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _t('openingBalance'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: balanceKind,
                      decoration: InputDecoration(labelText: _t('balanceType')),
                      items: [
                        DropdownMenuItem(
                          value: 'payable',
                          child: Text(_t('shopOwesSupplier')),
                        ),
                        DropdownMenuItem(
                          value: 'credit',
                          child: Text(_t('supplierCredit')),
                        ),
                      ],
                      onChanged: (value) =>
                          update(() => balanceKind = value ?? balanceKind),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: opening,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: _t('openingAmountOptional'),
                        suffixText: 'AFN',
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showAppDatePicker(
                          context: dialogContext,
                          initialDate: openingDate,
                          firstDate: DateTime(2000),
                          lastDate: CalendarService.shopToday(),
                          helpText: _t('effectiveDate'),
                        );
                        if (picked != null) update(() => openingDate = picked);
                      },
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        '${_t('effectiveDate')}: ${formatDate(openingDate.toIso8601String(), locale: Localizations.localeOf(context).toLanguageTag())}',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            )),
            CommandButton(id: 'action.save', child: FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(_t('nameRequired'))),
                        );
                        return;
                      }
                      update(() => saving = true);
                      try {
                        final phones = [phone.text, phone2.text]
                            .map((value) => value.trim())
                            .where((value) => value.isNotEmpty)
                            .toSet();
                        var duplicatePhone = false;
                        for (final value in phones) {
                          if (await widget.database.supplierPhoneExists(
                            value,
                            exceptId: supplier?['id'] as int?,
                          )) {
                            duplicatePhone = true;
                          }
                        }
                        if (duplicatePhone && dialogContext.mounted) {
                          final confirmed = await showDialog<bool>(
                            context: dialogContext,
                            builder: (confirmContext) => AlertDialog(
                              title: Text(_t('possibleDuplicate')),
                              content: Text(_t('sharedPhoneWarning')),
                              actions: [
                                CommandButton(id: 'action.cancel', child: TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: Text(context.l10n.cancel),
                                )),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: Text(_t('continueAnyway')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) {
                            update(() => saving = false);
                            return;
                          }
                        }
                        if (supplier == null) {
                          final parsed = opening.text.trim().isEmpty
                              ? 0
                              : parseMoneyMinor(opening.text);
                          if (parsed == null) {
                            update(() => saving = false);
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(_t('invalidAmount'))),
                              );
                            }
                            return;
                          }
                          final signed = balanceKind == 'credit'
                              ? -parsed
                              : parsed;
                          await widget.database.addSupplier(
                            name: name.text,
                            company: company.text,
                            phone: phone.text,
                            phone2: phone2.text,
                            address: address.text,
                            notes: notes.text,
                            openingBalance: signed,
                            openingDate: openingDate,
                          );
                        } else {
                          await widget.database.updateSupplier(
                            id: supplier['id'] as int,
                            name: name.text,
                            company: company.text,
                            phone: phone.text,
                            phone2: phone2.text,
                            address: address.text,
                            notes: notes.text,
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          update(() => saving = false);
                          ScaffoldMessenger.of(dialogContext)
                              .showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(context.l10n.save),
            )),
          ],
        ),
      ),
    );
    for (final controller in [
      name,
      company,
      phone,
      phone2,
      address,
      notes,
      opening,
    ]) {
      controller.dispose();
    }
    if (saved == true) await _load();
  }

  Future<void> _archive(Map<String, Object?> supplier, bool archived) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(archived ? _t('restoreSupplier') : _t('archiveSupplier')),
        content: Text(archived ? _t('restoreConfirm') : _t('archiveConfirm')),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          )),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(archived ? _t('restore') : _t('archive')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.database.archiveSupplier(
      supplier['id'] as int,
      archived: !archived,
    );
    await _load();
  }

  Future<void> _delete(Map<String, Object?> supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('deleteSupplier')),
        content: Text(_t('deleteConfirm')),
        actions: [
          CommandButton(id: 'action.cancel', child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          )),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await widget.database.deleteSupplierIfUnused(
      supplier['id'] as int,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_t(deleted ? 'supplierDeleted' : 'hasHistory'))),
    );
    await _load();
  }

  Future<void> _profile(Map<String, Object?> supplier, {int initialTabIndex = 0}) async {
    AppCommandRegistry.maybeOf(context)?.select('supplier', supplier);
    final id = supplier['id'] as int;
    final ledger = await widget.database.supplierLedger(id);
    final purchases = await widget.database.db.rawQuery(
      'SELECT * FROM fabric_purchases WHERE supplier_id=? ORDER BY date DESC,id DESC',
      [id],
    );
    final payments = await widget.database.supplierPayments(id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => DefaultTabController(
        initialIndex: initialTabIndex,
        length: 4,
        child: AlertDialog(
          title: Text('${supplier['name']}  ·  ${supplier['code']}'),
          content: SizedBox(
            width: 900,
            height: (MediaQuery.sizeOf(dialogContext).height - 220).clamp(
              240.0,
              600.0,
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _profileStat(
                      _t('currentOwed'),
                      _money(_balance(supplier) > 0 ? _balance(supplier) : 0),
                    ),
                    _profileStat(
                      _t('supplierCredit'),
                      _money(_balance(supplier) < 0 ? _balance(supplier) : 0),
                    ),
                    Text(
                      '${supplier['company'] ?? ''}  ${supplier['phone'] ?? ''}',
                    ),
                  ],
                ),
                TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(text: _t('purchases')),
                    Tab(text: _t('ledger')),
                    Tab(text: _t('payments')),
                    Tab(text: _t('information')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _purchaseList(purchases),
                      _ledgerList(ledger),
                      _paymentList(payments),
                      _information(supplier),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.close),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _supplierForm(supplier);
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(_t('editSupplier')),
            ),
            if ((supplier['archived'] as num? ?? 0) == 0)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _paySupplier(supplier);
                },
                icon: const Icon(Icons.payments_outlined),
                label: Text(_t('paySupplier')),
              ),
          ],
        ),
      ),
    );
    await _load();
  }

  int _balance(Map<String, Object?> supplier) =>
      (supplier['balance'] as num?)?.toInt() ?? 0;

  String _paymentMethodLabel(String method) => switch (method) {
    'Cash' => context.l10n.cash,
    'Bank transfer' => context.l10n.bankTransfer,
    'Other' => context.l10n.other,
    _ => method,
  };

  String _statusLabel(String status) => switch (status) {
    'Posted' => _t('posted'),
    'Draft' => _t('draft'),
    _ => status,
  };

  Widget _profileStat(String label, String value) => Chip(
    label: Text('$label: $value'),
    avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
  );

  Widget _purchaseList(List<Map<String, Object?>> purchases) =>
      purchases.isEmpty
      ? Center(child: Text(_t('noPurchases')))
      : ListView(
          children: [
            for (final purchase in purchases)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  '${purchase['number']} · ${_money((purchase['total'] as num).toInt())}',
                ),
                subtitle: Text(
                  '${purchase['invoice_reference'] ?? ''} · ${formatDate('${purchase['date']}', locale: Localizations.localeOf(context).toLanguageTag())} · ${_statusLabel('${purchase['status'] ?? ''}')}',
                ),
                trailing: Text(
                  '${_t('remaining')}: ${_money(((purchase['total'] as num).toInt() - (purchase['paid'] as num).toInt()).clamp(0, 1 << 30).toInt())}',
                ),
              ),
          ],
        );

  Widget _ledgerList(List<Map<String, Object?>> entries) {
    if (entries.isEmpty) return Center(child: Text(_t('noLedger')));
    final ordered = entries.toList()
      ..sort((a, b) {
        final date = '${a['date']}'.compareTo('${b['date']}');
        return date == 0 ? (a['id'] as int).compareTo(b['id'] as int) : date;
      });
    var running = 0;
    final rows = <Map<String, Object?>>[];
    for (final entry in ordered) {
      running += (entry['charge'] as num? ?? 0).toInt();
      running -= (entry['payment'] as num? ?? 0).toInt();
      rows.add({...entry, 'running': running});
    }
    return ListView(
      children: [
        for (final entry in rows.reversed)
          Builder(
            builder: (context) {
              final details = <String>[
                formatDate(
                  '${entry['date']}',
                  locale: Localizations.localeOf(context).toLanguageTag(),
                ),
              ];
              final purchaseNumber = '${entry['purchase_number'] ?? ''}';
              final bill = '${entry['supplier_bill'] ?? ''}';
              final linkedBills = '${entry['linked_purchase_bills'] ?? ''}';
              final voucher = '${entry['payment_voucher'] ?? ''}';
              if (purchaseNumber.isNotEmpty) {
                details.add('${_t('purchaseNumber')}: $purchaseNumber');
              }
              if (bill.isNotEmpty) details.add('${_t('supplierBill')}: $bill');
              if (linkedBills.isNotEmpty) {
                details.add('${_t('linkedPurchases')}: $linkedBills');
              }
              if (voucher.isNotEmpty && voucher != '${entry['reference']}') {
                details.add('${_t('paymentVoucher')}: $voucher');
              }
              return ListTile(
                dense: true,
                title: Text('${entry['description']} · ${entry['reference']}'),
                subtitle: Text(details.join('\n')),
                trailing: Text(_money((entry['running'] as int).abs())),
              );
            },
          ),
      ],
    );
  }

  Widget _paymentList(List<Map<String, Object?>> payments) => payments.isEmpty
      ? Center(child: Text(_t('noPayments')))
      : ListView(
          children: [
            for (final payment in payments)
              Builder(
                builder: (context) {
                  final amount = (payment['amount'] as num).toInt();
                  final allocated = (payment['allocated_amount'] as num? ?? 0)
                      .toInt();
                  final advance = (amount - allocated).clamp(0, 1 << 60);
                  final bills = '${payment['purchase_bills'] ?? ''}';
                  final details = <String>[
                    formatDate(
                      '${payment['date']}',
                      locale: Localizations.localeOf(context).toLanguageTag(),
                    ),
                    '${_paymentMethodLabel('${payment['method'] ?? ''}')} · ${_statusLabel('${payment['status'] ?? ''}')}',
                    if (bills.isNotEmpty) '${_t('supplierBill')}: $bills',
                    if (allocated > 0)
                      '${_t('allocatedToPurchases')}: ${_money(allocated)}',
                    if (advance > 0)
                      '${_t('advanceCredit')}: ${_money(advance)}',
                    if ('${payment['reference'] ?? ''}'.isNotEmpty)
                      '${_t('externalReference')}: ${payment['reference']}',
                    if ('${payment['notes'] ?? ''}'.isNotEmpty)
                      '${_t('notes')}: ${payment['notes']}',
                  ];
                  return ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text('${payment['receipt']} · ${_money(amount)}'),
                    subtitle: Text(details.join('\n')),
                  );
                },
              ),
          ],
        );

  Widget _information(Map<String, Object?> supplier) => ListView(
    children: [
      ListTile(
        title: Text(_t('company')),
        subtitle: Text('${supplier['company'] ?? '—'}'),
      ),
      ListTile(
        title: Text(_t('mobile')),
        subtitle: Text('${supplier['phone'] ?? '—'}'),
      ),
      ListTile(
        title: Text(_t('mobile2')),
        subtitle: Text('${supplier['phone2'] ?? '—'}'),
      ),
      ListTile(
        title: Text(_t('address')),
        subtitle: Text('${supplier['address'] ?? '—'}'),
      ),
      ListTile(
        title: Text(_t('notes')),
        subtitle: Text('${supplier['notes'] ?? '—'}'),
      ),
    ],
  );

  Future<void> _newPurchase([Map<String, Object?>? selectedSupplier]) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FabricPurchaseScreen(
          database: widget.database,
          supplierId: selectedSupplier?['id'] as int?,
        ),
      ),
    );
    if (result != null) {
      await _load();
      if (result != 'draft-saved' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('purchasePosted').replaceFirst('{number}', result),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openPurchaseDraft(int draftId) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            FabricPurchaseScreen(database: widget.database, draftId: draftId),
      ),
    );
    if (result != null) {
      await _load();
      if (result != 'draft-saved' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('purchasePosted').replaceFirst('{number}', result),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showPurchaseDrafts() async {
    final drafts = await widget.database.fabricPurchaseDrafts();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('purchaseDrafts')),
        content: SizedBox(
          width: 520,
          child: drafts.isEmpty
              ? Text(_t('noPurchaseDrafts'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final draft in drafts)
                      ListTile(
                        leading: const Icon(Icons.edit_note),
                        title: Text(
                          '${draft['number']} · ${draft['supplier_name']}',
                        ),
                        subtitle: Text(
                          '${_t('draftLines').replaceFirst('{count}', '${draft['line_count']}')} · ${_money((draft['total'] as num).toInt())}',
                        ),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _openPurchaseDraft(draft['id'] as int);
                        },
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  Future<void> _paySupplier(Map<String, Object?> supplier) async {
    final supplierId = supplier['id'] as int;
    final purchases = await widget.database.db.query(
      'fabric_purchases',
      where: "supplier_id=? AND status='Posted' AND paid<total",
      whereArgs: [supplierId],
      orderBy: 'date,id',
    );
    if (!mounted) return;
    var purchaseId = purchases.isEmpty ? null : purchases.first['id'] as int?;
    var allocateOldest = true;
    var date = CalendarService.shopToday();
    var method = 'Cash';
    var saving = false;
    final amount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    final posted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: Text(_t('paySupplier')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${supplier['name']} · ${_t('currentOwed')}: ${_money(_balance(supplier).clamp(0, 1 << 30).toInt())} · ${_t('supplierCredit')}: ${_money((-_balance(supplier)).clamp(0, 1 << 30).toInt())}',
                  ),
                  if (purchases.isEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(_t('noUnpaidPurchases')),
                    )
                  else
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allocateOldest,
                      title: Text(_t('oldestPurchases')),
                      onChanged: (value) =>
                          update(() => allocateOldest = value ?? true),
                    ),
                  if (!allocateOldest)
                    DropdownButtonFormField<int>(
                      initialValue: purchaseId!,
                      decoration: InputDecoration(
                        labelText: _t('allocateToPurchase'),
                      ),
                      items: purchases.map((purchase) {
                        final due =
                            (purchase['total'] as int) -
                            (purchase['paid'] as int);
                        return DropdownMenuItem(
                          value: purchase['id'] as int,
                          child: Text('${purchase['number']} · ${_money(due)}'),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          update(() => purchaseId = value ?? purchaseId),
                    ),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _t('amountPaid'),
                      suffixText: 'AFN',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final value = await showAppDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: CalendarService.shopToday(),
                        helpText: _t('paymentDate'),
                      );
                      if (value != null) update(() => date = value);
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      '${_t('paymentDate')}: ${formatDate(date.toIso8601String(), locale: Localizations.localeOf(context).toLanguageTag())}',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: InputDecoration(labelText: _t('paymentMethod')),
                    items: ['Cash', 'Bank transfer', 'Other']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value == 'Cash'
                                  ? context.l10n.cash
                                  : value == 'Bank transfer'
                                  ? context.l10n.bankTransfer
                                  : context.l10n.other,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        update(() => method = value ?? method),
                  ),
                  TextField(
                    controller: reference,
                    decoration: InputDecoration(
                      labelText: _t('externalReference'),
                    ),
                  ),
                  TextField(
                    controller: notes,
                    decoration: InputDecoration(labelText: _t('notes')),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CommandButton(id: 'action.cancel', child: TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: Text(context.l10n.cancel),
            )),
            CommandButton(id: 'action.save', child: FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final value = parseMoneyMinor(amount.text);
                      if (value == null || value <= 0) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(_t('invalidAmount'))),
                        );
                        return;
                      }
                      update(() => saving = true);
                      try {
                        final targets = allocateOldest || purchases.isEmpty
                            ? purchases
                            : purchases.where((row) => row['id'] == purchaseId);
                        var remaining = value;
                        final allocations = <int, int>{};
                        for (final purchase in targets) {
                          final due =
                              (purchase['total'] as int) -
                              (purchase['paid'] as int);
                          final applied = remaining < due ? remaining : due;
                          if (applied > 0) {
                            allocations[purchase['id'] as int] = applied;
                            remaining -= applied;
                          }
                          if (remaining == 0) break;
                        }
                        if (remaining > 0) {
                          final confirmed = await showDialog<bool>(
                            context: dialogContext,
                            builder: (confirmContext) => AlertDialog(
                              title: Text(_t('supplierCredit')),
                              content: Text(
                                _t(
                                  'confirmSupplierAdvance',
                                ).replaceFirst('{amount}', _money(remaining)),
                              ),
                              actions: [
                                CommandButton(id: 'action.cancel', child: TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: Text(context.l10n.cancel),
                                )),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: Text(_t('continueAnyway')),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) {
                            update(() => saving = false);
                            return;
                          }
                        }
                        final receipt = await widget.database.recordSupplierPayment(
                          supplierId: supplierId,
                          amount: value,
                          date: date,
                          method: method,
                          allocations: allocations,
                          reference: reference.text,
                          notes: notes.text,
                          operationId:
                              'supplier-payment-${DateTime.now().microsecondsSinceEpoch}',
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _t('paymentSaved')
                                    .replaceFirst('{number}', receipt),
                              ),
                            ),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          update(() => saving = false);
                          ScaffoldMessenger.of(dialogContext)
                              .showSnackBar(SnackBar(content: Text('$error')));
                        }
                      }
                    },
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.payments_outlined),
              label: Text(_t('savePayment')),
            )),
          ],
        ),
      ),
    );
    amount.dispose();
    reference.dispose();
    notes.dispose();
    if (posted == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = _visible;
    final active = _rows.where((row) => (row['archived'] as num? ?? 0) == 0);
    final owed = active.fold<int>(
      0,
      (sum, row) => sum + _balance(row).clamp(0, 1 << 30).toInt(),
    );
    final credit = active.fold<int>(
      0,
      (sum, row) => sum + (-_balance(row)).clamp(0, 1 << 30).toInt(),
    );
    return CommandScope(commands: _keyboardCommands(), builder: (context) => Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ResponsiveListPage(
          header: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: Text(
                    _t('suppliers'),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                CommandButton(register: false, aliases: const ['action.new'], id: 'suppliers.add', child: FilledButton.icon(
                  onPressed: () => _supplierForm(),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(_t('addSupplier')),
                )),
                OutlinedButton.icon(
                  onPressed: () => _newPurchase(),
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: Text(_t('newPurchase')),
                ),
                TextButton.icon(
                  onPressed: _showPurchaseDrafts,
                  icon: const Icon(Icons.edit_note),
                  label: Text(_t('purchaseDrafts')),
                ),
                IconButton(
                  tooltip: l10n.refresh,
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 700 ? 1 : 3;
                final gap = 10.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: _summaryCard(
                        _t('activeSuppliers'),
                        '${active.length}',
                        Icons.groups_outlined,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _summaryCard(
                        _t('amountOwed'),
                        _money(owed),
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _summaryCard(
                        _t('availableCredit'),
                        _money(credit),
                        Icons.credit_score_outlined,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => _load(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: _t('searchSupplier'),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _filter,
                    items: [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(_t('allActive')),
                      ),
                      DropdownMenuItem(
                        value: 'owing',
                        child: Text(_t('withBalance')),
                      ),
                      DropdownMenuItem(
                        value: 'credit',
                        child: Text(_t('withCredit')),
                      ),
                      DropdownMenuItem(
                        value: 'archived',
                        child: Text(_t('archived')),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filter = value ?? 'active'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_t('loadError')),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ],
                  ),
                )
              : visible.isEmpty
              ? Center(child: Text(_t('noSuppliers')))
              : LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 900
                      ? ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) => CommandRecordTarget(kind: 'supplier', record: visible[index], child: _supplierCard(visible[index])),
                        )
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: HorizontalTable(
                            child: SingleChildScrollView(
                              child: DataTable(
                                columns: [
                                  DataColumn(label: Text(_t('supplierId'))),
                                  DataColumn(label: Text(_t('name'))),
                                  DataColumn(label: Text(_t('mobile'))),
                                  DataColumn(label: Text(_t('company'))),
                                  DataColumn(
                                    label: Text(_t('amountOwed')),
                                    numeric: true,
                                  ),
                                  DataColumn(
                                    label: Text(_t('supplierCredit')),
                                    numeric: true,
                                  ),
                                  DataColumn(label: Text(_t('actions'))),
                                ],
                                rows: [
                                  for (final row in visible) _supplierRow(row),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
        ),
      ),
    ));
  }

  Future<void> _supplierCommand(Future<void> Function(Map<String, Object?>) action, {bool Function(Map<String, Object?>)? eligible}) =>
      withCommandRecord(context, 'supplier', widget.database.suppliers(includeArchived: true), action, eligible: eligible);

  List<AppCommand> _keyboardCommands() => [
    AppCommand('suppliers.add', () => _supplierForm(), aliases: [CommandKey.add]),
    AppCommand('suppliers.edit', () => _supplierCommand(_supplierForm), aliases: [CommandKey.edit]),
    AppCommand('suppliers.remove', () => _supplierCommand(_delete), aliases: [CommandKey.remove]),
    AppCommand('suppliers.archive', () => _supplierCommand((row) => _archive(row, (row['archived'] as num? ?? 0) != 0))),
    AppCommand('suppliers.payment', () => _supplierCommand(_paySupplier, eligible: (row) => (row['archived'] as num? ?? 0) == 0)),
    AppCommand('nav.supplierLedger', () => _supplierCommand((row) => _profile(row, initialTabIndex: 1))),
    AppCommand('purchases.new', () => _newPurchase()),
    AppCommand('purchases.drafts', _showPurchaseDrafts),
    AppCommand(CommandKey.search, () => focusCommandSearch(_search)),
    AppCommand(CommandKey.refresh, _load),
  ];

  Widget _summaryCard(String title, String value, IconData icon) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  DataRow _supplierRow(Map<String, Object?> row) {
    final balance = _balance(row);
    return DataRow(
      selected: AppCommandRegistry.maybeOf(context)?.selected('supplier')?['id'] == row['id'],
      onSelectChanged: (_) => AppCommandRegistry.maybeOf(context)?.select('supplier', row),
      cells: [
        DataCell(Text('${row['code'] ?? 'S${row['id']}'}')),
        DataCell(Text('${row['name']}')),
        DataCell(Text('${row['phone'] ?? ''}')),
        DataCell(Text('${row['company'] ?? ''}')),
        DataCell(Text(_money(balance > 0 ? balance : 0))),
        DataCell(Text(_money(balance < 0 ? balance : 0))),
        DataCell(_actions(row)),
      ],
    );
  }

  Widget _supplierCard(Map<String, Object?> row) {
    final balance = _balance(row);
    final archived = (row['archived'] as num? ?? 0) == 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(Icons.storefront_outlined),
              ),
              title: Text('${row['name']}'),
              subtitle: Text(
                '${row['code'] ?? ''} · ${row['phone'] ?? ''} · ${row['company'] ?? ''}',
              ),
              trailing: archived ? Chip(label: Text(_t('archived'))) : null,
              onTap: () => _profile(row),
            ),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  '${_t('amountOwed')}: ${_money(balance > 0 ? balance : 0)}',
                ),
                Text(
                  '${_t('supplierCredit')}: ${_money(balance < 0 ? balance : 0)}',
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: _actions(row),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(Map<String, Object?> row) {
    final archived = (row['archived'] as num? ?? 0) == 1;
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: [
        IconButton(
          tooltip: _t('viewProfile'),
          onPressed: () => _profile(row),
          icon: const Icon(Icons.open_in_new),
        ),
        IconButton(
          tooltip: _t('editSupplier'),
          onPressed: () => _supplierForm(row),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: archived ? _t('restore') : _t('archive'),
          onPressed: () => _archive(row, archived),
          icon: Icon(
            archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          ),
        ),
        IconButton(
          tooltip: _t('deleteSupplier'),
          onPressed: () => _delete(row),
          icon: const Icon(Icons.delete_outline),
        ),
        if (!archived)
          IconButton(
            tooltip: _t('paySupplier'),
            onPressed: () => _paySupplier(row),
            icon: const Icon(Icons.payments_outlined),
          ),
      ],
    );
  }
}

const _supplierWords = <String, Map<String, String>>{
  'en': {
    'suppliers': 'Suppliers',
    'supplier': 'Supplier',
    'supplierId': 'Supplier ID',
    'addSupplier': 'Add supplier',
    'editSupplier': 'Edit supplier',
    'newPurchase': 'New fabric purchase',
    'purchaseDrafts': 'Purchase drafts',
    'noPurchaseDrafts': 'No saved purchase drafts.',
    'draftLines': 'Lines: {count}',
    'posted': 'Posted',
    'draft': 'Draft',
    'name': 'Name',
    'company': 'Company / shop',
    'mobile': 'Primary mobile',
    'mobile2': 'Second mobile (optional)',
    'address': 'Address',
    'notes': 'Notes',
    'openingBalance': 'Opening balance',
    'balanceType': 'Balance type',
    'shopOwesSupplier': 'Shop owes supplier',
    'supplierCredit': 'Supplier credit',
    'openingAmountOptional': 'Opening amount (optional)',
    'effectiveDate': 'Effective date',
    'nameRequired': 'Supplier name is required.',
    'invalidAmount': 'Enter a valid amount.',
    'possibleDuplicate': 'Possible duplicate supplier',
    'sharedPhoneWarning': 'This phone is already used by another supplier. Continue if they share a phone.',
    'continueAnyway': 'Continue anyway',
    'archiveSupplier': 'Archive supplier',
    'restoreSupplier': 'Restore supplier',
    'archiveConfirm': 'Archive this supplier? Their purchase and ledger history will be preserved.',
    'restoreConfirm': 'Restore this supplier?',
    'archive': 'Archive',
    'restore': 'Restore',
    'delete': 'Delete',
    'deleteSupplier': 'Delete supplier',
    'deleteConfirm': 'Delete permanently only if this supplier has no purchase or financial history?',
    'supplierDeleted': 'Supplier deleted.',
    'hasHistory': 'This supplier has history. Archive them instead.',
    'activeSuppliers': 'Active suppliers',
    'amountOwed': 'Amount owed',
    'availableCredit': 'Available supplier credit',
    'searchSupplier': 'Search by name, mobile, or supplier ID',
    'allActive': 'All active',
    'withBalance': 'With outstanding balance',
    'withCredit': 'With supplier credit',
    'archived': 'Archived',
    'actions': 'Actions',
    'viewProfile': 'View profile',
    'currentOwed': 'Current amount owed',
    'purchases': 'Purchases',
    'ledger': 'Supplier ledger',
    'payments': 'Payments',
    'information': 'Information',
    'noPurchases': 'No purchases yet.',
    'noLedger': 'No ledger entries.',
    'noPayments': 'No supplier payments yet.',
    'remaining': 'Remaining',
    'noSuppliers': 'No suppliers found.',
    'loadError': 'Suppliers could not be loaded.',
    'addSupplierFirst': 'Add a supplier first.',
    'addFabricFirst': 'Add fabric before recording a purchase.',
    'fabric': 'Fabric',
    'invoiceReference': 'Supplier invoice reference',
    'purchaseDate': 'Purchase date',
    'quantityAndUnit': 'Quantity ({unit})',
    'unitCost': 'Purchase cost per unit',
    'paidNow': 'Amount paid now',
    'paymentMethod': 'Payment method',
    'invalidPurchaseValues': 'Enter a valid quantity, cost, and payment.',
    'duplicateInvoiceWarning': 'A posted purchase already uses this invoice reference for the selected supplier. Continue?',
    'postPurchase': 'Post purchase',
    'purchasePosted': 'Purchase {number} posted.',
    'noUnpaidPurchases': 'This supplier has no unpaid purchases.',
    'paySupplier': 'Pay supplier',
    'allocateToPurchase': 'Allocate to purchase',
    'amountPaid': 'Amount paid',
    'paymentDate': 'Payment date',
    'externalReference': 'External reference',
    'paymentSaved': 'Payment {number} saved.',
    'savePayment': 'Save payment',
    'oldestPurchases': 'Allocate across oldest unpaid purchases first',
    'purchaseNumber': 'Purchase number',
    'supplierBill': 'Supplier bill',
    'linkedPurchases': 'Linked purchases',
    'paymentVoucher': 'Payment voucher',
    'allocatedToPurchases': 'Allocated to purchases',
    'advanceCredit': 'Supplier advance credit',
    'confirmSupplierAdvance':
        'The remaining {amount} will be saved as supplier credit. Continue?',
  },
  'ps': {
    'suppliers': 'عرضه کوونکي',
    'supplier': 'عرضه کوونکی',
    'supplierId': 'د عرضه کوونکي پېژندشمېره',
    'addSupplier': 'عرضه کوونکی زیاتول',
    'editSupplier': 'د عرضه کوونکي سمول',
    'newPurchase': 'د ټوکر نوې پېرودنه',
    'purchaseDrafts': 'د پېرود مسودې',
    'noPurchaseDrafts': 'د پېرود هېڅ مسوده نه ده ساتل شوې.',
    'draftLines': 'د کرښو شمېر: {count}',
    'posted': 'ثبت شوی',
    'draft': 'مسوده',
    'name': 'نوم',
    'company': 'شرکت / دوکان',
    'mobile': 'اصلي ګرځنده شمېره',
    'mobile2': 'دویمه ګرځنده شمېره (اختیاري)',
    'address': 'پته',
    'notes': 'یادښتونه',
    'openingBalance': 'لومړنی بیلانس',
    'balanceType': 'د بیلانس ډول',
    'shopOwesSupplier': 'دوکان عرضه کوونکي ته پوروړی دی',
    'supplierCredit': 'د عرضه کوونکي کریډیټ',
    'openingAmountOptional': 'د پیل اندازه (اختیاري)',
    'effectiveDate': 'د تطبیق نېټه',
    'nameRequired': 'د عرضه کوونکي نوم اړین دی.',
    'invalidAmount': 'سمه اندازه ولیکئ.',
    'possibleDuplicate': 'احتمالي تکراري عرضه کوونکی',
    'sharedPhoneWarning': 'دا تلیفون شمېره له بل عرضه کوونکي سره هم شریکه ده. که شمېره ګډه وي، دوام ورکړئ.',
    'continueAnyway': 'بیا هم دوام',
    'archiveSupplier': 'عرضه کوونکی آرشیف کړئ',
    'restoreSupplier': 'عرضه کوونکی بېرته فعال کړئ',
    'archiveConfirm':
        'دا عرضه کوونکی آرشیف کړئ؟ د پېرود او حساب مخینه به خوندي پاتې شي.',
    'restoreConfirm': 'دا عرضه کوونکی بېرته فعال کړئ؟',
    'archive': 'آرشیف کول',
    'restore': 'بېرته فعالول',
    'delete': 'ړنګول',
    'deleteSupplier': 'عرضه کوونکی ړنګول',
    'deleteConfirm': 'یوازې هغه وخت یې د تل لپاره ړنګ کړئ چې د پېرود یا مالي حساب مخینه ونه لري.',
    'supplierDeleted': 'عرضه کوونکی ړنګ شو.',
    'hasHistory': 'د دې عرضه کوونکي مخینه شته. پر ځای یې آرشیف کړئ.',
    'activeSuppliers': 'فعال عرضه کوونکي',
    'amountOwed': 'پور',
    'availableCredit': 'د عرضه کوونکي موجود کریډیټ',
    'searchSupplier': 'د نوم، ګرځنده شمېرې یا پېژندشمېرې له مخې لټون',
    'allActive': 'ټول فعال',
    'withBalance': 'د پاتې پور لرونکي',
    'withCredit': 'د کریډیټ لرونکي',
    'archived': 'آرشیف شوي',
    'actions': 'کړنې',
    'viewProfile': 'پروفایل کتل',
    'currentOwed': 'اوسنی پور',
    'purchases': 'پېرودنې',
    'ledger': 'د عرضه کوونکي حساب کتاب',
    'payments': 'تادیې',
    'information': 'معلومات',
    'noPurchases': 'تر اوسه پېرودنه نشته.',
    'noLedger': 'د حساب کتاب ریکارډ نشته.',
    'noPayments': 'تر اوسه عرضه کوونکي ته تادیه نه ده ثبت شوې.',
    'remaining': 'پاتې',
    'noSuppliers': 'عرضه کوونکی ونه موندل شو.',
    'loadError': 'د عرضه کوونکو معلومات نه دي لوډ شوي.',
    'addSupplierFirst': 'لومړی عرضه کوونکی زیات کړئ.',
    'addFabricFirst': 'د پېرود ثبتولو مخکې ټوکر زیات کړئ.',
    'fabric': 'ټوکر',
    'invoiceReference': 'د عرضه کوونکي د بل حواله',
    'purchaseDate': 'د پېرود نېټه',
    'quantityAndUnit': 'اندازه ({unit})',
    'unitCost': 'د هر واحد د پېرود لګښت',
    'paidNow': 'اوس ورکړل شوې اندازه',
    'paymentMethod': 'د تادیې طریقه',
    'invalidPurchaseValues': 'سمه اندازه، لګښت او تادیه ولیکئ.',
    'duplicateInvoiceWarning': 'د ټاکل شوي عرضه کوونکي لپاره پېرود لا دمخه د دې بل په حواله ثبت شوی. دوام کوئ؟',
    'postPurchase': 'پېرود ثبتول',
    'purchasePosted': 'پېرود {number} ثبت شو.',
    'noUnpaidPurchases': 'دغه عرضه کوونکی بې تادیې پېرودنه نه لري.',
    'paySupplier': 'عرضه کوونکي ته تادیه',
    'allocateToPurchase': 'پېرود ته ځانګړې کول',
    'amountPaid': 'ورکړل شوې اندازه',
    'paymentDate': 'د تادیې نېټه',
    'externalReference': 'بهرنۍ حواله',
    'paymentSaved': 'تادیه {number} ثبت شوه.',
    'savePayment': 'تادیه ثبتول',
    'oldestPurchases':
        'لومړی پیسې تر ټولو پخوانیو بې تادیې پېرودونو ته ځانګړې کړئ.',
    'purchaseNumber': 'د پېرود شمېره',
    'supplierBill': 'د عرضه کوونکي بل',
    'linkedPurchases': 'تړلې پېرودنې',
    'paymentVoucher': 'د تادیې رسید',
    'allocatedToPurchases': 'پېرودونو ته ځانګړې شوې اندازه',
    'advanceCredit': 'د عرضه کوونکي مخکې ورکړل شوی کریډیټ',
    'confirmSupplierAdvance':
        'پاتې {amount} به د عرضه کوونکي د کریډیټ په توګه ثبت شي. دوام کوئ؟',
  },
  'fa': {
    'suppliers': 'ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ú¯Ø§Ù†',
    'supplier': 'ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'supplierId': 'Ø´Ù†Ø§Ø³Ù‡ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'addSupplier': 'Ø§ÙØ²ÙˆØ¯Ù† ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'editSupplier': 'ÙˆÛŒØ±Ø§ÛŒØ´ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'newPurchase': 'Ø®Ø±ÛŒØ¯ Ø¬Ø¯ÛŒØ¯ Ù¾Ø§Ø±Ú†Ù‡',
    'purchaseDrafts': 'پیش‌نویس‌های خرید',
    'noPurchaseDrafts': 'پیش‌نویس خریدی ذخیره نشده است.',
    'name': 'Ù†Ø§Ù…',
    'company': 'Ø´Ø±Ú©Øª / Ø¯Ú©Ø§Ù†',
    'mobile': 'Ù…ÙˆØ¨Ø§ÛŒÙ„ Ø§ØµÙ„ÛŒ',
    'mobile2': 'Ù…ÙˆØ¨Ø§ÛŒÙ„ Ø¯ÙˆÙ… (Ø§Ø®ØªÛŒØ§Ø±ÛŒ)',
    'address': 'Ù†Ø´Ø§Ù†ÛŒ',
    'notes': 'ÛŒØ§Ø¯Ø¯Ø§Ø´Øªâ€ŒÙ‡Ø§',
    'openingBalance': 'Ù…Ø§Ù†Ø¯Ù‡ Ø§ÙØªØªØ§Ø­ÛŒÙ‡',
    'balanceType': 'Ù†ÙˆØ¹ Ù…Ø§Ù†Ø¯Ù‡',
    'shopOwesSupplier':
        'Ø¯Ú©Ø§Ù† Ø¨Ù‡ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø¨Ø¯Ù‡Ú©Ø§Ø± Ø§Ø³Øª',
    'supplierCredit': 'Ø§Ø¹ØªØ¨Ø§Ø± ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'openingAmountOptional': 'Ù…Ø¨Ù„Øº Ø§ÙØªØªØ§Ø­ÛŒÙ‡ (Ø§Ø®ØªÛŒØ§Ø±ÛŒ)',
    'effectiveDate': 'ØªØ§Ø±ÛŒØ® Ù…Ø¤Ø«Ø±',
    'nameRequired': 'Ù†Ø§Ù… ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø§Ù„Ø²Ø§Ù…ÛŒ Ø§Ø³Øª.',
    'invalidAmount': 'Ù…Ø¨Ù„Øº Ù…Ø¹ØªØ¨Ø± ÙˆØ§Ø±Ø¯ Ú©Ù†ÛŒØ¯.',
    'possibleDuplicate':
        'ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø§Ø­ØªÙ…Ø§Ù„Ø§Ù‹ ØªÚ©Ø±Ø§Ø±ÛŒ Ø§Ø³Øª',
    'sharedPhoneWarning': 'Ø§ÛŒÙ† Ø´Ù…Ø§Ø±Ù‡ Ø¨Ø±Ø§ÛŒ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø¯ÛŒÚ¯Ø±ÛŒ Ù†ÛŒØ² Ø«Ø¨Øª Ø´Ø¯Ù‡ Ø§Ø³Øª. Ø§Ú¯Ø± Ø´Ù…Ø§Ø±Ù‡ Ù…Ø´ØªØ±Ú© Ø§Ø³Øª Ø§Ø¯Ø§Ù…Ù‡ Ø¯Ù‡ÛŒØ¯.',
    'continueAnyway': 'Ø¯Ø± Ù‡Ø± ØµÙˆØ±Øª Ø§Ø¯Ø§Ù…Ù‡',
    'archiveSupplier': 'Ø¨Ø§ÛŒÚ¯Ø§Ù†ÛŒ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'restoreSupplier': 'Ø¨Ø§Ø²ÛŒØ§Ø¨ÛŒ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'archiveConfirm': 'Ø§ÛŒÙ† ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø¨Ø§ÛŒÚ¯Ø§Ù†ÛŒ Ø´ÙˆØ¯ØŸ Ø³Ø§Ø¨Ù‚Ù‡ Ø®Ø±ÛŒØ¯ Ùˆ Ø­Ø³Ø§Ø¨ Ø­ÙØ¸ Ù…ÛŒâ€ŒØ´ÙˆØ¯.',
    'restoreConfirm': 'Ø§ÛŒÙ† ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø¨Ø§Ø²ÛŒØ§Ø¨ÛŒ Ø´ÙˆØ¯ØŸ',
    'archive': 'Ø¨Ø§ÛŒÚ¯Ø§Ù†ÛŒ',
    'restore': 'Ø¨Ø§Ø²ÛŒØ§Ø¨ÛŒ',
    'delete': 'Ø­Ø°Ù',
    'deleteSupplier': 'Ø­Ø°Ù ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'deleteConfirm': 'ÙÙ‚Ø· Ø¯Ø± ØµÙˆØ±ØªÛŒ Ø¨Ø±Ø§ÛŒ Ù‡Ù…ÛŒØ´Ù‡ Ø­Ø°Ù Ø´ÙˆØ¯ Ú©Ù‡ Ø³Ø§Ø¨Ù‚Ù‡ Ø®Ø±ÛŒØ¯ ÛŒØ§ Ù…Ø§Ù„ÛŒ Ù†Ø¯Ø§Ø´ØªÙ‡ Ø¨Ø§Ø´Ø¯ØŸ',
    'supplierDeleted': 'ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø­Ø°Ù Ø´Ø¯.',
    'hasHistory': 'Ø§ÛŒÙ† ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø³Ø§Ø¨Ù‚Ù‡ Ø¯Ø§Ø±Ø¯. Ø¢Ù† Ø±Ø§ Ø¨Ø§ÛŒÚ¯Ø§Ù†ÛŒ Ú©Ù†ÛŒØ¯.',
    'activeSuppliers': 'ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ú¯Ø§Ù† ÙØ¹Ø§Ù„',
    'amountOwed': 'Ù…Ø¨Ù„Øº Ø¨Ø¯Ù‡ÛŒ',
    'availableCredit': 'Ø§Ø¹ØªØ¨Ø§Ø± Ù…ÙˆØ¬ÙˆØ¯ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'searchSupplier':
        'Ø¬Ø³ØªØ¬Ùˆ Ø¨Ø± Ø§Ø³Ø§Ø³ Ù†Ø§Ù…ØŒ Ù…ÙˆØ¨Ø§ÛŒÙ„ ÛŒØ§ Ø´Ù†Ø§Ø³Ù‡',
    'allActive': 'Ù‡Ù…Ù‡ ÙØ¹Ø§Ù„',
    'withBalance': 'Ø¯Ø§Ø±Ø§ÛŒ Ù…Ø§Ù†Ø¯Ù‡ Ø¨Ø¯Ù‡ÛŒ',
    'withCredit': 'Ø¯Ø§Ø±Ø§ÛŒ Ø§Ø¹ØªØ¨Ø§Ø± ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'archived': 'Ø¨Ø§ÛŒÚ¯Ø§Ù†ÛŒâ€ŒØ´Ø¯Ù‡',
    'actions': 'Ø¹Ù…Ù„ÛŒØ§Øª',
    'viewProfile': 'Ù…Ø´Ø§Ù‡Ø¯Ù‡ Ù¾Ø±ÙˆÙØ§ÛŒÙ„',
    'currentOwed': 'Ø¨Ø¯Ù‡ÛŒ ÙØ¹Ù„ÛŒ',
    'purchases': 'Ø®Ø±ÛŒØ¯Ù‡Ø§',
    'ledger': 'Ø¯ÙØªØ± Ø­Ø³Ø§Ø¨ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'payments': 'Ù¾Ø±Ø¯Ø§Ø®Øªâ€ŒÙ‡Ø§',
    'information': 'Ù…Ø¹Ù„ÙˆÙ…Ø§Øª',
    'noPurchases': 'Ù‡Ù†ÙˆØ² Ø®Ø±ÛŒØ¯ÛŒ Ø«Ø¨Øª Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª.',
    'noLedger': 'Ø«Ø¨Øª Ø­Ø³Ø§Ø¨ Ù…ÙˆØ¬ÙˆØ¯ Ù†ÛŒØ³Øª.',
    'noPayments': 'Ù‡Ù†ÙˆØ² Ù¾Ø±Ø¯Ø§Ø®ØªÛŒ Ø¨Ù‡ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø«Ø¨Øª Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª.',
    'remaining': 'Ø¨Ø§Ù‚ÛŒâ€ŒÙ…Ø§Ù†Ø¯Ù‡',
    'noSuppliers': 'ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡â€ŒØ§ÛŒ ÛŒØ§ÙØª Ù†Ø´Ø¯.',
    'loadError':
        'Ø¨Ø§Ø±Ú¯Ø°Ø§Ø±ÛŒ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ú¯Ø§Ù† Ø§Ù†Ø¬Ø§Ù… Ù†Ø´Ø¯.',
    'addSupplierFirst':
        'Ø§Ø¨ØªØ¯Ø§ ÛŒÚ© ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø§Ø¶Ø§ÙÙ‡ Ú©Ù†ÛŒØ¯.',
    'addFabricFirst':
        'Ù¾ÛŒØ´ Ø§Ø² Ø«Ø¨Øª Ø®Ø±ÛŒØ¯ØŒ Ù¾Ø§Ø±Ú†Ù‡ Ø§Ø¶Ø§ÙÙ‡ Ú©Ù†ÛŒØ¯.',
    'fabric': 'Ù¾Ø§Ø±Ú†Ù‡',
    'invoiceReference': 'Ù…Ø±Ø¬Ø¹ Ø¨Ù„ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'purchaseDate': 'ØªØ§Ø±ÛŒØ® Ø®Ø±ÛŒØ¯',
    'quantityAndUnit': 'Ù…Ù‚Ø¯Ø§Ø± ({unit})',
    'unitCost': 'Ù‡Ø²ÛŒÙ†Ù‡ Ø®Ø±ÛŒØ¯ Ù‡Ø± ÙˆØ§Ø­Ø¯',
    'paidNow': 'Ù…Ø¨Ù„Øº Ù¾Ø±Ø¯Ø§Ø®Øªâ€ŒØ´Ø¯Ù‡ ÙØ¹Ù„ÛŒ',
    'paymentMethod': 'Ø±ÙˆØ´ Ù¾Ø±Ø¯Ø§Ø®Øª',
    'invalidPurchaseValues':
        'Ù…Ù‚Ø¯Ø§Ø±ØŒ Ù‡Ø²ÛŒÙ†Ù‡ Ùˆ Ù¾Ø±Ø¯Ø§Ø®Øª Ù…Ø¹ØªØ¨Ø± ÙˆØ§Ø±Ø¯ Ú©Ù†ÛŒØ¯.',
    'duplicateInvoiceWarning': 'Ø§ÛŒÙ† Ù…Ø±Ø¬Ø¹ Ø¨Ù„ Ø¨Ø±Ø§ÛŒ Ø®Ø±ÛŒØ¯ Ø«Ø¨Øªâ€ŒØ´Ø¯Ù‡ Ù‡Ù…ÛŒÙ† ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ù…ÙˆØ¬ÙˆØ¯ Ø§Ø³Øª. Ø§Ø¯Ø§Ù…Ù‡ Ù…ÛŒâ€ŒØ¯Ù‡ÛŒØ¯ØŸ',
    'postPurchase': 'Ø«Ø¨Øª Ø®Ø±ÛŒØ¯',
    'purchasePosted': 'Ø®Ø±ÛŒØ¯ {number} Ø«Ø¨Øª Ø´Ø¯.',
    'noUnpaidPurchases': 'Ø§ÛŒÙ† ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø®Ø±ÛŒØ¯ Ù¾Ø±Ø¯Ø§Ø®Øªâ€ŒÙ†Ø´Ø¯Ù‡ Ù†Ø¯Ø§Ø±Ø¯.',
    'paySupplier': 'Ù¾Ø±Ø¯Ø§Ø®Øª Ø¨Ù‡ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'allocateToPurchase': 'ØªØ®ØµÛŒØµ Ø¨Ù‡ Ø®Ø±ÛŒØ¯',
    'amountPaid': 'Ù…Ø¨Ù„Øº Ù¾Ø±Ø¯Ø§Ø®Øªâ€ŒØ´Ø¯Ù‡',
    'paymentDate': 'ØªØ§Ø±ÛŒØ® Ù¾Ø±Ø¯Ø§Ø®Øª',
    'externalReference': 'Ù…Ø±Ø¬Ø¹ Ø¨ÛŒØ±ÙˆÙ†ÛŒ',
    'paymentSaved': 'Ù¾Ø±Ø¯Ø§Ø®Øª {number} Ø«Ø¨Øª Ø´Ø¯.',
    'savePayment': 'Ø«Ø¨Øª Ù¾Ø±Ø¯Ø§Ø®Øª',
    'oldestPurchases': 'Ø§Ø¨ØªØ¯Ø§ Ù…ÛŒØ§Ù† Ø®Ø±ÛŒØ¯Ù‡Ø§ÛŒ Ù¾Ø±Ø¯Ø§Ø®Øªâ€ŒÙ†Ø´Ø¯Ù‡ Ù‚Ø¯ÛŒÙ…ÛŒâ€ŒØªØ± ØªØ®ØµÛŒØµ Ø´ÙˆØ¯',
    'purchaseNumber': 'Ø´Ù…Ø§Ø±Ù‡ Ø®Ø±ÛŒØ¯',
    'supplierBill': 'Ø¨Ù„ ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'linkedPurchases': 'Ø®Ø±ÛŒØ¯Ù‡Ø§ÛŒ Ù…Ø±ØªØ¨Ø·',
    'paymentVoucher': 'Ø±Ø³ÛŒØ¯ Ù¾Ø±Ø¯Ø§Ø®Øª',
    'allocatedToPurchases': 'ØªØ®ØµÛŒØµâ€ŒÛŒØ§ÙØªÙ‡ Ø¨Ù‡ Ø®Ø±ÛŒØ¯Ù‡Ø§',
    'advanceCredit':
        'Ø§Ø¹ØªØ¨Ø§Ø± Ù¾ÛŒØ´â€ŒÙ¾Ø±Ø¯Ø§Ø®Øª ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡',
    'confirmSupplierAdvance': 'Ù…Ø¨Ù„Øº Ø¨Ø§Ù‚ÛŒâ€ŒÙ…Ø§Ù†Ø¯Ù‡ {amount} Ø¨Ù‡â€ŒØ¹Ù†ÙˆØ§Ù† Ø§Ø¹ØªØ¨Ø§Ø± ØªØ£Ù…ÛŒÙ†â€ŒÚ©Ù†Ù†Ø¯Ù‡ Ø«Ø¨Øª Ù…ÛŒâ€ŒØ´ÙˆØ¯. Ø§Ø¯Ø§Ù…Ù‡ Ù…ÛŒâ€ŒØ¯Ù‡ÛŒØ¯ØŸ',
  },
};
