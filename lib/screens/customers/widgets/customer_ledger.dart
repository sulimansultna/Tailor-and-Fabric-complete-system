import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../widgets/horizontal_table.dart';

import '../../../core/app_date_picker.dart';
import '../../../core/calendar_service.dart';

import '../../../core/formatters.dart';
import '../../../data/shop_database.dart';
import '../../../l10n/app_localizations_extensions.dart';

class CustomerLedger extends StatefulWidget {
  const CustomerLedger({
    super.key,
    required this.database,
    required this.customer,
    required this.onReceivePayment,
    this.onChanged,
    this.onOpenOrders,
    this.refreshToken = 0,
  });
  final ShopDatabase database;
  final Map<String, Object?> customer;
  final VoidCallback onReceivePayment;
  final VoidCallback? onChanged;
  final VoidCallback? onOpenOrders;
  final int refreshToken;

  @override
  State<CustomerLedger> createState() => _CustomerLedgerState();
}

class _CustomerLedgerState extends State<CustomerLedger>
    with AutomaticKeepAliveClientMixin {
  late Future<_LedgerSnapshot> future;
  final search = TextEditingController();
  final _fallbackScroll = ScrollController();
  ScrollController? _coordinatedScroll;
  ScrollController get scroll => _coordinatedScroll ?? _fallbackScroll;
  DateTime? fromDate;
  DateTime? toDate;
  String type = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<_LedgerSnapshot> _load() async {
    final id = widget.customer['id'] as int;
    final rows = await widget.database.customerLedger(id);
    final credit = await widget.database.availableCustomerCredit(id);
    return _LedgerSnapshot(rows, credit);
  }

  @override
  void didUpdateWidget(covariant CustomerLedger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) future = _load();
  }

  @override
  void dispose() {
    search.dispose();
    _fallbackScroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => future = _load());
    await future;
    widget.onChanged?.call();
  }

  int _delta(Map<String, Object?> row) =>
      (row['charge'] as int) - (row['payment'] as int);

  String _typeOf(Map<String, Object?> row) {
    final description = (row['description'] as String? ?? '').toLowerCase();
    final reference = (row['reference'] as String? ?? '').toUpperCase();
    if (description.startsWith('opening balance')) return 'Adjustments';
    if (description.startsWith('refund') || reference.startsWith('RF-')) {
      return 'Refunds';
    }
    if (description.contains('reversal') || reference.startsWith('REV-')) {
      return 'Adjustments';
    }
    if (description.contains('credit applied') ||
        reference.startsWith('CREDIT-')) {
      return 'Credits';
    }
    if (description.startsWith('adjustment') ||
        description.startsWith('order cancellation')) {
      return 'Adjustments';
    }
    if ((row['charge'] as int) != 0) return 'Charges';
    if ((row['payment'] as int) > 0) return 'Payments';
    return 'Adjustments';
  }

  String _reference(Map<String, Object?> row) {
    final bill = (row['bill_number'] as String?)?.trim() ?? '';
    final order = (row['order_number'] as String?)?.trim() ?? '';
    final reference = (row['receipt'] as String?)?.trim().isNotEmpty == true
        ? row['receipt'] as String
        : row['reference'] as String? ?? '';
    if (bill.isNotEmpty && order.isNotEmpty) return '$bill / $order';
    if (bill.isNotEmpty) return bill;
    if (order.isNotEmpty) return order;
    return reference;
  }

  String _description(BuildContext context, Map<String, Object?> row) {
    final raw = row['description'] as String? ?? '';
    final l10n = context.l10n;
    if (raw == 'Payment received') return l10n.paymentReceived;
    if (raw == 'Order charge') {
      final garments = row['garments'] as String?;
      if (garments != null && garments.isNotEmpty) {
        return garments
            .split(';')
            .map((part) {
              final pieces = part.split('|');
              final key = pieces.first;
              final garment = switch (key) {
                'shalwar' => l10n.shalwar,
                'waistcoat' => l10n.waistcoat,
                'coat' => l10n.coat,
                _ => key,
              };
              final quantity = pieces.length > 1 ? pieces[1] : '1';
              return '$garment ${_word(context, 'stitching')} × $quantity';
            })
            .join(', ');
      }
      return _word(context, 'orderCharge');
    }
    if (raw.startsWith('Order advance')) {
      return _word(context, 'advanceReceived');
    }
    if (raw.startsWith('Refund:')) {
      return '${_word(context, 'refund')}: ${raw.substring('Refund:'.length).trim()}';
    }
    if (raw.startsWith('Adjustment:')) {
      return '${_word(context, 'adjustment')}: ${raw.substring('Adjustment:'.length).trim()}';
    }
    if (raw.startsWith('Opening balance')) {
      return '${_word(context, 'openingBalance')}${raw == 'Opening balance' ? '' : ': ${raw.split(':').skip(1).join(':').trim()}'}';
    }
    if (raw.startsWith('Customer credit applied')) {
      return _word(context, 'creditApplied');
    }
    if (raw.startsWith('Fabric sale')) return _word(context, 'fabricSale');
    if (raw.startsWith('Payment reversal')) {
      return '${_word(context, 'paymentReversal')}: ${raw.substring('Payment reversal:'.length).trim()}';
    }
    if (raw.startsWith('Order cancellation')) {
      return '${_word(context, 'orderCancelled')}: ${raw.split(':').skip(1).join(':').trim()}';
    }
    return raw;
  }

  Future<void> _pickDateRange() async {
    final today = CalendarService.shopToday();
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: fromDate == null && toDate == null
          ? null
          : DateTimeRange(start: fromDate ?? toDate!, end: toDate ?? fromDate!),
    );
    if (picked != null && mounted) {
      setState(() {
        fromDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        );
        toDate = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
    }
  }

  Future<void> _showDetails(Map<String, Object?> row) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final rowType = _typeOf(row);
    final delta = _delta(row);
    final details = <(String, String)>[
      (_word(context, 'reference'), _reference(row)),
      (
        _word(context, 'transactionType'),
        _word(context, rowType.toLowerCase()),
      ),
      (
        _word(context, 'effectiveDate'),
        formatDate(row['date'] as String, locale: locale),
      ),
      (
        _word(context, 'recordedAt'),
        formatDate(
          row['recorded_at'] as String? ?? row['date'] as String,
          locale: locale,
        ),
      ),
      (_word(context, 'amount'), formatMoney(delta.abs(), locale: locale)),
      (
        _word(context, 'paymentMethod'),
        row['payment_method'] as String? ?? row['method'] as String? ?? '—',
      ),
      (_word(context, 'allocations'), row['allocations'] as String? ?? '—'),
      (_word(context, 'notes'), row['payment_notes'] as String? ?? '—'),
    ];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_word(context, 'transactionDetails')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in details)
                  ListTile(
                    dense: true,
                    title: Text(entry.$1),
                    subtitle: SelectableText(
                      entry.$2,
                      textDirection: entry.$1 == _word(context, 'reference')
                          ? TextDirection.ltr
                          : null,
                    ),
                  ),
                ListTile(
                  dense: true,
                  title: Text(_word(context, 'description')),
                  subtitle: Text(_description(context, row)),
                ),
                if (row['order_id'] != null)
                  ListTile(
                    dense: true,
                    title: Text(_word(context, 'relatedOrder')),
                    subtitle: Text(
                      '${row['order_number'] ?? ''} · ${row['bill_number'] ?? l10n.billNotAssigned}',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (row['order_id'] != null && widget.onOpenOrders != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onOpenOrders!();
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(_word(context, 'openOrder')),
            ),
          if (row['payment_id'] is int && row['payment_status'] == 'Posted')
            TextButton.icon(
              onPressed: () async {
                final reason = await _askReason(
                  context,
                  _word(context, 'reversePayment'),
                  _word(context, 'reason'),
                );
                if (reason == null || !mounted) return;
                try {
                  await widget.database.reversePayment(
                    row['payment_id'] as int,
                    reason,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _refresh();
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.errorGeneric}: $error')),
                  );
                }
              },
              icon: const Icon(Icons.undo),
              label: Text(_word(context, 'reversePayment')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason(
    BuildContext context,
    String title,
    String reasonLabel,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: reasonLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: Text(_word(context, 'confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openOpeningBalance() async {
    final result = await _showBalanceEntry(opening: true);
    if (result == null) return;
    try {
      await widget.database.setCustomerOpeningBalance(
        customerId: widget.customer['id'] as int,
        balance: result.$1,
        date: result.$2,
        reason: result.$3,
      );
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openAdjustment() async {
    final result = await _showBalanceEntry(opening: false);
    if (result == null) return;
    try {
      await widget.database.recordCustomerAdjustment(
        customerId: widget.customer['id'] as int,
        signedAmount: result.$1,
        date: result.$2,
        reason: result.$3,
      );
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<(int, DateTime, String)?> _showBalanceEntry({
    required bool opening,
  }) async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    var isCredit = false;
    DateTime date = CalendarService.shopToday();
    final result = await showDialog<(int, DateTime, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            _word(context, opening ? 'setOpeningBalance' : 'recordAdjustment'),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _word(context, 'amount'),
                  ),
                ),
                DropdownButtonFormField<bool>(
                  initialValue: isCredit,
                  decoration: InputDecoration(
                    labelText: _word(context, 'effect'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: false,
                      child: Text(_word(context, 'increaseDebt')),
                    ),
                    DropdownMenuItem(
                      value: true,
                      child: Text(_word(context, 'creditOrReduceDebt')),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => isCredit = value ?? false),
                ),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: _word(context, 'reason'),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () async {
                      final picked = await showAppDatePicker(
                        context: dialogContext,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: CalendarService.shopToday(),
                      );
                      if (picked != null) setDialogState(() => date = picked);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      formatDate(
                        date.toIso8601String(),
                        locale: Localizations.localeOf(context).toLanguageTag(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final parsed = parseMoneyMinor(amount.text);
                if (parsed == null ||
                    parsed <= 0 ||
                    reason.text.trim().isEmpty) {
                  return;
                }
                final signed = isCredit ? -parsed : parsed;
                Navigator.pop(dialogContext, (
                  signed,
                  date,
                  reason.text.trim(),
                ));
              },
              child: Text(_word(context, 'save')),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    reason.dispose();
    return result;
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_word(context, 'saveFailed')}: $error')),
    );
  }

  Future<void> _refundCredit() async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    final result = await showDialog<(int, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_word(context, 'refundCredit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: _word(context, 'amount')),
            ),
            TextField(
              controller: reason,
              maxLines: 2,
              decoration: InputDecoration(labelText: _word(context, 'reason')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = parseMoneyMinor(amount.text);
              if (parsed != null &&
                  parsed > 0 &&
                  reason.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, (parsed, reason.text.trim()));
              }
            },
            child: Text(_word(context, 'confirm')),
          ),
        ],
      ),
    );
    amount.dispose();
    reason.dispose();
    if (result == null) return;
    try {
      await widget.database.refundCustomerCredit(
        customerId: widget.customer['id'] as int,
        amount: result.$1,
        method: 'Cash',
        reason: result.$2,
      );
      await _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  Future<Directory> _exportDirectory() async {
    final local = Platform.environment['LOCALAPPDATA'];
    final root = local == null || local.isEmpty
        ? Directory.systemTemp
        : Directory(local);
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}TailorShop${Platform.pathSeparator}Exports',
    );
    await directory.create(recursive: true);
    return directory;
  }

  String _csvCell(Object? value, {bool userText = false}) {
    var text = value?.toString() ?? '';
    if (userText && RegExp(r'^\s*[=+@\-]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> _exportCsv(
    List<Map<String, Object?>> rows,
    Map<int, int> balances,
    int broughtForward,
    int periodEnd,
  ) async {
    try {
      final lines = <List<Object?>>[
        [
          'Date',
          'Bill / Reference',
          'Description',
          'Charge AFN',
          'Payment / Credit AFN',
          'Running Balance AFN',
        ],
        ['', '', 'Brought forward', '', '', broughtForward],
        for (final row in rows)
          [
            row['date'],
            _reference(row),
            _description(context, row),
            row['charge'],
            row['payment'],
            balances[row['id'] as int] ?? 0,
          ],
        [
          '',
          '',
          _word(context, 'periodCharges'),
          rows.fold<int>(0, (sum, row) => sum + (row['charge'] as int)),
          '',
          '',
        ],
        [
          '',
          '',
          _word(context, 'periodPayments'),
          '',
          rows.fold<int>(0, (sum, row) => sum + (row['payment'] as int)),
          '',
        ],
        ['', '', 'End of period', '', '', periodEnd],
      ];
      final csv = lines
          .map(
            (line) => line
                .map((value) {
                  final userText =
                      value is String &&
                      !RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
                  return _csvCell(value, userText: userText);
                })
                .join(','),
          )
          .join('\r\n');
      final dir = await _exportDirectory();
      final customerCode = (widget.customer['code'] as String? ?? 'customer')
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File(
        '${dir.path}${Platform.pathSeparator}Ledger_$customerCode.csv',
      );
      await file.writeAsBytes(utf8.encode('\uFEFF$csv'), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText(
            '${_word(context, 'csvExported')}: ${file.path}',
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  String _html(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  Future<void> _printStatement(
    List<Map<String, Object?>> rows,
    Map<int, int> balances,
    int broughtForward,
    int periodEnd,
  ) async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isRtl = Localizations.localeOf(context).languageCode != 'en';
    final customerName = widget.customer['name'] as String? ?? '';
    final customerCode = widget.customer['code'] as String? ?? '';
    final customerPhone = widget.customer['phone'] as String? ?? '';
    final from = fromDate == null
        ? '—'
        : formatDate(fromDate!.toIso8601String(), locale: locale);
    final to = toDate == null
        ? '—'
        : formatDate(toDate!.toIso8601String(), locale: locale);
    final words = <String, String>{
      for (final key in [
        'customerLedger',
        'dateRange',
        'broughtForward',
        'date',
        'reference',
        'description',
        'charges',
        'paymentCredit',
        'runningBalance',
        'endOfPeriod',
        'customerOwes',
        'customerCreditLabel',
        'accountSettled',
        'periodCharges',
        'periodPayments',
      ])
        key: _word(context, key),
    };
    final htmlRows = rows
        .map(
          (row) =>
              '<tr>'
              '<td>${_html(formatDate(row['date'] as String, locale: locale))}</td>'
              '<td>${_html(_reference(row))}</td>'
              '<td>${_html(_description(context, row))}</td>'
              '<td class="num">${_html(formatMoney(row['charge'] as int, locale: locale))}</td>'
              '<td class="num">${_html(formatMoney(row['payment'] as int, locale: locale))}</td>'
              '<td class="num">${_html(formatMoney(balances[row['id'] as int] ?? 0, locale: locale))}</td>'
              '</tr>',
        )
        .join();
    final balanceMeaning = periodEnd > 0
        ? '${words['customerOwes']}: ${formatMoney(periodEnd, locale: locale)}'
        : periodEnd < 0
        ? '${words['customerCreditLabel']}: ${formatMoney(periodEnd.abs(), locale: locale)}'
        : words['accountSettled']!;
    final chargesTotal = rows.fold<int>(
      0,
      (sum, row) => sum + (row['charge'] as int),
    );
    final paymentsTotal = rows.fold<int>(
      0,
      (sum, row) => sum + (row['payment'] as int),
    );
    try {
      final settings = await widget.database.settings();
      final dir = await _exportDirectory();
      final html =
          '''<!doctype html><html lang="${_html(locale)}"><meta charset="utf-8"><title>${_html(words['customerLedger']!)}</title>
<style>body{font:14px Arial,sans-serif;color:#172b4d;margin:32px}h1,h2{color:#173b5e}header{border-bottom:2px solid #087c78;padding-bottom:16px;margin-bottom:20px}table{width:100%;border-collapse:collapse;margin-top:20px}th{background:#eaf1f4;text-align:left}th,td{padding:9px;border-bottom:1px solid #d9e0e4}.num{text-align:right;white-space:nowrap}.sum{display:flex;gap:40px;margin-top:20px;font-weight:bold}@media print{body{margin:12mm}}</style>
<body dir="${isRtl ? 'rtl' : 'ltr'}"><header><h1>${_html(settings['shop_name']?.toString() ?? 'Tailor Shop')}</h1><div>${_html(settings['address']?.toString() ?? '')} · ${_html(settings['phone']?.toString() ?? '')}</div></header>
<h2>${_html(words['customerLedger']!)}</h2><p>${_html(customerName)} · ${_html(customerCode)} · ${_html(customerPhone)}</p>
<p>${_html(words['dateRange']!)}: ${_html(from)} – ${_html(to)}</p>
<p><b>${_html(words['broughtForward']!)}:</b> ${_html(formatMoney(broughtForward, locale: locale))}</p><p>${_html(words['periodCharges']!)}: ${_html(formatMoney(chargesTotal, locale: locale))} · ${_html(words['periodPayments']!)}: ${_html(formatMoney(paymentsTotal, locale: locale))}</p><table><thead><tr><th>${_html(words['date']!)}</th><th>${_html(words['reference']!)}</th><th>${_html(words['description']!)}</th><th class="num">${_html(words['charges']!)}</th><th class="num">${_html(words['paymentCredit']!)}</th><th class="num">${_html(words['runningBalance']!)}</th></tr></thead><tbody>$htmlRows</tbody></table>
<div class="sum"><span>${_html(words['endOfPeriod']!)}: ${_html(formatMoney(periodEnd.abs(), locale: locale))}</span><span>${_html(balanceMeaning)}</span></div><script>window.onload=()=>window.print()</script></body></html>''';
      final code = customerCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File(
        '${dir.path}${Platform.pathSeparator}Statement_$code.html',
      );
      await file.writeAsString(html, encoding: utf8, flush: true);
      if (Platform.isWindows) {
        await Process.start('rundll32.exe', [
          'url.dll,FileProtocolHandler',
          file.path,
        ], mode: ProcessStartMode.detached);
      }
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final l10n = context.l10n;
    return FutureBuilder<_LedgerSnapshot>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_word(context, 'loadError')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allRows = [...snapshot.data!.rows]
          ..sort((a, b) {
            final byDate = (a['date'] as String).compareTo(b['date'] as String);
            return byDate != 0
                ? byDate
                : (a['id'] as int).compareTo(b['id'] as int);
          });
        final hasOpeningRow = allRows.any(
          (row) => (row['description'] as String? ?? '').startsWith(
            'Opening balance',
          ),
        );
        var running = !hasOpeningRow
            ? (widget.customer['opening_balance'] as int? ?? 0)
            : 0;
        final balances = <int, int>{};
        for (final row in allRows) {
          running += _delta(row);
          balances[row['id'] as int] = running;
        }
        final currentBalance = running;
        final start = fromDate == null ? null : _dayKey(fromDate!);
        final end = toDate == null ? null : _dayKey(toDate!);
        final periodRows = allRows.where((row) {
          final day = (row['date'] as String).substring(0, 10);
          return (start == null || day.compareTo(start) >= 0) &&
              (end == null || day.compareTo(end) <= 0);
        }).toList();
        final baseBalance = hasOpeningRow
            ? 0
            : widget.customer['opening_balance'] as int? ?? 0;
        final broughtForward =
            baseBalance +
            (start == null
                ? 0
                : allRows
                      .where(
                        (row) =>
                            (row['date'] as String)
                                .substring(0, 10)
                                .compareTo(start) <
                            0,
                      )
                      .fold<int>(0, (sum, row) => sum + _delta(row)));
        final periodEnd =
            broughtForward +
            periodRows.fold<int>(0, (sum, row) => sum + _delta(row));
        final visibleRows = periodRows.where((row) {
          final query = search.text.trim().toLowerCase();
          final searchable = [
            _reference(row),
            row['receipt']?.toString() ?? '',
            row['order_number']?.toString() ?? '',
            row['bill_number']?.toString() ?? '',
            row['reference']?.toString() ?? '',
            row['description']?.toString() ?? '',
          ].join(' ').toLowerCase();
          return (type == 'All' || _typeOf(row) == type) &&
              (query.isEmpty || searchable.contains(query));
        }).toList();
        final collected = periodRows
            .where(
              (row) =>
                  _typeOf(row) == 'Payments' && (row['payment'] as int) > 0,
            )
            .fold<int>(0, (sum, row) => sum + (row['payment'] as int));
        final debt = (currentBalance + snapshot.data!.credit)
            .clamp(0, 1 << 60)
            .toInt();
        final compact = MediaQuery.sizeOf(context).width < 840;
        _coordinatedScroll = PrimaryScrollController.maybeOf(context);
        return CustomScrollView(
          controller: scroll,
          slivers: [
            if (context.findAncestorStateOfType<NestedScrollViewState>() !=
                null)
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 10),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Text(
                          _word(context, 'customerLedger'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: widget.onReceivePayment,
                              icon: const Icon(Icons.payments_outlined),
                              label: Text(l10n.receivePayment),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _printStatement(
                                periodRows,
                                balances,
                                broughtForward,
                                periodEnd,
                              ),
                              icon: const Icon(Icons.print_outlined),
                              label: Text(_word(context, 'printStatement')),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _exportCsv(
                                periodRows,
                                balances,
                                broughtForward,
                                periodEnd,
                              ),
                              icon: const Icon(Icons.download_outlined),
                              label: Text(_word(context, 'exportCsv')),
                            ),
                            PopupMenuButton<String>(
                              tooltip: _word(context, 'actions'),
                              onSelected: (value) {
                                if (value == 'opening') _openOpeningBalance();
                                if (value == 'adjustment') _openAdjustment();
                                if (value == 'refund') _refundCredit();
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'opening',
                                  child: Text(
                                    _word(context, 'setOpeningBalance'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'adjustment',
                                  child: Text(
                                    _word(context, 'recordAdjustment'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'refund',
                                  child: Text(_word(context, 'refundCredit')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _balanceBanner(
                    context,
                    currentBalance,
                    debt,
                    snapshot.data!.credit,
                    locale,
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth < 660
                          ? (constraints.maxWidth - 10) / 2
                          : (constraints.maxWidth - 20) / 3;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _summaryCard(
                            context,
                            _word(context, 'customerOwes'),
                            debt,
                            Icons.account_balance_wallet_outlined,
                            Theme.of(context).colorScheme.tertiary,
                            locale,
                            cardWidth,
                          ),
                          _summaryCard(
                            context,
                            _word(context, 'availableCredit'),
                            snapshot.data!.credit,
                            Icons.savings_outlined,
                            Theme.of(context).colorScheme.secondary,
                            locale,
                            cardWidth,
                          ),
                          _summaryCard(
                            context,
                            _word(context, 'paymentsPeriod'),
                            collected,
                            Icons.payments_outlined,
                            Theme.of(context).colorScheme.primary,
                            locale,
                            cardWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: compact ? 250 : 310,
                        child: TextField(
                          controller: search,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: _word(context, 'searchLedger'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: search.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () => setState(search.clear),
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: type,
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: _word(context, 'transactionType'),
                          ),
                          items: [
                            for (final value in [
                              'All',
                              'Charges',
                              'Payments',
                              'Credits',
                              'Refunds',
                              'Adjustments',
                            ])
                              DropdownMenuItem(
                                value: value,
                                child: Text(
                                  _word(context, value.toLowerCase()),
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => type = value ?? 'All'),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickDateRange,
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          fromDate == null && toDate == null
                              ? _word(context, 'dateRange')
                              : '${fromDate == null ? '…' : formatDate(fromDate!.toIso8601String(), locale: Localizations.localeOf(context).toLanguageTag())} – ${toDate == null ? '…' : formatDate(toDate!.toIso8601String(), locale: Localizations.localeOf(context).toLanguageTag())}',
                        ),
                      ),
                      TextButton(
                        onPressed:
                            search.text.isEmpty &&
                                type == 'All' &&
                                fromDate == null &&
                                toDate == null
                            ? null
                            : () => setState(() {
                                search.clear();
                                type = 'All';
                                fromDate = null;
                                toDate = null;
                              }),
                        child: Text(_word(context, 'clearFilters')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_word(context, 'broughtForward')}: ${formatMoney(broughtForward, locale: locale)}',
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${_word(context, 'endOfPeriod')}: ${formatMoney(periodEnd, locale: locale)}',
                          textAlign: TextAlign.end,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
                  if (search.text.isNotEmpty || type != 'All')
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _word(context, 'balanceFilterHint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            if (visibleRows.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    allRows.isEmpty
                        ? l10n.noLedgerEntries
                        : _word(context, 'noFilteredTransactions'),
                  ),
                ),
              )
            else if (compact)
              SliverList.builder(
                itemCount: visibleRows.length,
                itemBuilder: (context, index) => _transactionCard(
                  context,
                  visibleRows[index],
                  balances[visibleRows[index]['id'] as int] ?? 0,
                  locale,
                ),
              )
            else
              SliverToBoxAdapter(
                child: _transactionTable(
                  context,
                  visibleRows,
                  balances,
                  locale,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _balanceBanner(
    BuildContext context,
    int balance,
    int debt,
    int credit,
    String locale,
  ) {
    final label = balance > 0
        ? '${_word(context, 'customerOwes')}: ${formatMoney(debt, locale: locale)}'
        : balance < 0
        ? '${_word(context, 'customerCreditLabel')}: ${formatMoney(credit, locale: locale)}'
        : _word(context, 'accountSettled');
    final color = balance > 0
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.secondary;
    final icon = balance > 0
        ? Icons.warning_amber_rounded
        : balance < 0
        ? Icons.savings_outlined
        : Icons.check_circle_outline;
    return Card(
      color: color.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_word(context, 'todayBalance')}: ${formatMoney(balance.abs(), locale: locale)}',
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    BuildContext context,
    String label,
    int amount,
    IconData icon,
    Color color,
    String locale,
    double width,
  ) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatMoney(amount, locale: locale)} AFN',
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _transactionTable(
    BuildContext context,
    List<Map<String, Object?>> rows,
    Map<int, int> balances,
    String locale,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final table = DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(_word(context, 'date'))),
          DataColumn(label: Text(_word(context, 'reference'))),
          DataColumn(label: Text(_word(context, 'description'))),
          DataColumn(label: Text(_word(context, 'charges')), numeric: true),
          DataColumn(
            label: Text(_word(context, 'paymentCredit')),
            numeric: true,
          ),
          DataColumn(
            label: Text(_word(context, 'runningBalance')),
            numeric: true,
          ),
          DataColumn(label: Text(_word(context, 'viewDetails'))),
        ],
        rows: [
          for (var i = 0; i < rows.length; i++)
            DataRow(
              color: WidgetStatePropertyAll(
                i.isEven
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              cells: [
                DataCell(
                  Text(
                    formatDate(rows[i]['date'] as String, locale: locale),
                    maxLines: 1,
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () => _showDetails(rows[i]),
                    child: Text(
                      _reference(rows[i]),
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 210,
                    child: Text(
                      _description(context, rows[i]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    rows[i]['charge'] == 0
                        ? '—'
                        : formatMoney(rows[i]['charge'] as int, locale: locale),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    rows[i]['payment'] == 0
                        ? '—'
                        : formatMoney(
                            rows[i]['payment'] as int,
                            locale: locale,
                          ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    _signedBalance(balances[rows[i]['id'] as int] ?? 0, locale),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  IconButton(
                    tooltip: _word(context, 'viewDetails'),
                    onPressed: () => _showDetails(rows[i]),
                    icon: const Icon(Icons.open_in_new, size: 19),
                  ),
                ),
              ],
            ),
        ],
      );
      return HorizontalTable(child: table);
    },
  );

  Widget _transactionCard(
    BuildContext context,
    Map<String, Object?> row,
    int balance,
    String locale,
  ) => Card(
    margin: const EdgeInsetsDirectional.only(bottom: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetails(row),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _description(context, row),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: _word(context, 'viewDetails'),
                  onPressed: () => _showDetails(row),
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            Text(
              '${formatDate(row['date'] as String, locale: locale)} · ${_reference(row)}',
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if ((row['charge'] as int) != 0)
                  Text(
                    '${_word(context, 'charges')}: ${formatMoney(row['charge'] as int, locale: locale)}',
                    textDirection: TextDirection.ltr,
                  ),
                if ((row['payment'] as int) != 0)
                  Text(
                    '${_word(context, 'paymentCredit')}: ${formatMoney(row['payment'] as int, locale: locale)}',
                    textDirection: TextDirection.ltr,
                  ),
                Text(
                  '${_word(context, 'runningBalance')}: ${_signedBalance(balance, locale)}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  String _signedBalance(int amount, String locale) =>
      '${amount > 0
          ? '+'
          : amount < 0
          ? '−'
          : ''}${formatMoney(amount.abs(), locale: locale)}';

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _LedgerSnapshot {
  const _LedgerSnapshot(this.rows, this.credit);
  final List<Map<String, Object?>> rows;
  final int credit;
}

String _word(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  final ps = language == 'ps';
  final fa = language == 'fa';
  const values = <String, List<String>>{
    'customerLedger': ['Customer Ledger', 'د پېرودونکي حساب', 'حساب مشتری'],
    'customerOwes': ['Customer owes', 'پېرودونکی پوروړی دی', 'بدهی مشتری'],
    'customerCreditLabel': [
      'Customer credit',
      'د پېرودونکي کریډیټ',
      'اعتبار مشتری',
    ],
    'availableCredit': [
      'Available customer credit',
      'شته کریډیټ',
      'اعتبار قابل استفاده',
    ],
    'paymentsPeriod': [
      'Payments received in selected period',
      'په ټاکلې موده کې ترلاسه شوې پیسې',
      'پرداخت‌های دریافت‌شده در دوره',
    ],
    'todayBalance': ['Today', 'نن', 'امروز'],
    'accountSettled': ['Account settled', 'حساب تصفیه شوی', 'حساب تسویه است'],
    'searchLedger': [
      'Search bills, orders, receipts, descriptions',
      'بل، فرمایش، رسید یا تشریح ولټوئ',
      'جستجو بل، سفارش، رسید یا شرح',
    ],
    'transactionType': ['Transaction type', 'د معاملې ډول', 'نوع تراکنش'],
    'all': ['All', 'ټول', 'همه'],
    'charges': ['Charges', 'لګښتونه', 'بدهکاری‌ها'],
    'payments': ['Payments', 'تادیات', 'پرداخت‌ها'],
    'credits': ['Credits', 'کریډیټونه', 'اعتبارها'],
    'refunds': ['Refunds', 'بېرته ورکړې', 'بازپرداخت‌ها'],
    'adjustments': ['Adjustments', 'سمونونه', 'اصلاحات'],
    'dateRange': ['Date range', 'د نېټې موده', 'بازه تاریخ'],
    'clearFilters': ['Clear filters', 'فلټرونه پاک کړئ', 'پاک کردن فیلترها'],
    'broughtForward': ['Brought forward', 'پخوانی بیلانس', 'مانده انتقالی'],
    'endOfPeriod': ['End of period', 'د مودې پای', 'پای دوره'],
    'reversePayment': ['Reverse payment', 'د پیسو بېرته ثبت', 'برگشت پرداخت'],
    'periodCharges': ['Period charges', 'د مودې لګښتونه', 'هزینه‌های دوره'],
    'periodPayments': ['Period payments', 'د مودې تادیات', 'پرداخت‌های دوره'],
    'balanceFilterHint': [
      'Running balances include transactions hidden by search and type filters.',
      'روان بیلانس هغه معاملې هم شمېري چې د لټون یا ډول له فلټرونو پټې دي.',
      'مانده جاری تراکنش‌های پنهان‌شده با فیلترها را هم دربرمی‌گیرد.',
    ],
    'paymentCredit': ['Payment / Credit', 'تادیه / کریډیټ', 'پرداخت / اعتبار'],
    'runningBalance': ['Running balance', 'روان بیلانس', 'مانده جاری'],
    'viewDetails': ['View details', 'تفصیل وګورئ', 'مشاهده جزئیات'],
    'transactionDetails': [
      'Transaction details',
      'د معاملې تفصیل',
      'جزئیات تراکنش',
    ],
    'reference': ['Bill / Reference', 'بل / حواله', 'بل / مرجع'],
    'description': ['Description', 'تشریح', 'شرح'],
    'date': ['Date', 'نېټه', 'تاریخ'],
    'effectiveDate': ['Effective date', 'د تطبیق نېټه', 'تاریخ مؤثر'],
    'recordedAt': ['Recorded at', 'د ثبت وخت', 'زمان ثبت'],
    'amount': ['Amount (AFN)', 'اندازه (افغانۍ)', 'مبلغ (افغانی)'],
    'paymentMethod': ['Payment method', 'د تادیې طریقه', 'روش پرداخت'],
    'allocations': ['Invoice allocations', 'د بل تخصیص', 'تخصیص به فاکتور'],
    'notes': ['Notes', 'یادښتونه', 'یادداشت'],
    'relatedOrder': ['Related order', 'اړوند فرمایش', 'سفارش مرتبط'],
    'openOrder': [
      'Open customer orders',
      'د پېرودونکي فرمایشونه',
      'بازکردن سفارش‌ها',
    ],
    'printStatement': ['Print statement', 'حساب چاپ کړئ', 'چاپ صورت‌حساب'],
    'exportCsv': ['Export CSV', 'CSV صادر کړئ', 'خروجی CSV'],
    'actions': ['Ledger actions', 'د حساب کړنې', 'عملیات حساب'],
    'setOpeningBalance': [
      'Set opening balance',
      'د پیل بیلانس ثبت کړئ',
      'ثبت مانده افتتاحیه',
    ],
    'recordAdjustment': ['Record adjustment', 'سمون ثبت کړئ', 'ثبت اصلاح'],
    'refundCredit': [
      'Refund customer credit',
      'کریډیټ بېرته ورکړئ',
      'بازپرداخت اعتبار مشتری',
    ],
    'reason': ['Reason / explanation', 'لامل / تشریح', 'دلیل / توضیح'],
    'save': ['Save', 'خوندي کول', 'ذخیره'],
    'confirm': ['Confirm', 'تایید', 'تأیید'],
    'effect': ['Account effect', 'پر حساب اغېز', 'اثر بر حساب'],
    'increaseDebt': [
      'Increase customer debt',
      'د پېرودونکي پور زیاتول',
      'افزایش بدهی مشتری',
    ],
    'creditOrReduceDebt': [
      'Reduce debt / add credit',
      'پور کمول / کریډیټ زیاتول',
      'کاهش بدهی / افزایش اعتبار',
    ],
    'saveFailed': ['Could not save', 'خوندي نه شو', 'ذخیره نشد'],
    'loadError': [
      'Could not load this customer ledger.',
      'د پېرودونکي حساب نه شو لوستلای.',
      'بارگذاری حساب مشتری ممکن نشد.',
    ],
    'noFilteredTransactions': [
      'No transactions match these filters.',
      'له دې فلټرونو سره معامله نشته.',
      'تراکنشی با این فیلترها پیدا نشد.',
    ],
    'csvExported': ['CSV saved', 'CSV خوندي شو', 'CSV ذخیره شد'],
    'stitching': ['stitching', 'ګنډل', 'دوخت'],
    'orderCharge': ['Order charge', 'د فرمایش لګښت', 'هزینه سفارش'],
    'advanceReceived': [
      'Advance received',
      'مخکینۍ تادیه ترلاسه شوه',
      'پیش‌پرداخت دریافت شد',
    ],
    'refund': ['Refund', 'بېرته ورکړه', 'بازپرداخت'],
    'adjustment': ['Adjustment', 'سمون', 'اصلاح'],
    'openingBalance': ['Opening balance', 'د پیل بیلانس', 'مانده افتتاحیه'],
    'creditApplied': [
      'Customer credit applied',
      'د پېرودونکي کریډیټ وکارول شو',
      'اعتبار مشتری اعمال شد',
    ],
    'fabricSale': ['Fabric sale', 'د ټوکر پلور', 'فروش پارچه'],
    'paymentReversal': [
      'Payment reversal',
      'د تادیې بېرته ګرځول',
      'برگشت پرداخت',
    ],
    'orderCancelled': ['Order cancellation', 'د فرمایش لغوه کول', 'لغو سفارش'],
  };
  final options = values[key];
  if (options == null) return key;
  return options[ps
      ? 1
      : fa
      ? 2
      : 0];
}
