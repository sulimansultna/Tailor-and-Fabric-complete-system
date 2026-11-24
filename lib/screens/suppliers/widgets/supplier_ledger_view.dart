import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../l10n/app_localizations_extensions.dart';
import '../../../widgets/horizontal_table.dart';
import '../../../widgets/responsive_layout.dart';
import '../supplier_ledger_statement.dart';

Future<void> showSupplierLedger({
  required BuildContext context,
  required Map<String, Object?> supplier,
  required List<Map<String, Object?>> entries,
}) => showResponsiveDialog<void>(
  context: context,
  builder: (context) {
    final size = ResponsiveLayout.dialogSize(context, maxWidth: 1220);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${supplier['name'] ?? ''}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          [
                            _word(context, 'title'),
                            if ('${supplier['code'] ?? ''}'.isNotEmpty)
                              '${supplier['code']}',
                            if ('${supplier['phone'] ?? ''}'.isNotEmpty)
                              '${supplier['phone']}',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SupplierLedgerView(
                entries: entries,
                fallbackOpeningBalance:
                    (supplier['opening_balance'] as num? ?? 0).toInt(),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

class SupplierLedgerView extends StatefulWidget {
  const SupplierLedgerView({
    super.key,
    required this.entries,
    this.fallbackOpeningBalance = 0,
  });
  final List<Map<String, Object?>> entries;
  final int fallbackOpeningBalance;

  @override
  State<SupplierLedgerView> createState() => _SupplierLedgerViewState();
}

class _SupplierLedgerViewState extends State<SupplierLedgerView> {
  final search = TextEditingController();
  final scroll = ScrollController();
  late SupplierLedgerStatement statement;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(covariant SupplierLedgerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries ||
        oldWidget.fallbackOpeningBalance != widget.fallbackOpeningBalance) {
      _prepare();
    }
  }

  void _prepare() => statement = SupplierLedgerStatement(
    widget.entries,
    fallbackOpeningBalance: widget.fallbackOpeningBalance,
  );

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  String _money(int value) => formatPaymentMoney(
    value,
    locale: Localizations.localeOf(context).toLanguageTag(),
  );

  String _description(SupplierLedgerRow row) {
    final raw = '${row.data['description'] ?? ''}';
    const descriptions = {
      'Opening balance': 'opening',
      'Opening supplier credit': 'openingCredit',
      'Fabric purchase': 'purchase',
      'Purchase payment': 'purchasePayment',
      'Supplier payment': 'supplierPayment',
      'Advance to supplier': 'advance',
      'Supplier payment and advance': 'paymentAdvance',
    };
    final key = descriptions[raw];
    if (key != null) return _word(context, key);
    for (final pair in const {
      'Payment reversal:': 'reversal',
      'Purchase return:': 'purchaseReturn',
    }.entries) {
      if (raw.startsWith(pair.key)) {
        return '${_word(context, pair.value)}: ${raw.substring(pair.key.length).trim()}';
      }
    }
    return raw;
  }

  Widget _balance(int value, {Key? key}) {
    final colors = Theme.of(context).colorScheme;
    final state = value > 0
        ? 'owed'
        : value < 0
        ? 'credit'
        : 'settled';
    final color = value > 0
        ? colors.tertiary
        : value < 0
        ? colors.primary
        : colors.onSurfaceVariant;
    return Semantics(
      key: key,
      label: '${_money(value.abs())}, ${_word(context, state)}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _money(value.abs()),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
          Text(
            _word(context, state),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _amount(int value, {bool reduction = false, bool showZero = false}) =>
      Text(
        value == 0 && !showZero ? '—' : _money(value),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: value == 0
              ? Theme.of(context).colorScheme.onSurfaceVariant
              : reduction
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
      );

  Future<void> _details(SupplierLedgerRow row) => showResponsiveDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(_word(context, 'transaction')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (label, value) in [
                (
                  _word(context, 'date'),
                  formatDate(
                    '${row.data['date']}',
                    locale: Localizations.localeOf(context).toLanguageTag(),
                  ),
                ),
                (_word(context, 'reference'), '${row.data['reference'] ?? ''}'),
                (_word(context, 'description'), _description(row)),
                (_word(context, 'increases'), _money(row.increase)),
                (_word(context, 'decreases'), _money(row.decrease)),
                (
                  _word(context, 'balance'),
                  '${_money(row.balance.abs())} · '
                      '${_word(context, row.balance > 0
                          ? 'owed'
                          : row.balance < 0
                          ? 'credit'
                          : 'settled')}',
                ),
                (
                  _word(context, 'purchaseNumber'),
                  '${row.data['purchase_number'] ?? ''}',
                ),
                (
                  _word(context, 'supplierBill'),
                  '${row.data['supplier_bill'] ?? ''}',
                ),
                (
                  _word(context, 'linkedPurchases'),
                  '${row.data['linked_purchase_bills'] ?? ''}',
                ),
                (
                  _word(context, 'voucher'),
                  '${row.data['payment_voucher'] ?? ''}',
                ),
              ])
                if (value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        SelectableText(value),
                      ],
                    ),
                  ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final query = normalizeLocalizedDigits(search.text).trim().toLowerCase();
    final visible = statement.rows
        .where(
          (row) =>
              query.isEmpty ||
              normalizeLocalizedDigits(
                '${row.data.values.join(' ')} ${_description(row)}',
              ).toLowerCase().contains(query),
        )
        .toList();
    final colors = Theme.of(context).colorScheme;
    return Scrollbar(
      controller: scroll,
      thumbVisibility: true,
      child: CustomScrollView(
        key: const ValueKey('supplier-ledger-scroll'),
        controller: scroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = ResponsiveLayout.columns(
                        context,
                        constraints.maxWidth,
                        minWidth: 175,
                        maxColumns: 4,
                        gap: 8,
                      );
                      final width =
                          (constraints.maxWidth - 8 * (columns - 1)) / columns;
                      final values = [
                        (
                          _word(context, 'opening'),
                          _balance(statement.openingBalance),
                        ),
                        (
                          _word(context, 'increases'),
                          _amount(statement.totalIncreases, showZero: true),
                        ),
                        (
                          _word(context, 'decreases'),
                          _amount(
                            statement.totalDecreases,
                            reduction: true,
                            showZero: true,
                          ),
                        ),
                        (
                          _word(context, 'closing'),
                          _balance(
                            statement.closingBalance,
                            key: const ValueKey('supplier-ledger-closing'),
                          ),
                        ),
                      ];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (label, value) in values)
                            SizedBox(
                              width: width,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 80,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: value,
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
                  const SizedBox(height: 10),
                  Text(
                    _word(context, 'explanation'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('supplier-ledger-search'),
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: _word(context, 'search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.l10n.clearSearch,
                              onPressed: () => setState(search.clear),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_word(context, 'allHistory')} · ${visible.length} / '
                    '${statement.rows.length} · ${_word(context, 'oldestFirst')} · '
                    '${_word(context, 'detailsHint')}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: FixedTableHeader(
              height: MediaQuery.textScalerOf(context).scale(12) * 3 + 16,
              child: Material(
                color: colors.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: _StatementColumns(
                    date: _heading('date'),
                    reference: _heading('reference'),
                    description: _heading('description'),
                    compactTransaction: _heading('transaction'),
                    increase: _heading('increases', numeric: true),
                    decrease: _heading('decreases', numeric: true),
                    balance: _heading('balance', numeric: true),
                  ),
                ),
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _word(context, query.isEmpty ? 'empty' : 'noMatches'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final row = visible[index];
                final date = formatDate(
                  '${row.data['date']}',
                  locale: Localizations.localeOf(context).toLanguageTag(),
                );
                final reference = '${row.data['reference'] ?? ''}';
                final bill = '${row.data['supplier_bill'] ?? ''}';
                final description = _description(row);
                return Material(
                  color: index.isEven
                      ? colors.surface
                      : colors.surfaceContainerLow,
                  child: InkWell(
                    key: ValueKey('supplier-ledger-row-${row.data['id']}'),
                    onTap: () => _details(row),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: colors.outlineVariant),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: _StatementColumns(
                        date: _cell(date),
                        reference: _cell(reference, bold: true),
                        description: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cell(description),
                            if (bill.isNotEmpty)
                              _cell('${_word(context, 'supplierBill')}: $bill'),
                          ],
                        ),
                        compactTransaction: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cell(reference, bold: true),
                            _cell(date),
                            _cell(description),
                          ],
                        ),
                        increase: _amount(row.increase),
                        decrease: _amount(row.decrease, reduction: true),
                        balance: _balance(
                          row.balance,
                          key: ValueKey(
                            'supplier-ledger-balance-${row.data['id']}',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          SliverToBoxAdapter(
            child: ColoredBox(
              color: colors.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_word(context, 'closing')} · '
                        '${_word(context, 'allHistory')}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _balance(statement.closingBalance),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String value, {bool bold = false}) => Text(
    value,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontWeight: bold ? FontWeight.w700 : null),
  );

  Widget _heading(String key, {bool numeric = false}) => Text(
    _word(context, key),
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: numeric ? TextAlign.end : null,
    style: Theme.of(context).textTheme.labelSmall
        ?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _StatementColumns extends StatelessWidget {
  const _StatementColumns({
    required this.date,
    required this.reference,
    required this.description,
    required this.compactTransaction,
    required this.increase,
    required this.decrease,
    required this.balance,
  });
  final Widget date, reference, description, compactTransaction;
  final Widget increase, decrease, balance;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 950 * ResponsiveLayout.textFactor(context);
      Widget cell(Widget child, int flex) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: child,
        ),
      );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (wide) ...[
            cell(date, 2),
            cell(reference, 3),
            cell(description, 5),
          ] else
            cell(compactTransaction, 5),
          cell(increase, 3),
          cell(decrease, 3),
          Expanded(flex: 4, child: balance),
        ],
      );
    },
  );
}

String _word(BuildContext context, String key) =>
    _words[Localizations.localeOf(context).languageCode]?[key] ??
    _words['en']![key]!;

const _words = <String, Map<String, String>>{
  'en': {
    'title': 'Supplier ledger',
    'opening': 'Opening balance',
    'closing': 'Closing balance',
    'increases': 'Charges / increases',
    'decreases': 'Payments / credits',
    'balance': 'Running balance',
    'owed': 'Owed to supplier',
    'credit': 'Supplier credit',
    'settled': 'Settled',
    'date': 'Date',
    'reference': 'Reference',
    'description': 'Description',
    'transaction': 'Transaction details',
    'search': 'Search reference, bill, or description',
    'allHistory': 'All transactions',
    'oldestFirst': 'Oldest to newest',
    'detailsHint': 'Select a row for full details',
    'explanation': 'Opening balance + charges − payments / credits = closing balance. Credit means a balance in your favor.',
    'empty': 'No transactions recorded.',
    'noMatches': 'No matching transactions.',
    'openingCredit': 'Opening supplier credit',
    'purchase': 'Fabric purchase',
    'purchasePayment': 'Purchase payment',
    'supplierPayment': 'Supplier payment',
    'advance': 'Advance paid to supplier',
    'paymentAdvance': 'Supplier payment and advance',
    'reversal': 'Payment reversal',
    'purchaseReturn': 'Purchase return',
    'purchaseNumber': 'Purchase number',
    'supplierBill': 'Supplier bill',
    'linkedPurchases': 'Linked purchases',
    'voucher': 'Payment voucher',
  },
  'ps': {
    'title': 'د عرضه کوونکي حساب کتاب',
    'opening': 'لومړنی بیلانس',
    'closing': 'وروستی بیلانس',
    'increases': 'پېرود / زیاتوالی',
    'decreases': 'ورکړې / کریډیټ',
    'balance': 'روان بیلانس',
    'owed': 'عرضه کوونکي ته پور',
    'credit': 'د عرضه کوونکي کریډیټ',
    'settled': 'حساب برابر دی',
    'date': 'نېټه',
    'reference': 'حواله',
    'description': 'تشریح',
    'transaction': 'د معاملې جزئیات',
    'search': 'حواله، بل یا تشریح ولټوئ',
    'allHistory': 'ټولې معاملې',
    'oldestFirst': 'له زړې څخه نوې ته',
    'detailsHint': 'د بشپړو جزئیاتو لپاره معامله وټاکئ',
    'explanation': 'لومړنی بیلانس + پېرود − ورکړې / کریډیټ = وروستی بیلانس. کریډیټ ستاسو په ګټه بیلانس دی.',
    'empty': 'هیڅ معامله نه ده ثبت شوې.',
    'noMatches': 'سمون لرونکې معامله نشته.',
    'openingCredit': 'د عرضه کوونکي لومړنی کریډیټ',
    'purchase': 'د ټوکر پېرود',
    'purchasePayment': 'د پېرود ورکړه',
    'supplierPayment': 'عرضه کوونکي ته ورکړه',
    'advance': 'عرضه کوونکي ته مخکې ورکړه',
    'paymentAdvance': 'عرضه کوونکي ته ورکړه او مخکې ورکړه',
    'reversal': 'د ورکړې بېرته ګرځول',
    'purchaseReturn': 'د پېرود بېرته سپارل',
    'purchaseNumber': 'د پېرود شمېره',
    'supplierBill': 'د عرضه کوونکي بل',
    'linkedPurchases': 'اړوند پېرودونه',
    'voucher': 'د ورکړې سند',
  },
  'fa': {
    'title': 'دفتر حساب تأمین‌کننده',
    'opening': 'مانده اول دوره',
    'closing': 'مانده نهایی',
    'increases': 'خرید / افزایش',
    'decreases': 'پرداخت / اعتبار',
    'balance': 'مانده جاری',
    'owed': 'بدهی به تأمین‌کننده',
    'credit': 'اعتبار نزد تأمین‌کننده',
    'settled': 'تسویه شده',
    'date': 'تاریخ',
    'reference': 'مرجع',
    'description': 'شرح',
    'transaction': 'جزئیات معامله',
    'search': 'جستجوی مرجع، بل یا شرح',
    'allHistory': 'همه معاملات',
    'oldestFirst': 'از قدیم به جدید',
    'detailsHint': 'برای جزئیات کامل، معامله را انتخاب کنید',
    'explanation': 'مانده اول دوره + خرید − پرداخت / اعتبار = مانده نهایی. اعتبار به معنی مانده به نفع شما است.',
    'empty': 'معامله‌ای ثبت نشده است.',
    'noMatches': 'معامله مطابق یافت نشد.',
    'openingCredit': 'اعتبار اول دوره تأمین‌کننده',
    'purchase': 'خرید تکه',
    'purchasePayment': 'پرداخت خرید',
    'supplierPayment': 'پرداخت به تأمین‌کننده',
    'advance': 'پیش‌پرداخت به تأمین‌کننده',
    'paymentAdvance': 'پرداخت و پیش‌پرداخت به تأمین‌کننده',
    'reversal': 'برگشت پرداخت',
    'purchaseReturn': 'برگشت خرید',
    'purchaseNumber': 'شماره خرید',
    'supplierBill': 'بل تأمین‌کننده',
    'linkedPurchases': 'خریدهای مرتبط',
    'voucher': 'سند پرداخت',
  },
};
