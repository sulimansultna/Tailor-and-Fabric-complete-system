import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../commands/app_commands.dart';

import '../../widgets/responsive_list_page.dart';
import '../../widgets/horizontal_table.dart';

import '../../core/app_date_picker.dart';

import '../../core/formatters.dart';
import '../../core/calendar_service.dart';
import '../../data/shop_database.dart';
import '../../dialogs/payment_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../customers/customer_profile_screen.dart';
import '../orders/orders_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.database});
  final ShopDatabase database;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _fallbackVerticalScroll = ScrollController();
  ScrollController? _coordinatedVerticalScroll;
  ScrollController get _verticalScroll =>
      _coordinatedVerticalScroll ?? _fallbackVerticalScroll;
  final _horizontalScroll = ScrollController();
  Timer? _debounce;
  List<Map<String, Object?>> _rows = [];
  Map<String, int> _summary = const {};
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _totalCount = 0;
  static const _pageSize = 50;
  String _status = 'All';
  String _method = 'All';
  List<String> _methods = const ['Cash', 'Bank transfer', 'Other'];
  DateTimeRange? _range;
  int _request = 0;

  DateTime get _periodStart =>
      _range?.start ??
      CalendarService.startOfMonth(
        CalendarService.shopToday(),
        calendar: CalendarService.activeCalendar,
      );
  DateTime get _periodEnd => _range?.end ?? CalendarService.shopToday();
  String get _from => _periodStart.toIso8601String().substring(0, 10);
  String get _through => _periodEnd.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _fallbackVerticalScroll.dispose();
    _horizontalScroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final settings = await widget.database.settings();
      final configuredMethods =
          ((settings['payment_methods'] as String?) ??
                  'Cash, Bank transfer, Other')
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
      final rangeStart = _range?.start.toIso8601String().substring(0, 10);
      final rangeEnd = _range?.end.toIso8601String().substring(0, 10);
      final result = await Future.wait([
        widget.database.paymentRows(
          query: _search.text.trim(),
          fromDate: rangeStart,
          throughDate: rangeEnd,
          method: _method == 'All' ? null : _method,
          status: _status == 'All' ? null : _status,
          limit: _pageSize,
        ),
        widget.database.paymentSummary(fromDate: _from, throughDate: _through),
        widget.database.paymentRowCount(
          query: _search.text.trim(),
          fromDate: rangeStart,
          throughDate: rangeEnd,
          method: _method == 'All' ? null : _method,
          status: _status == 'All' ? null : _status,
        ),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _rows = result[0] as List<Map<String, Object?>>;
        _summary = result[1] as Map<String, int>;
        _totalCount = result[2] as int;
        _methods = configuredMethods.isEmpty
            ? const ['Cash', 'Bank transfer', 'Other']
            : configuredMethods;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _rows.length >= _totalCount) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final next = await widget.database.paymentRows(
        query: _search.text.trim(),
        fromDate: _range?.start.toIso8601String().substring(0, 10),
        throughDate: _range?.end.toIso8601String().substring(0, 10),
        method: _method == 'All' ? null : _method,
        status: _status == 'All' ? null : _status,
        limit: _pageSize,
        offset: _rows.length,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _rows.addAll(next);
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _loadingMore = false);
      _message('$error');
    }
  }

  String _word(BuildContext context, String en, String ps, String fa) {
    final language = Localizations.localeOf(context).languageCode;
    return language == 'ps'
        ? ps
        : language == 'fa'
        ? fa
        : en;
  }

  String _pashtoLabel(String label) =>
      const {
        'Amount received': 'ترلاسه شوې پیسې',
        'External reference': 'بهرنۍ حواله',
        'Notes': 'یادښتونه',
        'Recorded at': 'د ثبت وخت',
        'Reversed at': 'د بېرته ثبت وخت',
        'Reversal reason': 'د بېرته ثبت دلیل',
        'Unallocated customer credit': 'نه تخصیص شوی کریډیټ',
        'Invoice total': 'د بل ټولټال',
        'Allocated from this payment': 'له دې تادیې څخه تخصیص شوی',
        'Remaining now': 'اوسنی پاتې',
      }[label] ??
      label;

  String _dariLabel(String label) =>
      const {
        'Amount received': 'مبلغ دریافتی',
        'External reference': 'مرجع بیرونی',
        'Notes': 'یادداشت‌ها',
        'Recorded at': 'زمان ثبت',
        'Reversed at': 'زمان برگشت',
        'Reversal reason': 'دلیل برگشت',
        'Unallocated customer credit': 'اعتبار تخصیص‌نیافته مشتری',
        'Invoice total': 'مجموع بل',
        'Allocated from this payment': 'تخصیص از این پرداخت',
        'Remaining now': 'باقی‌ماندهٔ فعلی',
      }[label] ??
      label;

  Future<void> _receive() async {
    await showPaymentDialog(
      context,
      widget.database,
      onPrintReceipt: _printSavedReceipt,
    );
    if (mounted) await _load();
  }

  Future<void> _printSavedReceipt(String receipt) async {
    final rows = await widget.database.paymentRows(query: receipt);
    final row = rows.where((item) => item['receipt'] == receipt).firstOrNull;
    if (row == null) throw StateError('Saved receipt was not found.');
    final printed = await _printReceipt(row, [], showError: false);
    if (!printed) throw StateError('Receipt printing did not open.');
  }

  Future<void> _pickRange() async {
    final now = CalendarService.shopToday();
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange:
          _range ??
          DateTimeRange(
            start: CalendarService.startOfMonth(
              now,
              calendar: CalendarService.activeCalendar,
            ),
            end: now,
          ),
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    if (_verticalScroll.hasClients) _verticalScroll.jumpTo(0);
    await _load();
  }

  Future<void> _reverse(Map<String, Object?> row) async {
    final reason = TextEditingController();
    final why = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _word(ctx, 'Reverse payment', 'تادیه بېرته ثبتول', 'برگشت پرداخت'),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _word(
                  ctx,
                  'This preserves the receipt and records a linked reversal. Any dependent credit use must be resolved first.',
                  'دا رسید ساتي او اړوند بېرته ثبت جوړوي. د کریډیټ تړلي کارونه باید لومړی حل شي.',
                  'این کار رسید را نگه می‌دارد و برگشت مرتبط ثبت می‌کند. استفاده‌های وابسته از اعتبار باید نخست حل شوند.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _word(
                    ctx,
                    'Reason (required)',
                    'دلیل (اړین)',
                    'دلیل (ضروری)',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reason.text.trim()),
            child: Text(
              _word(
                ctx,
                'Confirm reversal',
                'بېرته ثبت تاییدول',
                'تأیید برگشت',
              ),
            ),
          ),
        ],
      ),
    );
    reason.dispose();
    if (why == null || why.isEmpty) return;
    try {
      await widget.database.reversePayment(row['id'] as int, why);
      if (mounted) {
        await _load();
        if (mounted) {
          _message(
            _word(
              context,
              'Payment reversed.',
              'تادیه بېرته ثبت شوه.',
              'پرداخت برگشت داده شد.',
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        _message(
          _word(
            context,
            'Could not reverse payment: $error',
            'تادیه بېرته نه شوه ثبتېدای: $error',
            'برگشت پرداخت انجام نشد: $error',
          ),
        );
      }
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _details(Map<String, Object?> row) async {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final allocations = await widget.database.db.rawQuery(
      '''SELECT a.amount,o.number,o.bill_number,o.total,
        MAX(o.total-o.paid,0) AS remaining_now,
        (SELECT GROUP_CONCAT(ol.garment || ' ×' || ol.quantity, ', ')
         FROM order_lines ol WHERE ol.order_id=o.id) AS garment_summary
        FROM payment_allocations a JOIN orders o ON o.id=a.order_id
        WHERE a.payment_id=? ORDER BY a.id''',
      [row['id']],
    );
    if (!mounted) return;
    final allocated = allocations.fold<int>(
      0,
      (sum, item) => sum + (item['amount'] as int),
    );
    final screenHeight = MediaQuery.sizeOf(context).height;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['receipt']?.toString() ?? '',
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    _word(
                      ctx,
                      'Payment details',
                      'د تادیې جزئیات',
                      'جزئیات پرداخت',
                    ),
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _statusChip(ctx, row['status']?.toString() ?? 'Posted'),
          ],
        ),
        content: SizedBox(
          width: 760,
          height: math.min(650, screenHeight - 220),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row['customer_name']?.toString() ?? '',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                SelectableText(
                  row['phone']?.toString() ?? '',
                  textDirection: TextDirection.ltr,
                ),
                Text(
                  '${formatDate(row['date'] as String, locale: locale)} · ${localizedPaymentMethod(ctx, row['method'] as String)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(ctx).colorScheme.primaryContainer
                      .withValues(alpha: .35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _detailLine(
                      ctx,
                      'Amount received',
                      _money(ctx, row['amount'] as int),
                    ),
                  ),
                ),
                _detailLine(
                  ctx,
                  'External reference',
                  row['reference']?.toString().isNotEmpty == true
                      ? row['reference'].toString()
                      : '—',
                ),
                _detailLine(
                  ctx,
                  'Notes',
                  row['notes']?.toString().isNotEmpty == true
                      ? row['notes'].toString()
                      : '—',
                ),
                _detailLine(
                  ctx,
                  'Recorded at',
                  row['created_at']?.toString() ?? '—',
                ),
                if ((row['notes']?.toString() ?? '').trim().isNotEmpty)
                  _detailLine(ctx, 'Notes', row['notes'].toString()),
                const Divider(),
                Text(
                  _word(
                    ctx,
                    'Invoice allocations',
                    'د بل تخصیصونه',
                    'تخصیص‌های صورتحساب',
                  ),
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                if (allocations.isEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _word(
                        ctx,
                        'Customer Credit — not allocated to a bill.',
                        'د پېرودونکي کریډیټ — کوم بل ته نه دی ځانګړی شوی.',
                        'اعتبار مشتری — به هیچ بل تخصیص نیافته است.',
                      ),
                    ),
                  ),
                if (allocations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_word(ctx, 'Remaining balances shown as of', 'پاتې بیلانسونه د دې نېټې له مخې دي', 'مانده‌ها بر اساس این تاریخ هستند')} ${formatDate(CalendarService.shopToday().toIso8601String(), locale: locale)}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                for (final item in allocations) _allocationDetail(ctx, item),
                if ((row['amount'] as int) > allocated)
                  _detailLine(
                    ctx,
                    row['status'] == 'Posted'
                        ? 'Unallocated customer credit'
                        : 'Unallocated from this receipt',
                    _money(ctx, (row['amount'] as int) - allocated),
                  ),
                if (row['status'] == 'Reversed') ...[
                  const Divider(),
                  _detailLine(
                    ctx,
                    'Reversed at',
                    row['reversed_at']?.toString() ?? '—',
                  ),
                  _detailLine(
                    ctx,
                    'Reversal reason',
                    row['reversal_reason']?.toString() ?? '—',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _openLedger(row);
            },
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: Text(
              _word(
                ctx,
                'Open Customer Ledger',
                'د پېرودونکي حساب پرانیزئ',
                'دفتر حساب مشتری را باز کنید',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.close),
          ),
          TextButton.icon(
            onPressed: () => _printReceipt(row, allocations),
            icon: const Icon(Icons.print_outlined),
            label: Text(
              _word(ctx, 'Print / Reprint', 'چاپ / بیاچاپ', 'چاپ / چاپ دوباره'),
            ),
          ),
          if (row['status'] == 'Posted')
            PopupMenuButton<String>(
              onSelected: (_) {
                Navigator.pop(ctx);
                _reverse(row);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reverse',
                  child: Text(
                    _word(
                      context,
                      'Reverse payment',
                      'تادیه بېرته ثبتول',
                      'برگشت پرداخت',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _allocationDetail(BuildContext ctx, Map<String, Object?> item) {
    final bill = item['bill_number']?.toString().trim() ?? '';
    final order = item['number']?.toString().trim() ?? '';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_word(ctx, 'Bill', 'بل', 'بل')} ${bill.isEmpty ? '—' : bill}',
              style: Theme.of(ctx).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            SelectableText(
              '${_word(ctx, 'Order', 'فرمایش', 'سفارش')} ${order.isEmpty ? '—' : order}',
              textDirection: TextDirection.ltr,
            ),
            if ((item['garment_summary']?.toString() ?? '').isNotEmpty)
              Text(item['garment_summary'].toString()),
            const SizedBox(height: 6),
            _detailLine(
              ctx,
              'Invoice total',
              _money(ctx, item['total'] as int),
            ),
            _detailLine(
              ctx,
              'Allocated from this payment',
              _money(ctx, item['amount'] as int),
            ),
            _detailLine(
              ctx,
              'Remaining now',
              _money(ctx, item['remaining_now'] as int),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openOrder(item['bill_number'], item['number']);
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _word(ctx, 'Open Bill', 'بل پرانیزئ', 'بازکردن بل'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLedger(Map<String, Object?> row) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerProfileScreen(
          database: widget.database,
          customer: {
            'id': row['customer_id'],
            'name': row['customer_name'],
            'phone': row['phone'],
          },
          initialTabIndex: 1,
        ),
      ),
    );
  }

  Future<void> _openOrder(Object? billNumber, Object? orderNumber) async {
    final bill = billNumber?.toString().trim() ?? '';
    final order = orderNumber?.toString().trim() ?? '';
    final search = bill.isNotEmpty ? bill : order;
    if (search.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: context.l10n.goBack,
              icon: const BackButtonIcon(),
              onPressed: () => Navigator.of(routeContext).maybePop(),
            ),
            title: Text(context.l10n.orders),
          ),
          body: OrdersScreen(database: widget.database, initialSearch: search),
        ),
      ),
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                _word(context, label, _pashtoLabel(label), _dariLabel(label)),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: SelectableText(
                value,
                textAlign: TextAlign.end,
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      );

  Future<bool> _printReceipt(
    Map<String, Object?> row,
    List<Map<String, Object?>> allocations, {
    bool showError = true,
  }) async {
    final receiptTitle = _word(
      context,
      'Payment receipt',
      'د تادیې رسید',
      'رسید پرداخت',
    );
    final recordedLabel = _word(context, 'Recorded', 'ثبت شوی', 'ثبت‌شده');
    final referenceLabel = _word(
      context,
      'External reference',
      'بهرنۍ حواله',
      'مرجع بیرونی',
    );
    final notesLabel = _word(context, 'Notes', 'یادښتونه', 'یادداشت‌ها');
    final orderLabel = _word(context, 'Order', 'فرمایش', 'سفارش');
    final billLabel = _word(context, 'Bill', 'بل', 'بل');
    final garmentsLabel = _word(context, 'Garments', 'جامې', 'لباس‌ها');
    final invoiceTotalLabel = _word(
      context,
      'Invoice total',
      'د بل ټولټال',
      'مجموع بل',
    );
    final allocatedLabel = _word(
      context,
      'Allocated from this payment',
      'تخصیص شوی',
      'تخصیص‌یافته',
    );
    final remainingNowLabel = _word(
      context,
      'Remaining now',
      'اوسنی پاتې',
      'باقی‌ماندهٔ فعلی',
    );
    final debtLabel = _word(
      context,
      'Current customer debt at print time',
      'د پېرودونکي پاتې پور',
      'بدهی باقی‌مانده مشتری',
    );
    final creditLabel = _word(
      context,
      'Available credit',
      'شته کریډیټ',
      'اعتبار موجود',
    );
    final unusedLabel = _word(
      context,
      'Unallocated from this receipt',
      'له دې رسید څخه نه دی تخصیص شوی',
      'تخصیص‌نیافته از این رسید',
    );
    final paymentMethod = localizedPaymentMethod(
      context,
      row['method'] as String,
    );
    final status = row['status']?.toString() ?? 'Posted';
    final statusLabel = status == 'Reversed'
        ? _word(context, 'Reversed', 'بېرته ثبت شوی', 'برگشت‌شده')
        : _word(context, 'Posted', 'ثبت شوی', 'ثبت‌شده');
    final billAllocationsLabel = _word(
      context,
      'Bill allocations',
      'د بل تخصیصونه',
      'تخصیص‌های بل',
    );
    final printTimeLabel = _word(
      context,
      'Remaining balances below are current at print time',
      'لاندې پاتې بیلانسونه د چاپ د وخت اوسني ارزښتونه دي',
      'مانده‌های زیر در زمان چاپ فعلی هستند',
    );
    final customerCreditLine = _word(
      context,
      'Customer Credit — not allocated to a bill.',
      'د پېرودونکي کریډیټ — کوم بل ته نه دی ځانګړی شوی.',
      'اعتبار مشتری — به هیچ بل تخصیص نیافته است.',
    );
    final thankYouLabel = _word(context, 'Thank you.', 'مننه.', 'سپاسگزاریم.');
    final reversalReasonLabel = _word(
      context,
      'Reversal reason',
      'د بېرته ثبت دلیل',
      'دلیل برگشت',
    );
    final reversedAtLabel = _word(
      context,
      'Reversed at',
      'د بېرته ثبت وخت',
      'زمان برگشت',
    );
    try {
      final locale = Localizations.localeOf(context).toLanguageTag();
      String money(int minor) => formatPaymentMoney(minor, locale: locale);
      final direction = Localizations.localeOf(context).languageCode == 'en'
          ? 'ltr'
          : 'rtl';
      final settings = await widget.database.settings();
      final ledger = await widget.database.customerLedger(
        row['customer_id'] as int,
      );
      final ledgerBalance = ledger.fold<int>(
        0,
        (balance, item) =>
            balance + (item['charge'] as int) - (item['payment'] as int),
      );
      final availableCredit = await widget.database.availableCustomerCredit(
        row['customer_id'] as int,
      );
      if (allocations.isEmpty) {
        allocations = await widget.database.db.rawQuery(
          '''SELECT o.number,o.bill_number,o.total,a.amount,
            MAX(o.total-o.paid,0) AS remaining_now,
            (SELECT GROUP_CONCAT(ol.garment || ' ×' || ol.quantity, ', ')
             FROM order_lines ol WHERE ol.order_id=o.id) AS garment_summary
            FROM payment_allocations a JOIN orders o ON o.id=a.order_id
            WHERE a.payment_id=? ORDER BY a.id''',
          [row['id']],
        );
      }
      String esc(Object? value) =>
          const HtmlEscape().convert(value?.toString() ?? '');
      final currentDate = formatDate(
        CalendarService.shopToday().toIso8601String(),
        locale: locale,
      );
      final details = allocations
          .map(
            (item) =>
                '''<tr>
              <td><b>${esc(item['bill_number'] ?? '—')}</b></td>
              <td dir="ltr">${esc(item['number'] ?? '—')}</td>
              <td>${esc(item['garment_summary'] ?? '—')}</td>
              <td>${esc(money(item['total'] as int))}</td>
              <td>${esc(money(item['amount'] as int))}</td>
              <td>${esc(money(item['remaining_now'] as int))}</td>
            </tr>''',
          )
          .join();
      final unallocated =
          (row['amount'] as int) -
          allocations.fold<int>(
            0,
            (sum, item) => sum + (item['amount'] as int),
          );
      final reversal = status == 'Reversed'
          ? '<p><b>${esc(reversalReasonLabel)}:</b> ${esc(row['reversal_reason'] ?? '—')}<br><b>${esc(reversedAtLabel)}:</b> ${esc(row['reversed_at'] ?? '—')}</p>'
          : '';
      final html =
          '''<!doctype html><html lang="${esc(locale)}" dir="$direction"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(receiptTitle)} ${esc(row['receipt'])}</title><style>
          @page{size:A4;margin:14mm}*{box-sizing:border-box}body{font:13px Arial,"Noto Sans Arabic",sans-serif;color:#172b4d;margin:0;direction:$direction}header{border-bottom:3px solid #087c78;padding-bottom:12px;display:flex;justify-content:space-between;gap:18px}h1{color:#173b5e;margin:0 0 5px;font-size:21px}h2{color:#173b5e;margin:22px 0 8px;font-size:18px}.muted{color:#64748b}.receipt{text-align:end;color:#087c78;font-size:18px;font-weight:800}.receipt-number{font-size:23px}.amount{font-size:23px;font-weight:bold;margin:16px 0;padding:12px;background:#f1f8f7;border-inline-start:4px solid #087c78}.status{display:inline-block;border:1px solid #9ab5b6;border-radius:30px;padding:4px 10px;font-weight:700}table{width:100%;border-collapse:collapse;margin-top:14px;table-layout:fixed}td,th{padding:7px 5px;border-bottom:1px solid #d9e0e4;text-align:start;overflow-wrap:anywhere}th{background:#f1f6f7;color:#173b5e}.balances{display:flex;gap:12px;flex-wrap:wrap;margin-top:18px}.balances span{border:1px solid #d9e0e4;border-radius:6px;padding:8px}.footer{border-top:1px solid #d9e0e4;margin-top:30px;padding-top:10px;color:#64748b}@media print{body{-webkit-print-color-adjust:exact;print-color-adjust:exact}}@media print and (max-width:480px){@page{size:80mm auto;margin:4mm}body{font-size:10px}h1{font-size:16px}h2{font-size:13px}.receipt-number{font-size:18px}.amount{font-size:18px;padding:8px}td,th{padding:4px 2px;font-size:9px}}</style></head><body>
          <header><div><h1>${esc(settings['shop_name'] ?? 'Tailor Shop')}</h1><div>${esc(settings['address'] ?? '')}</div><div dir="ltr">${esc(settings['phone'] ?? '')}</div></div><div class="receipt"><div>${esc(receiptTitle)}</div><div class="receipt-number" dir="ltr">${esc(row['receipt'])}</div><span class="status">${esc(statusLabel)}</span></div></header>
          <p><b>${esc(row['customer_name'])}</b> · <span dir="ltr">${esc(row['phone'])}</span></p><p>${esc(formatDate(row['date'] as String, locale: locale))} · ${esc(paymentMethod)} · ${esc(recordedLabel)} ${esc(row['created_at'] ?? '—')}</p><div class="amount">${esc(money(row['amount'] as int))}</div><p>${esc(referenceLabel)}: ${esc(row['reference'] ?? '—')}</p><p>${esc(notesLabel)}: ${esc(row['notes'] ?? '—')}</p>$reversal
          <h2>${esc(billAllocationsLabel)}</h2><table><thead><tr><th>${esc(billLabel)}</th><th>${esc(orderLabel)}</th><th>${esc(garmentsLabel)}</th><th>${esc(invoiceTotalLabel)}</th><th>${esc(allocatedLabel)}</th><th>${esc(remainingNowLabel)}</th></tr></thead><tbody>${details.isEmpty ? '<tr><td colspan="6">$customerCreditLine</td></tr>' : details}</tbody></table>
          <p class="muted">${esc(printTimeLabel)}: ${esc(currentDate)}</p><div class="balances"><span>${esc(debtLabel)}: ${esc(money(ledgerBalance.clamp(0, 1 << 60)))}</span><span>${esc(creditLabel)}: ${esc(money(availableCredit))}</span><span>${esc(unusedLabel)}: ${esc(money(unallocated.clamp(0, 1 << 60)))}</span></div><footer class="footer">${esc(thankYouLabel)}</footer><script>window.onload=()=>window.print()</script></body></html>''';
      final dir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}TailorShopReceipts',
      );
      await dir.create(recursive: true);
      final file = File(
        '${dir.path}${Platform.pathSeparator}Payment_${row['receipt']}.html',
      );
      await file.writeAsString(html, encoding: utf8, flush: true);
      if (Platform.isWindows) {
        await Process.start('rundll32.exe', [
          'url.dll,FileProtocolHandler',
          file.path,
        ], mode: ProcessStartMode.detached);
      } else {
        return false;
      }
      return true;
    } catch (error) {
      if (mounted && showError) {
        _message(
          _word(
            context,
            'Could not open receipt for printing: $error',
            'رسید د چاپ لپاره خلاص نه شو: $error',
            'بازکردن رسید برای چاپ انجام نشد: $error',
          ),
        );
      }
      return false;
    }
  }

  Widget _summaryCard(
    BuildContext context,
    String title,
    int amount,
    IconData icon, {
    bool emphasis = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: emphasis
          ? colors.primaryContainer.withValues(alpha: .45)
          : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primary.withValues(alpha: .10),
              foregroundColor: colors.primary,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _money(context, amount),
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _money(BuildContext context, int minorAmount) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return formatPaymentMoney(minorAmount, locale: locale);
  }

  static const _paymentColumnWidths = <double>[
    220,
    195,
    140,
    145,
    145,
    155,
    125,
    148,
  ];

  Widget _tableCell(
    double width,
    Widget child, {
    AlignmentGeometry? alignment,
  }) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: alignment ?? AlignmentDirectional.centerStart,
        child: child,
      ),
    ),
  );

  Widget _tableHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final labels = [
      _word(
        context,
        'Bill / Related Orders',
        'بل / اړوند فرمایشونه',
        'بل / سفارش‌های مرتبط',
      ),
      _word(context, 'Customer', 'پېرودونکی', 'مشتری'),
      _word(context, 'Receipt Number', 'د رسید شمېره', 'شمارهٔ رسید'),
      _word(context, 'Payment Date', 'د تادیې نېټه', 'تاریخ پرداخت'),
      _word(context, 'Amount Received', 'ترلاسه شوې پیسې', 'مبلغ دریافتی'),
      _word(context, 'Payment Method', 'د تادیې طریقه', 'روش پرداخت'),
      _word(context, 'Status', 'حالت', 'وضعیت'),
      _word(context, 'Actions', 'کړنې', 'عملیات'),
    ];
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            _tableCell(
              _paymentColumnWidths[i],
              Text(
                labels[i],
                maxLines: 2,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              alignment: i == 4
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
            ),
        ],
      ),
    );
  }

  Widget _paymentRow(BuildContext context, Map<String, Object?> row) {
    final posted = row['status'] == 'Posted';
    final colors = Theme.of(context).colorScheme;
    final allocationCount = (row['allocation_count'] as num? ?? 0).toInt();
    final allocated = (row['allocated_amount'] as num? ?? 0).toInt();
    final amount = (row['amount'] as num? ?? 0).toInt();
    final firstBill = row['first_bill_number']?.toString().trim() ?? '';
    final firstOrder = row['first_order_number']?.toString().trim() ?? '';
    final garmentSummary =
        row['first_garment_summary']?.toString().trim() ?? '';
    final phone = row['phone']?.toString() ?? '';
    final method = row['method']?.toString() ?? '';
    final methodIcon = method.toLowerCase().contains('bank')
        ? Icons.account_balance_outlined
        : method.toLowerCase().contains('card')
        ? Icons.credit_card_outlined
        : method.toLowerCase().contains('wallet')
        ? Icons.account_balance_wallet_outlined
        : Icons.payments_outlined;

    return CommandRecordTarget(kind: 'payment', record: row, child: Material(
      color: colors.surface,
      child: InkWell(
        onTap: () => _details(row),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              _tableCell(
                _paymentColumnWidths[0],
                allocationCount == 0
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _word(
                              context,
                              'Customer Credit',
                              'د پېرودونکي کریډیټ',
                              'اعتبار مشتری',
                            ),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Text(
                            _word(
                              context,
                              'Not allocated to a bill',
                              'بل ته نه دی ځانګړی شوی',
                              'به بل تخصیص نیافته',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: () => _openOrder(
                          row['first_bill_number'],
                          row['first_order_number'],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_word(context, 'Bill', 'بل', 'بل')} ${firstBill.isEmpty ? '—' : firstBill}',
                                textDirection: TextDirection.ltr,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              if (garmentSummary.isNotEmpty)
                                Text(
                                  garmentSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              Wrap(
                                spacing: 5,
                                runSpacing: 0,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (firstOrder.isNotEmpty)
                                    Text(
                                      firstOrder,
                                      textDirection: TextDirection.ltr,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  if (allocationCount > 1)
                                    TextButton(
                                      onPressed: () => _details(row),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(36, 24),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        '+${allocationCount - 1} ${_word(context, 'more', 'نور', 'بیشتر')}',
                                      ),
                                    ),
                                ],
                              ),
                              if (amount > allocated)
                                Text(
                                  '+ ${_word(context, 'Customer Credit', 'د پېرودونکي کریډیټ', 'اعتبار مشتری')}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: colors.tertiary),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
              _tableCell(
                _paymentColumnWidths[1],
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['customer_name']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          SelectableText(
                            phone,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.bodySmall,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _word(
                        context,
                        'Copy phone',
                        'د موبایل شمېره کاپي کړئ',
                        'کپی شمارهٔ موبایل',
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: phone.isEmpty ? null : () => _copyPhone(phone),
                      icon: const Icon(Icons.content_copy_outlined, size: 17),
                    ),
                  ],
                ),
              ),
              _tableCell(
                _paymentColumnWidths[2],
                Text(
                  row['receipt']?.toString() ?? '',
                  maxLines: 1,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _tableCell(
                _paymentColumnWidths[3],
                Text(
                  formatDate(
                    row['date'] as String,
                    locale: Localizations.localeOf(context).toLanguageTag(),
                  ),
                  maxLines: CalendarService.showBothDates ? 2 : 1,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              _tableCell(
                _paymentColumnWidths[4],
                Text(
                  _money(context, amount),
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: posted ? colors.primary : colors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                alignment: AlignmentDirectional.centerEnd,
              ),
              _tableCell(
                _paymentColumnWidths[5],
                Row(
                  children: [
                    Icon(methodIcon, size: 18, color: colors.onSurfaceVariant),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        localizedPaymentMethod(context, method),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              _tableCell(
                _paymentColumnWidths[6],
                _statusChip(context, row['status']?.toString() ?? 'Posted'),
              ),
              _tableCell(
                _paymentColumnWidths[7],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _word(
                        context,
                        'View Payment',
                        'تادیه وګورئ',
                        'مشاهده پرداخت',
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _details(row),
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                    ),
                    IconButton(
                      tooltip: _word(
                        context,
                        'Print Receipt',
                        'رسید چاپ کړئ',
                        'چاپ رسید',
                      ),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _printReceipt(row, []),
                      icon: const Icon(Icons.print_outlined, size: 19),
                    ),
                    _rowMenu(context, row),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _statusChip(BuildContext context, String status) {
    final posted = status == 'Posted';
    final color = posted
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 105),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              posted ? Icons.check_circle_outline : Icons.undo,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                status == 'Posted'
                    ? _word(context, 'Posted', 'ثبت شوی', 'ثبت‌شده')
                    : _word(context, 'Reversed', 'بېرته ثبت شوی', 'برگشت‌شده'),
                softWrap: true,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowMenu(
    BuildContext context,
    Map<String, Object?> row,
  ) => PopupMenuButton<String>(
    tooltip: _word(
      context,
      'More payment actions',
      'د تادیې نورې کړنې',
      'عملیات بیشتر پرداخت',
    ),
    onSelected: (value) {
      if (value == 'details') _details(row);
      if (value == 'print') _printReceipt(row, []);
      if (value == 'reverse') _reverse(row);
      if (value == 'ledger') _openLedger(row);
      if (value == 'bills') _details(row);
    },
    itemBuilder: (ctx) => [
      PopupMenuItem(
        value: 'details',
        child: Text(_word(ctx, 'View details', 'تفصیل وګورئ', 'مشاهده جزئیات')),
      ),
      PopupMenuItem(
        value: 'print',
        child: Text(
          _word(ctx, 'Print / Reprint', 'چاپ / بیاچاپ', 'چاپ / چاپ دوباره'),
        ),
      ),
      PopupMenuItem(
        value: 'ledger',
        child: Text(
          _word(
            ctx,
            'Open Customer Ledger',
            'د پېرودونکي حساب پرانیزئ',
            'بازکردن دفتر حساب مشتری',
          ),
        ),
      ),
      PopupMenuItem(
        value: 'bills',
        child: Text(
          _word(
            ctx,
            'Open Related Bills',
            'اړوند بلونه پرانیزئ',
            'بازکردن بل‌های مرتبط',
          ),
        ),
      ),
      if (row['status'] == 'Posted')
        PopupMenuItem(
          value: 'reverse',
          child: Text(
            _word(ctx, 'Reverse payment', 'تادیه بېرته ثبتول', 'برگشت پرداخت'),
          ),
        ),
    ],
  );

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    _message(
      _word(
        context,
        'Phone number copied.',
        'د موبایل شمېره کاپي شوه.',
        'شمارهٔ موبایل کپی شد.',
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 175,
          child: DropdownButtonFormField<String>(
            initialValue: _status,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: _word(context, 'Status', 'حالت', 'وضعیت'),
            ),
            items: const ['All', 'Posted', 'Reversed']
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'All'
                          ? _word(
                              context,
                              'All statuses',
                              'ټول حالتونه',
                              'همه وضعیت‌ها',
                            )
                          : _word(
                              context,
                              value,
                              value == 'Posted' ? 'ثبت شوی' : 'بېرته ثبت شوی',
                              value == 'Posted' ? 'ثبت‌شده' : 'برگشت‌شده',
                            ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _status = value ?? 'All');
              if (_verticalScroll.hasClients) _verticalScroll.jumpTo(0);
              _load();
            },
          ),
        ),
        SizedBox(
          width: 195,
          child: DropdownButtonFormField<String>(
            initialValue: _method,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.method),
            items: ['All', ..._methods]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'All'
                          ? _word(
                              context,
                              'All methods',
                              'ټولې طریقې',
                              'همه روش‌ها',
                            )
                          : localizedPaymentMethod(context, value),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _method = value ?? 'All');
              if (_verticalScroll.hasClients) _verticalScroll.jumpTo(0);
              _load();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: _pickRange,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            _range == null
                ? _word(context, 'Date range', 'د نېټې موده', 'محدوده تاریخ')
                : '${formatDate(_from, locale: Localizations.localeOf(context).toLanguageTag())} – ${formatDate(_through, locale: Localizations.localeOf(context).toLanguageTag())}',
          ),
        ),
        TextButton.icon(
          onPressed: _status == 'All' && _method == 'All' && _range == null
              ? null
              : () {
                  setState(() {
                    _status = 'All';
                    _method = 'All';
                    _range = null;
                  });
                  if (_verticalScroll.hasClients) _verticalScroll.jumpTo(0);
                  _load();
                },
          icon: const Icon(Icons.clear),
          label: Text(
            _word(
              context,
              'Clear filters',
              'فلټرونه پاک کړئ',
              'پاک‌کردن فیلترها',
            ),
          ),
        ),
      ],
    );
  }

  String _countText(BuildContext context, int start, int end, int total) {
    final language = Localizations.localeOf(context).languageCode;
    if (language == 'ps') {
      return 'له $start څخه تر $end، ټول $total تادیې';
    }
    if (language == 'fa') {
      return 'نمایش $start تا $end از $total پرداخت';
    }
    return '$start–$end of $total payments';
  }

  void _clearSearchAndFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _status = 'All';
      _method = 'All';
      _range = null;
    });
    if (_verticalScroll.hasClients) _verticalScroll.jumpTo(0);
    _load();
  }

  Widget _paymentTable(BuildContext context, double availableWidth) {
    final colors = Theme.of(context).colorScheme;
    final nothingRecorded =
        _totalCount == 0 &&
        _search.text.trim().isEmpty &&
        _status == 'All' &&
        _method == 'All' &&
        _range == null;
    final requiredWidth = _paymentColumnWidths.fold<double>(
      0,
      (sum, width) => sum + width,
    );
    final tableWidth = math.max(requiredWidth, availableWidth).toDouble();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Scrollbar(
          controller: _horizontalScroll,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalScroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: tableWidth,
              height: math.max(0, constraints.maxHeight - 12),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical &&
                      notification.metrics.pixels >=
                          notification.metrics.maxScrollExtent - 180) {
                    _loadMore();
                  }
                  return false;
                },
                child: CustomScrollView(
                  controller: _verticalScroll,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: FixedTableHeader(
                        height: 52,
                        child: _tableHeader(context),
                      ),
                    ),
                    if (_rows.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                nothingRecorded
                                    ? Icons.payments_outlined
                                    : Icons.search_off_outlined,
                                size: 38,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                nothingRecorded
                                    ? _word(
                                        context,
                                        'No payments have been recorded yet.',
                                        'تر اوسه تادیه نه ده ثبت شوې.',
                                        'هنوز پرداختی ثبت نشده است.',
                                      )
                                    : _word(
                                        context,
                                        'No payments match these filters.',
                                        'د ټاکل شوو فلټرونو سره تادیه ونه موندل شوه.',
                                        'پرداختی با این فلترها پیدا نشد.',
                                      ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              if (nothingRecorded)
                                CommandButton(register: false, aliases: const ['action.new'], id: 'payments.add', child: FilledButton.icon(
                                  onPressed: _receive,
                                  icon: const Icon(Icons.payments_outlined),
                                  label: Text(context.l10n.receivePayment),
                                ))
                              else
                                OutlinedButton.icon(
                                  onPressed: _clearSearchAndFilters,
                                  icon: const Icon(
                                    Icons.filter_alt_off_outlined,
                                  ),
                                  label: Text(
                                    _word(
                                      context,
                                      'Clear Filters',
                                      'فلټرونه پاک کړئ',
                                      'پاک‌کردن فلترها',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, index) =>
                            _paymentRow(context, _rows[index]),
                      ),
                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: colors.outlineVariant),
                          ),
                        ),
                        child: Text(
                          _countText(
                            context,
                            _rows.isEmpty ? 0 : 1,
                            _rows.length,
                            _totalCount,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = context.l10n.payments;
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    return CommandScope(commands: _keyboardCommands(), builder: (context) => Focus(
      child: Focus(
        child: ColoredBox(
          color: colors.surfaceContainerLow,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 850;
              final pagePadding = narrow ? 12.0 : 22.0;
              final periodLabel = _word(
                context,
                'Selected period',
                'ټاکل شوې موده',
                'دورهٔ انتخاب‌شده',
              );
              final periodText =
                  '$periodLabel: ${formatDate(_from, locale: Localizations.localeOf(context).toLanguageTag())} – ${formatDate(_through, locale: Localizations.localeOf(context).toLanguageTag())}';
              final hint = _word(
                context,
                'Search bill number, customer, mobile, receipt, or order.',
                'د بل شمېره، پېرودونکی، موبایل، رسید یا فرمایش ولټوئ.',
                'شمارهٔ بل، مشتری، موبایل، رسید یا سفارش را جستجو کنید.',
              );
              final info = _word(
                context,
                'Period received is posted payments by payment date. Net collections subtract refunds. Reversed receipts are excluded. Current customer debt is a live balance.',
                'د مودې ترلاسه شوې پیسې د ثبت شویو تادیو له مخې دي. خالص راټولونه بېرته ورکړې منفي کوي. بېرته ثبت شوي رسیدونه نه شمېرل کېږي. اوسنی پور ژوندی بیلانس دی.',
                'دریافتی دوره بر اساس تاریخ پرداخت‌های ثبت‌شده است. خالص دریافتی بازپرداخت‌ها را کم می‌کند. رسیدهای برگشت‌شده حساب نمی‌شوند. بدهی جاری، ماندهٔ فعلی است.',
              );

              return Padding(
                padding: EdgeInsets.all(pagePadding),
                child: ResponsiveListPage(
                  header: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 12,
                      spacing: 12,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: math.max(260, constraints.maxWidth - 330),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _word(
                                  context,
                                  'Find bills, record payments, and print receipts.',
                                  'بلونه ومومئ، تادیې ثبت کړئ او رسیدونه چاپ کړئ.',
                                  'بل‌ها را پیدا کنید، پرداخت ثبت کنید و رسید چاپ کنید.',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            IconButton(
                              tooltip: context.l10n.refresh,
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                            ),
                            CommandButton(register: false, aliases: const ['action.new'], id: 'payments.add', child: FilledButton.icon(
                              onPressed: _receive,
                              icon: const Icon(Icons.payments_outlined),
                              label: Text(context.l10n.receivePayment),
                            )),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, size) {
                        final columns = size.maxWidth >= 1120
                            ? 4
                            : size.maxWidth >= 560
                            ? 2
                            : 1;
                        const gap = 10.0;
                        final width =
                            (size.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                context,
                                _word(
                                  context,
                                  'Payments Received',
                                  'ترلاسه شوې تادیې',
                                  'پرداخت‌های دریافتی',
                                ),
                                _summary['received'] ?? 0,
                                Icons.south_west,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                context,
                                _word(
                                  context,
                                  'Refunds Paid',
                                  'بېرته ورکړل شوې پیسې',
                                  'بازپرداخت‌های انجام‌شده',
                                ),
                                _summary['refunds'] ?? 0,
                                Icons.reply_outlined,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                context,
                                _word(
                                  context,
                                  'Net Collections',
                                  'خالص راټولونه',
                                  'خالص دریافتی',
                                ),
                                _summary['net'] ?? 0,
                                Icons.account_balance_wallet_outlined,
                                emphasis: true,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: _summaryCard(
                                context,
                                _word(
                                  context,
                                  'Current Customer Debt',
                                  'د پېرودونکو اوسنی پور',
                                  'بدهی کنونی مشتریان',
                                ),
                                _summary['outstanding'] ?? 0,
                                Icons.pending_actions_outlined,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        top: 5,
                        bottom: 9,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 17),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              periodText,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Tooltip(
                            message: info,
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            focusNode: _searchFocus,
                            onChanged: (_) {
                              _request++;
                              setState(() {});
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 300),
                                () {
                                  if (_verticalScroll.hasClients) {
                                    _verticalScroll.jumpTo(0);
                                  }
                                  _load();
                                },
                              );
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: hint,
                              isDense: true,
                              filled: true,
                              fillColor: colors.surface,
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: _word(
                                        context,
                                        'Clear Search',
                                        'لټون پاک کړئ',
                                        'پاک‌کردن جستجو',
                                      ),
                                      onPressed: () {
                                        _search.clear();
                                        setState(() {});
                                        if (_verticalScroll.hasClients) {
                                          _verticalScroll.jumpTo(0);
                                        }
                                        _load();
                                      },
                                      icon: const Icon(Icons.close),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _filters(context),
                    const SizedBox(height: 10),
                  ],
                  body: Builder(
                    builder: (bodyContext) {
                      _coordinatedVerticalScroll =
                          PrimaryScrollController.maybeOf(bodyContext);
                      return _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.cloud_off_outlined,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _word(
                                      context,
                                      'Payments could not be loaded.',
                                      'تادیې نه شوې لوستل کېدای.',
                                      'بارگذاری پرداخت‌ها انجام نشد.',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: _load,
                                    icon: const Icon(Icons.refresh),
                                    label: Text(
                                      _word(
                                        context,
                                        'Retry',
                                        'بیا هڅه',
                                        'تلاش دوباره',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : AnimatedSwitcher(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 180),
                              child: _paymentTable(
                                bodyContext,
                                constraints.maxWidth - pagePadding * 2,
                              ),
                            );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ));
  }

  List<AppCommand> _keyboardCommands() => [
    AppCommand('payments.add', _receive, aliases: [CommandKey.add]),
    AppCommand(CommandKey.search, _searchFocus.requestFocus),
    AppCommand(CommandKey.refresh, _load),
    AppCommand('payments.details', () => withCommandRecord(context, 'payment', _rows, _details)),
    AppCommand('payments.print', () => withCommandRecord(context, 'payment', _rows, _details), aliases: [CommandKey.print]),
    AppCommand('payments.reverse', () => withCommandRecord(context, 'payment', _rows, _reverse, eligible: (row) => row['status'] == 'Posted'), aliases: [CommandKey.remove]),
    AppCommand(CommandKey.edit, () {}, disabledReason: () => localizedCommandText(context,
      'Posted receipts preserve financial history. Open payment details to reverse an eligible receipt.',
      'ثبت شوي رسیدونه نه بدلېږي؛ د بېرته ګرځولو لپاره جزئیات پرانیزئ.', 'رسیدهای ثبت‌شده ویرایش نمی‌شوند؛ برای برگشت رسید، جزئیات را باز کنید.')),
  ];
}
