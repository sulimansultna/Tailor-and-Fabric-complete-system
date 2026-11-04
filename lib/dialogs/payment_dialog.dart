import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../commands/app_commands.dart';

import '../core/app_date_picker.dart';
import '../core/calendar_service.dart';

import '../core/formatters.dart';
import '../data/shop_database.dart';
import '../l10n/app_localizations_extensions.dart';

String _moneyInput(int minor) => minor % 100 == 0
    ? (minor ~/ 100).toString()
    : (minor / 100).toStringAsFixed(2);

String _paymentText(BuildContext context, String en, String ps, String fa) {
  final language = Localizations.localeOf(context).languageCode;
  return language == 'ps'
      ? ps
      : language == 'fa'
      ? fa
      : en;
}

String _paymentMoney(int minor, String locale) =>
    formatPaymentMoney(minor, locale: locale);

String _paymentAmountLine(
  BuildContext context,
  String en,
  String ps,
  String fa,
  int minor,
  String locale,
) => '${_paymentText(context, en, ps, fa)}: ${_paymentMoney(minor, locale)}';

Future<void> showPaymentDialog(
  BuildContext context,
  ShopDatabase db, {
  Map<String, Object?>? customer,
  Map<String, Object?>? order,
  Future<void> Function(String receipt)? onPrintReceipt,
}) async {
  final inferredCustomer =
      customer ??
      (order == null
          ? null
          : <String, Object?>{
              'id': order['customer_id'],
              'name': order['customer_name'],
              'phone': order['customer_phone'],
              'balance': order['balance'],
            });
  final settings = await db.settings();
  if (!context.mounted) return;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final configuredMethods =
      ((settings['payment_methods'] as String?) ?? 'Cash, Bank transfer, Other')
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
  if (configuredMethods.isEmpty) {
    configuredMethods.addAll(['Cash', 'Bank transfer', 'Other']);
  }
  final amount = TextEditingController();
  final search = TextEditingController(
    text: inferredCustomer?['phone'] as String? ?? '',
  );
  final reference = TextEditingController();
  final notes = TextEditingController();
  final allocations = <int, TextEditingController>{};
  var matches = inferredCustomer == null
      ? <Map<String, Object?>>[]
      : [inferredCustomer];
  int? customerId = inferredCustomer?['id'] as int?;
  String method = configuredMethods.contains('Cash')
      ? 'Cash'
      : configuredMethods.first;
  DateTime date = CalendarService.shopToday();
  bool saving = false;
  List<Map<String, Object?>> orders = [];
  int credit = 0;
  int currentBalance = 0;
  bool loadingCustomer = false;
  bool customerLoadFailed = false;
  bool submitting = false;
  String allocationMode = order == null ? 'oldest' : 'selected';
  final allocatedId = order?['id'] as int?;
  Timer? customerSearchDebounce;
  var customerSearchVersion = 0;
  var customerLoadVersion = 0;
  Future<void> loadCustomer(
    int? id,
    void Function(void Function()) setState,
  ) async {
    final request = ++customerLoadVersion;
    setState(() {
      customerId = id;
      loadingCustomer = id != null;
      customerLoadFailed = false;
      orders = [];
      credit = 0;
      currentBalance = 0;
      for (final controller in allocations.values) {
        controller.dispose();
      }
      allocations.clear();
    });
    try {
      final loadedOrders = id == null
          ? <Map<String, Object?>>[]
          : await db.unpaidOrders(id);
      final summary = id == null
          ? <String, int>{}
          : await db.customerFinancialSummary(id);
      if (request != customerLoadVersion) return;
      setState(() {
        orders = loadedOrders;
        credit = summary['credit'] ?? 0;
        currentBalance = summary['balance'] ?? 0;
        for (final row in orders) {
          allocations[row['id'] as int] = TextEditingController(text: '0');
        }
        loadingCustomer = false;
      });
    } catch (_) {
      if (request != customerLoadVersion) return;
      setState(() {
        loadingCustomer = false;
        customerLoadFailed = true;
      });
    }
  }

  try {
    await loadCustomer(customerId, (update) => update());
    if (!context.mounted) return;
    final dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          final l10n = ctx.l10n;
          final value = parseMoneyMinor(amount.text);
          final received = value ?? 0;
          var allocationTotal = 0;
          if (allocationMode == 'oldest' || allocationMode == 'selected') {
            var remaining = received;
            for (final row in orders) {
              if (allocationMode == 'selected' && row['id'] != allocatedId) {
                allocations[row['id'] as int]?.text = '0';
                continue;
              }
              final balance = (row['remaining'] as int);
              final allocated = remaining < balance ? remaining : balance;
              allocations[row['id'] as int]?.text = _moneyInput(allocated);
              allocationTotal += allocated;
              remaining -= allocated;
            }
          } else {
            for (final controller in allocations.values) {
              allocationTotal += parseMoneyMinor(controller.text) ?? 0;
            }
          }
          final unallocated = (received - allocationTotal).clamp(0, 1 << 60);
          final outstanding = orders.fold<int>(
            0,
            (sum, row) => sum + (row['remaining'] as int),
          );
          final balanceAfter = currentBalance - received;
          final canSave =
              !saving &&
              !submitting &&
              !loadingCustomer &&
              !customerLoadFailed &&
              customerId != null &&
              received > 0 &&
              allocationTotal <= received;
          Future<void> closePayment() async {
            if (saving || submitting) return;
            if ([amount, reference, notes].any((controller) => controller.text.trim().isNotEmpty) && !await confirmCommandDiscard(ctx)) return;
            if (ctx.mounted) Navigator.pop(ctx);
          }
          void updateCustomer(void Function() update) {
            if (ctx.mounted) setState(update);
          }

          final customerName = matches
              .where((c) => c['id'] == customerId)
              .map((c) => c['name'])
              .firstOrNull;
          final screenSize = MediaQuery.sizeOf(ctx);
          final dialogWidth = screenSize.width < 760
              ? math.max(0.0, screenSize.width - 72)
              : math.min(680.0, screenSize.width - 96);
          Future<void> submit(bool printAfterSave) async {
            if (!canSave || saving || submitting) return;
            submitting = true;
            final id = customerId;
            final amountMinor = value ?? 0;
            final reqAllocations = <int, int>{};
            if (allocationMode == 'oldest') {
              var left = amountMinor;
              for (final row in orders) {
                if (left <= 0) break;
                final remaining = row['remaining'] as int;
                final part = remaining < left ? remaining : left;
                if (part > 0) reqAllocations[row['id'] as int] = part;
                left -= part;
              }
            } else {
              for (final row in orders) {
                if (allocationMode == 'selected' && row['id'] != allocatedId) {
                  continue;
                }
                final part =
                    parseMoneyMinor(
                      allocations[row['id'] as int]?.text ?? '',
                    ) ??
                    0;
                if (part > 0) reqAllocations[row['id'] as int] = part;
              }
            }
            final sum = reqAllocations.values.fold<int>(0, (a, b) => a + b);
            if (id == null ||
                amountMinor <= 0 ||
                sum > amountMinor ||
                reqAllocations.entries.any(
                  (entry) =>
                      entry.value >
                      (orders.firstWhere(
                            (o) => o['id'] == entry.key,
                          )['remaining']
                          as int),
                )) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.amountGreaterZero)));
              submitting = false;
              return;
            }
            if (sum < amountMinor) {
              final accepted = await showDialog<bool>(
                context: ctx,
                builder: (c) => AlertDialog(
                  title: Text(
                    _paymentText(
                      ctx,
                      'Confirm customer credit',
                      'د پېرودونکي کریډیټ تایید کړئ',
                      'تأیید اعتبار مشتری',
                    ),
                  ),
                  content: Text(
                    '${_paymentMoney(amountMinor - sum, locale)} ${_paymentText(ctx, 'will remain as customer credit.', 'به د پېرودونکي کریډیټ پاتې شي.', 'به‌عنوان اعتبار مشتری باقی می‌ماند.')}',
                  ),
                  actions: [
                    CommandButton(id: 'action.cancel', child: TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l10n.cancel),
                    )),
                    CommandButton(id: 'action.save', child: FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(
                        _paymentText(ctx, 'Confirm', 'تایید', 'تأیید'),
                      ),
                    )),
                  ],
                ),
              );
              if (!ctx.mounted || accepted != true) {
                submitting = false;
                return;
              }
            }
            setState(() => saving = true);
            try {
              final receipt = await db.receivePayment(
                customerId: id,
                amount: amountMinor,
                date: date,
                method: method,
                description: notes.text.trim(),
                allocations: reqAllocations,
                externalReference: reference.text,
                operationId: 'ui-${DateTime.now().microsecondsSinceEpoch}',
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_paymentText(context, 'Payment saved', 'تادیه ثبت شوه', 'پرداخت ثبت شد')} · $receipt',
                    ),
                  ),
                );
              }
              if (printAfterSave && onPrintReceipt != null) {
                try {
                  await onPrintReceipt(receipt);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _paymentText(
                            context,
                            'Payment saved; printing failed. Reprint it from the Payments list.',
                            'تادیه ثبت شوه؛ چاپ ناکام شو. له تادیو څخه یې بیا چاپ کړئ.',
                            'پرداخت ثبت شد؛ چاپ انجام نشد. از فهرست پرداخت‌ها دوباره چاپ کنید.',
                          ),
                        ),
                      ),
                    );
                  }
                }
              }
            } catch (error) {
              setState(() {
                saving = false;
                submitting = false;
              });
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${_paymentText(context, 'Payment was not saved', 'تادیه ثبت نه شوه', 'پرداخت ثبت نشد')}: $error',
                  ),
                ),
              );
            }
          }

          return AlertDialog(
            icon: const Icon(Icons.payments_outlined),
            title: Text(l10n.receivePaymentTitle),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(120.0, screenSize.height - 200),
              ),
              child: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          l10n.customer,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      TextField(
                        controller: search,
                        enabled: !saving && !submitting,
                        decoration: InputDecoration(
                          labelText: l10n.searchCustomerByNamePhone,
                          prefixIcon: const Icon(Icons.search),
                        ),
                        onChanged: (text) {
                          final request = ++customerSearchVersion;
                          customerSearchDebounce?.cancel();
                          customerSearchDebounce = Timer(
                            const Duration(milliseconds: 250),
                            () async {
                              final found = await db.searchCustomers(text);
                              if (!ctx.mounted ||
                                  request != customerSearchVersion) {
                                return;
                              }
                              matches = found;
                              if (!matches.any(
                                (candidate) => candidate['id'] == customerId,
                              )) {
                                await loadCustomer(null, updateCustomer);
                              }
                              if (ctx.mounted) setState(() {});
                            },
                          );
                        },
                      ),
                      if (matches.isNotEmpty)
                        DropdownButtonFormField<int>(
                          key: ValueKey(customerId),
                          isExpanded: true,
                          initialValue: customerId,
                          decoration: InputDecoration(labelText: l10n.customer),
                          items: matches
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c['id'] as int,
                                  child: Text(
                                    '${c['name']} · ${c['phone']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: saving
                              ? null
                              : (id) => loadCustomer(id, updateCustomer),
                        ),
                      if (customerId != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.customer}: ${customerName ?? ''}  ·  ID ${matches.where((c) => c['id'] == customerId).map((c) => c['code'] ?? c['id']).firstOrNull ?? customerId}',
                        ),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        _paymentText(
                          ctx,
                          'Payment details',
                          'د تادیې جزئیات',
                          'جزئیات پرداخت',
                        ),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const ValueKey('payment-amount'),
                        controller: amount,
                        enabled:
                            !saving &&
                            customerId != null &&
                            !loadingCustomer &&
                            !customerLoadFailed,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.amountAFN,
                          prefixIcon: const Icon(Icons.payments_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      if (loadingCustomer)
                        const LinearProgressIndicator()
                      else if (customerLoadFailed)
                        TextButton.icon(
                          onPressed: () =>
                              loadCustomer(customerId, updateCustomer),
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _paymentText(
                              ctx,
                              'Could not load balance. Retry',
                              'بیلانس ترلاسه نه شو. بیا هڅه وکړئ',
                              'مانده بارگیری نشد. تلاش مجدد',
                            ),
                          ),
                        )
                      else if (customerId != null)
                        _PaymentBalancePreview(
                          currentBalance: currentBalance,
                          received: received,
                          balanceAfter: balanceAfter,
                          locale: locale,
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: method,
                              decoration: InputDecoration(
                                labelText: l10n.method,
                              ),
                              items: configuredMethods
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(
                                        localizedPaymentMethod(ctx, v),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => method = v ?? 'Cash'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                formatDate(
                                  date.toIso8601String(),
                                  locale: Localizations.localeOf(ctx)
                                      .toLanguageTag(),
                                ),
                              ),
                              onPressed: () async {
                                final picked = await showAppDatePicker(
                                  context: ctx,
                                  initialDate: date,
                                  firstDate: DateTime(2000),
                                  lastDate: CalendarService.shopToday(),
                                );
                                if (picked != null && ctx.mounted) {
                                  setState(() => date = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        title: Text(
                          _paymentText(
                            ctx,
                            'More details (optional)',
                            'نور جزئیات (اختیاري)',
                            'جزئیات بیشتر (اختیاری)',
                          ),
                        ),
                        children: [
                          TextField(
                            controller: reference,
                            decoration: InputDecoration(
                              labelText: l10n.reference,
                            ),
                          ),
                          TextField(
                            controller: notes,
                            decoration: InputDecoration(
                              labelText: l10n.additionalNotes,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 24),
                          if (order == null)
                            Row(
                              children: [
                                Text(
                                  _paymentText(
                                    ctx,
                                    'Allocate to bills',
                                    'بلونو ته تخصیص',
                                    'تخصیص به بل‌ها',
                                  ),
                                  style: Theme.of(ctx).textTheme.titleSmall,
                                ),
                                const Spacer(),
                                DropdownButton<String>(
                                  value: allocationMode,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'oldest',
                                      child: Text(
                                        _paymentText(
                                          ctx,
                                          'Oldest first',
                                          'لومړی زوړ',
                                          'ابتدا قدیمی‌تر',
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'multiple',
                                      child: Text(
                                        _paymentText(
                                          ctx,
                                          'Choose bills',
                                          'بلونه وټاکئ',
                                          'انتخاب بل‌ها',
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                    () => allocationMode = v ?? 'oldest',
                                  ),
                                ),
                              ],
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                l10n.paymentForSelectedBill,
                                style: Theme.of(ctx).textTheme.titleSmall,
                              ),
                            ),
                          if (customerId != null &&
                              !loadingCustomer &&
                              !customerLoadFailed &&
                              orders.isEmpty)
                            Text(
                              _paymentText(
                                ctx,
                                'No unpaid bills. Unallocated money becomes customer credit.',
                                'ناورکړل شوي بلونه نشته. نه تخصیص شوې پیسې د پېرودونکي کریډیټ کېږي.',
                                'بل پرداخت‌نشده نیست. مبلغ تخصیص‌نیافته اعتبار مشتری می‌شود.',
                              ),
                            ),
                          for (final row in orders)
                            if (allocationMode != 'selected' ||
                                row['id'] == allocatedId)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  border: Border.all(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${_paymentText(ctx, 'Bill', 'بل', 'بل')} ${row['bill_number']?.toString().trim().isNotEmpty == true ? row['bill_number'].toString() : '—'}',
                                            style: Theme.of(ctx)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                            textDirection: TextDirection.ltr,
                                          ),
                                          Text(
                                            '${_paymentText(ctx, 'Order', 'فرمایش', 'سفارش')} ${row['number']?.toString() ?? '—'}',
                                            textDirection: TextDirection.ltr,
                                          ),
                                          if ((row['garment_summary']
                                                      ?.toString() ??
                                                  '')
                                              .isNotEmpty)
                                            Text(
                                              row['garment_summary'].toString(),
                                              style: Theme.of(ctx)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          const SizedBox(height: 5),
                                          Wrap(
                                            spacing: 12,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                _paymentAmountLine(
                                                  ctx,
                                                  'Invoice total',
                                                  'د بل ټولټال',
                                                  'مجموع بل',
                                                  row['total'] as int,
                                                  locale,
                                                ),
                                              ),
                                              Text(
                                                _paymentAmountLine(
                                                  ctx,
                                                  'Already paid',
                                                  'تر اوسه ورکړل شوي',
                                                  'پرداخت‌شده',
                                                  row['paid'] as int,
                                                  locale,
                                                ),
                                              ),
                                              Text(
                                                _paymentAmountLine(
                                                  ctx,
                                                  'Remaining',
                                                  'پاتې',
                                                  'باقی‌مانده',
                                                  row['remaining'] as int,
                                                  locale,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 160,
                                      child: TextField(
                                        controller:
                                            allocations[row['id'] as int],
                                        enabled:
                                            allocationMode == 'multiple' &&
                                            !saving,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        textAlign: TextAlign.end,
                                        decoration: InputDecoration(
                                          labelText: _paymentText(
                                            ctx,
                                            'Allocation',
                                            'تخصیص',
                                            'مبلغ تخصیص',
                                          ),
                                          prefixText: 'AFN ',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          const Divider(height: 24),
                          Text(
                            _paymentText(
                              ctx,
                              'Bill allocation details',
                              'د تخصیص او بیلانس مخکتنه',
                              'پیش‌نمایش تخصیص و مانده',
                            ),
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _paymentAmountLine(
                              ctx,
                              'Received',
                              'ترلاسه شوي',
                              'دریافتی',
                              received,
                              locale,
                            ),
                          ),
                          Text(
                            _paymentAmountLine(
                              ctx,
                              'Allocated',
                              'تخصیص شوي',
                              'تخصیص‌یافته',
                              allocationTotal,
                              locale,
                            ),
                          ),
                          Text(
                            _paymentAmountLine(
                              ctx,
                              'Becomes customer credit',
                              'د پېرودونکي کریډیټ کېږي',
                              'به اعتبار مشتری تبدیل می‌شود',
                              unallocated,
                              locale,
                            ),
                          ),
                          Text(
                            _paymentAmountLine(
                              ctx,
                              'Available credit after payment',
                              'له تادیې وروسته شته کریډیټ',
                              'اعتبار پس از پرداخت',
                              credit + unallocated,
                              locale,
                            ),
                          ),
                          Text(
                            _paymentAmountLine(
                              ctx,
                              'Unpaid bills after allocation',
                              'له تخصیص وروسته ناورکړل شوي بلونه',
                              'بل‌های پرداخت‌نشده پس از تخصیص',
                              (outstanding - allocationTotal).clamp(0, 1 << 60),
                              locale,
                            ),
                          ),
                        ],
                      ),
                      if (amount.text.trim().isNotEmpty && value == null)
                        Text(
                          _paymentText(
                            ctx,
                            'Enter a valid amount with at most two decimal places.',
                            'سمه اندازه ولیکئ؛ تر دوو اعشاریو پورې.',
                            'مبلغ معتبر با حداکثر دو رقم اعشار وارد کنید.',
                          ),
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              CommandButton(id: 'action.cancel', child: TextButton(
                onPressed: saving ? null : closePayment,
                child: Text(l10n.cancel),
              )),
              OutlinedButton.icon(
                onPressed: !canSave || onPrintReceipt == null
                    ? null
                    : () => submit(true),
                icon: const Icon(Icons.print_outlined),
                label: Text(
                  _paymentText(ctx, 'Save & Print', 'ثبت او چاپ', 'ثبت و چاپ'),
                ),
              ),
              CommandButton(id: 'action.save', child: FilledButton(
                onPressed: canSave ? () => submit(false) : null,
                child: Text(
                  saving
                      ? _paymentText(ctx, 'Saving…', 'ثبت کېږي…', 'در حال ثبت…')
                      : _paymentText(
                          ctx,
                          'Save Payment',
                          'تادیه ثبت کړئ',
                          'ثبت پرداخت',
                        ),
                ),
              )),
            ],
          );
        },
      ),
    );
    await Navigator.of(context, rootNavigator: true).push(dialogRoute);
    // Text fields stay mounted during the closing transition.
    await dialogRoute.completed;
  } finally {
    customerSearchDebounce?.cancel();
    customerSearchVersion++;
    customerLoadVersion++;
    amount.dispose();
    search.dispose();
    reference.dispose();
    notes.dispose();
    for (final controller in allocations.values) {
      controller.dispose();
    }
  }
}

class _PaymentBalancePreview extends StatelessWidget {
  const _PaymentBalancePreview({
    required this.currentBalance,
    required this.received,
    required this.balanceAfter,
    required this.locale,
  });

  final int currentBalance;
  final int received;
  final int balanceAfter;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String balanceText(int balance) {
      final status = balance > 0
          ? _paymentText(
              context,
              'Customer owes',
              'د پېرودونکي پور',
              'بدهی مشتری',
            )
          : balance < 0
          ? _paymentText(
              context,
              'Customer advance',
              'د پېرودونکي پیشکي',
              'پیش‌پرداخت مشتری',
            )
          : _paymentText(context, 'Settled', 'حساب پاک دی', 'تسویه شد');
      return '${_paymentMoney(balance.abs(), locale)} · $status';
    }

    Widget line(String label, String value, {bool emphasis = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 4,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
              color: emphasis ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );

    return Container(
      key: const ValueKey('payment-balance-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(
            _paymentText(
              context,
              'Current balance',
              'اوسنی بیلانس',
              'مانده فعلی',
            ),
            balanceText(currentBalance),
          ),
          line(
            _paymentText(context, 'Payment now', 'اوسنۍ تادیه', 'پرداخت فعلی'),
            _paymentMoney(received, locale),
          ),
          const Divider(),
          line(
            _paymentText(
              context,
              'Balance after payment',
              'له تادیې وروسته بیلانس',
              'مانده پس از پرداخت',
            ),
            balanceText(balanceAfter),
            emphasis: true,
          ),
        ],
      ),
    );
  }
}
