import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';
import '../../reports/order_document_service.dart';

import '../../widgets/responsive_list_page.dart';

import '../../core/app_date_picker.dart';
import '../../core/formatters.dart';
import '../../core/calendar_service.dart';
import '../../data/shop_database.dart';
import '../../dialogs/order_lifecycle_dialogs.dart';
import '../../dialogs/order_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/garment.dart';
import '../../widgets/section_title.dart';
import '../../widgets/shop_logo.dart';
import '../dashboard/dashboard_screen.dart' show showOrderCustomerPicker;

String? _orderDatePart(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.length < 10 ? null : text.substring(0, 10);
}

int _invoiceInt(Object? value, [int fallback = 0]) => value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '') ?? fallback;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.database,
    this.initialFilter,
    this.initialSearch = '',
  });

  final ShopDatabase database;
  final String? initialFilter;
  final String initialSearch;

  @override
  State<OrdersScreen> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersScreen> {
  late String query;
  late final TextEditingController searchController;
  String status = 'All';
  String lifecycleStatus = 'all';
  late String? dashboardFilter;
  final List<Map<String, Object?>> _allOrders = [];
  List<Map<String, Object?>> rows = [];
  bool loading = true;
  bool failed = false;
  bool _historyMode = false;
  String dateScope = 'all';
  DateTime periodAnchor = CalendarService.shopToday();
  DateTimeRange? customRange;

  @override
  void initState() {
    super.initState();
    query = widget.initialSearch;
    searchController = TextEditingController(text: query);
    dashboardFilter = widget.initialFilter;
    if (dashboardFilter == 'ready') status = 'Ready';
    _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.database.searchOrders(
        query: query,
        productionStatus: status == 'All' ? null : status,
        lifecycleStatus: lifecycleStatus,
        includeArchived: true,
      );
      final now = CalendarService.shopToday();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (!mounted) return;
      setState(() {
        _allOrders
          ..clear()
          ..addAll(data);
        rows = _visibleOrders(today);
        loading = false;
        failed = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Orders load failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  bool _matchesDashboardFilter(Map<String, Object?> row, String today) {
    final due = _orderDatePart(row['due_date']);
    return switch (dashboardFilter) {
      'newToday' => _orderDatePart(row['order_date']) == today,
      'dueToday' =>
        due == today &&
            row['status'] != 'Delivered' &&
            row['cancellation_status'] != 'Cancelled',
      'overdue' =>
        due != null &&
            due.compareTo(today) < 0 &&
            row['status'] != 'Delivered' &&
            row['cancellation_status'] != 'Cancelled',
      'ready' => row['status'] == 'Ready',
      _ => true,
    };
  }

  String _todayKey() {
    final now = CalendarService.shopToday();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, Object?>> _visibleOrders(String today) => _allOrders
      .where(
        (row) =>
            (!_historyMode || row['status'] == 'Delivered' || _invoiceInt(row['archived']) != 0) &&
            (status == 'All' || row['status'] == status) &&
            (lifecycleStatus == 'all' ||
                (lifecycleStatus == 'cancelled' &&
                    row['cancellation_status'] == 'Cancelled') ||
                (lifecycleStatus == 'active' &&
                    row['cancellation_status'] != 'Cancelled' &&
                    row['archived'] != 1) ||
                (lifecycleStatus == 'returned' && row['has_returns'] == 1) ||
                (lifecycleStatus == 'archived' && row['archived'] == 1)) &&
            _matchesDashboardFilter(row, today) &&
            _matchesDateScope(row) &&
            ('${row['number']} ${row['bill_number'] ?? ''} ${row['name']} ${row['phone']}'
                .toLowerCase()
                .contains(query.toLowerCase())),
      )
      .toList();

  bool _matchesDateScope(Map<String, Object?> row) {
    if (dateScope == 'all') return true;
    final rawDate = row['order_date']?.toString();
    if (rawDate == null) return false;
    if (dateScope == 'range') {
      final range = customRange;
      if (range == null) return true;
      final start = _orderDatePart(range.start.toIso8601String())!;
      final end = _orderDatePart(range.end.toIso8601String())!;
      final orderDate = _orderDatePart(rawDate);
      return orderDate != null &&
          orderDate.compareTo(start) >= 0 &&
          orderDate.compareTo(end) <= 0;
    }
    final date = CalendarService.dateForDisplay(rawDate);
    if (date == null) return false;
    final year = _calendarYear(date);
    if (year != _periodYear) return false;
    return dateScope != 'month' || _calendarMonth(date) == _periodMonth;
  }

  int _calendarYear(DateTime date) =>
      CalendarService.activeCalendar == CalendarService.solarHijri
      ? CalendarService.fromGregorian(date).year
      : date.year;

  int _calendarMonth(DateTime date) =>
      CalendarService.activeCalendar == CalendarService.solarHijri
      ? CalendarService.fromGregorian(date).month
      : date.month;

  int get _periodYear => _calendarYear(periodAnchor);
  int get _periodMonth => _calendarMonth(periodAnchor);

  DateTime _firstDateOfPeriod(int year, int month) =>
      CalendarService.activeCalendar == CalendarService.solarHijri
      ? CalendarService.toGregorian(SolarDate(year, month, 1))
      : DateTime(year, month, 1);

  List<int> get _availableYears {
    final years = <int>{
      _calendarYear(CalendarService.shopToday()),
      _periodYear,
    };
    for (final row in _allOrders) {
      final rawDate = row['order_date']?.toString();
      final date = rawDate == null
          ? null
          : CalendarService.dateForDisplay(rawDate);
      if (date != null) years.add(_calendarYear(date));
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }

  String _periodText(String key) {
    final language = Localizations.localeOf(context).languageCode;
    return switch ((key, language)) {
      ('filter', 'ps') => 'د فرمایشونو موده',
      ('all', 'ps') => 'ټولې نېټې',
      ('monthMode', 'ps') => 'میاشتني',
      ('yearMode', 'ps') => 'کلني',
      ('month', 'ps') => 'میاشت',
      ('year', 'ps') => 'کال',
      ('filter', 'fa') => 'بازهٔ سفارش‌ها',
      ('all', 'fa') => 'همهٔ تاریخ‌ها',
      ('monthMode', 'fa') => 'ماهانه',
      ('yearMode', 'fa') => 'سالانه',
      ('month', 'fa') => 'ماه',
      ('year', 'fa') => 'سال',
      ('filter', _) => 'Order period',
      ('all', _) => 'All dates',
      ('monthMode', _) => 'Monthly',
      ('yearMode', _) => 'Yearly',
      ('month', _) => 'Month',
      ('year', _) => 'Year',
      ('range', _) => '${context.l10n.fromDate} / ${context.l10n.toDate}',
      _ => key,
    };
  }

  String _monthName(int month) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (CalendarService.activeCalendar == CalendarService.solarHijri) {
      return CalendarService.solarMonthName(month, locale);
    }
    return CalendarService.format(
      DateTime(2020, month, 1),
      calendar: CalendarService.gregorian,
      locale: locale,
      includeYear: false,
    ).replaceFirst(RegExp(r'^\d+\s*'), '');
  }

  Future<void> _editOrder(Map<String, Object?> order) async {
    try {
      if (await showEditConfirmedOrderDialog(context, widget.database, order)) {
        await _load();
      }
    } catch (error, stackTrace) {
      debugPrint('Invoice edit failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${orderLifecycleLabel(context, 'operationFailed')}: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _cancelOrder(Map<String, Object?> order) async {
    try {
      if (await showCancelOrderDialog(context, widget.database, order)) {
        await _load();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${orderLifecycleLabel(context, 'operationFailed')}: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _returnOrder(Map<String, Object?> order) async {
    try {
      final number = await showReturnOrderDialog(
        context,
        widget.database,
        order,
      );
      if (number == null || !mounted) return;
      await _load();
      final available = await widget.database.availableCustomerCredit(
        _invoiceInt(order['customer_id']),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$number · ${orderLifecycleLabel(context, 'returnRecorded')} · ${formatMoney(available)} ${orderLifecycleLabel(context, 'availableCredit')}',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${orderLifecycleLabel(context, 'operationFailed')}: $error',
            ),
          ),
        );
      }
    }
  }

  Future<void> _refundOrder(Map<String, Object?> order) async {
    final returns = await widget.database.orderReturns(
      _invoiceInt(order['id']),
    );
    if (!mounted) return;
    final latestReturnId = returns.isEmpty
        ? null
        : _invoiceInt(returns.first['id']);
    if (await showCustomerRefundDialog(
      context,
      widget.database,
      _invoiceInt(order['customer_id']),
      orderReturnId: latestReturnId,
    )) {
      await _load();
    }
  }

  Future<void> _archiveOrder(Map<String, Object?> order) async {
    final archive = _invoiceInt(order['archived']) == 0;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(commandText(ctx, archive ? 'order.archive' : 'order.restore')),
      content: Text('${order['bill_number'] ?? order['number']}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(localizedCommandText(ctx, 'Confirm', 'تایید', 'تأیید')))],
    ));
    if (confirmed != true) return;
    await widget.database.archiveOrder(
      _invoiceInt(order['id']),
      archived: archive,
    );
    await _load();
  }

  Future<void> _orderCommand(Future<void> Function(Map<String, Object?>) action,
      {bool Function(Map<String, Object?>)? eligible}) =>
      withCommandRecord(context, 'order', rows, action, eligible: eligible);

  List<AppCommand> _keyboardCommands() => [
    AppCommand('orders.add', _newOrder, aliases: [CommandKey.add]),
    AppCommand('orders.edit', () => _orderCommand(_editOrder, eligible: (row) => row['cancellation_status'] != 'Cancelled' && row['has_returns'] != 1 && _invoiceInt(row['archived']) == 0), aliases: [CommandKey.edit]),
    AppCommand(CommandKey.search, () => focusCommandSearch(searchController)),
    AppCommand(CommandKey.refresh, _load),
    AppCommand('orders.drafts', _openDrafts),
    AppCommand('orders.print', () => _orderCommand((row) => previewOrderDocument(context, widget.database, row['id'] as int, kind: OrderDocumentKind.customerBill, locale: Localizations.localeOf(context).toLanguageTag())), aliases: [CommandKey.print]),
    AppCommand('orders.printBoth', () => _orderCommand((row) => _printOrder(row, Localizations.localeOf(context).toLanguageTag(), both: true)), aliases: [CommandKey.printBoth]),
    AppCommand('orders.measurementPrint', () => _orderCommand((row) => previewOrderDocument(context, widget.database, row['id'] as int, kind: OrderDocumentKind.measurements, locale: Localizations.localeOf(context).toLanguageTag()))),
    AppCommand('orders.history', () => _orderCommand(_showHistory)),
    AppCommand('order.cancel', () => _orderCommand(_cancelOrder, eligible: _canCancelCommand), disabledReason: () => commandEligibility(context, 'order', rows, _canCancelCommand, ('Select an active, undelivered invoice without returns.', 'فعال او نه سپارل شوی بل وټاکئ.', 'بل فعال و تحویل‌نشده بدون برگشت را انتخاب کنید.'))),
    AppCommand('order.return', () => _orderCommand(_returnOrder, eligible: (row) => row['cancellation_status'] != 'Cancelled' && row['status'] == 'Delivered' && _invoiceInt(row['archived']) == 0)),
    AppCommand('orders.refund', () => _orderCommand(_refundOrder)),
    AppCommand('order.archive', () => _orderCommand(_archiveOrder, eligible: _canArchiveCommand), disabledReason: () => commandEligibility(context, 'order', rows, _canArchiveCommand, ('Only an eligible delivered order can be archived with this shortcut.', 'د دې لنډلارې له مخې یوازې سپارل شوی فرمایش آرشیف کېږي.', 'با این میان‌بر فقط سفارش تحویل‌شده واجد شرایط آرشیف می‌شود.'))),
    AppCommand('order.restore', () => _orderCommand(_archiveOrder, eligible: (row) => _invoiceInt(row['archived']) != 0)),
    AppCommand('orders.remove', () => _orderCommand((row) => row['cancellation_status'] == 'Cancelled' || row['status'] == 'Delivered' || row['has_returns'] == 1 ? _archiveOrder(row) : _cancelOrder(row)), aliases: [CommandKey.remove]),
    AppCommand('order.deliver', () => _orderCommand((row) async {
      final registry = AppCommandRegistry.maybeOf(context);
      registry?.select('order', row);
      if (registry != null) await registry.forward(() => registry.invoke('nav.delivery'), 'order.deliver');
    }, eligible: _canDeliverCommand), disabledReason: () => commandEligibility(context, 'order', rows, _canDeliverCommand, ('Select a Ready order before marking it delivered.', 'لومړی چمتو فرمایش وټاکئ.', 'ابتدا سفارش آماده را انتخاب کنید.'))),
    AppCommand('nav.history', () async { setState(() { _historyMode = true; status = 'All'; lifecycleStatus = 'all'; dateScope = 'all'; dashboardFilter = null; }); await _load(); }),
    AppCommand('nav.orders', () async { setState(() => _historyMode = false); await _load(); }),
  ];

  bool _canDeliverCommand(Map<String, Object?> row) => row['status'] == 'Ready' && row['cancellation_status'] != 'Cancelled';
  bool _canArchiveCommand(Map<String, Object?> row) => row['status'] == 'Delivered' && _invoiceInt(row['archived']) == 0;
  bool _canCancelCommand(Map<String, Object?> row) => row['cancellation_status'] != 'Cancelled' && row['status'] != 'Delivered' && row['has_returns'] != 1 && _invoiceInt(row['archived']) == 0;

  Future<void> _showHistory(Map<String, Object?> order) =>
      showOrderChangeHistory(
        context,
        widget.database,
        _invoiceInt(order['id']),
      );

  Future<void> _printOrder(Map<String, Object?> order, String locale, {bool both = false}) async {
    await showSavedOrderPrintOptions(
      context,
      widget.database,
      order['id'] as int,
      locale: locale,
      focusPrintBoth: both,
    );
  }

  Future<void> _closeInvoiceThen(
    BuildContext dialogContext,
    Future<void> Function() action,
  ) async {
    final route = ModalRoute.of(dialogContext);
    Navigator.of(dialogContext).pop();
    await route?.completed;
    if (mounted) await action();
  }

  Future<void> _newOrder() async {
    final customer = await showOrderCustomerPicker(context, widget.database);
    if (!mounted || customer == null) return;
    await showOrderDialog(context, widget.database, customer);
    if (mounted) await _load();
  }

  Future<void> _openDrafts() async {
    var trash = false;
    var future = widget.database.orderDrafts();
    ModalRoute<void>? dialogRoute;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        dialogRoute = ModalRoute.of(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(orderLifecycleLabel(dialogContext, 'drafts')),
            content: SizedBox(
              width: 560,
              height: 430,
              child: FutureBuilder<List<Map<String, Object?>>>(
                future: future,
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final drafts = snapshot.data!;
                  if (drafts.isEmpty) {
                    return Center(
                      child: Text(
                        trash
                            ? orderLifecycleLabel(context, 'noHistory')
                            : orderLifecycleLabel(context, 'drafts'),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: drafts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final draft = drafts[index];
                      final draftId = _invoiceInt(draft['id']);
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          '${draft['customer_name']} · ${draft['customer_phone']}',
                        ),
                        subtitle: Text(
                          '${orderLifecycleLabel(context, 'drafts')} · ${draft['updated_at']}',
                        ),
                        trailing: trash
                            ? IconButton(
                                tooltip: orderLifecycleLabel(
                                  context,
                                  'restore',
                                ),
                                icon: const Icon(Icons.restore_outlined),
                                onPressed: () async {
                                  await widget.database.restoreOrderDraft(
                                    draftId,
                                  );
                                  setDialogState(() {
                                    future = widget.database.orderDrafts(
                                      trash: true,
                                    );
                                  });
                                },
                              )
                            : Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: orderLifecycleLabel(
                                      context,
                                      'editBill',
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      final route = dialogRoute;
                                      Navigator.pop(dialogContext);
                                      await route?.completed;
                                      if (!mounted) return;
                                      final customer = await widget.database
                                          .customerDetails(
                                            _invoiceInt(draft['customer_id']),
                                          );
                                      if (customer == null || !mounted) return;
                                      await showOrderDialog(
                                        context,
                                        widget.database,
                                        customer,
                                        draftId: draftId,
                                      );
                                      if (mounted) await _load();
                                    },
                                  ),
                                  IconButton(
                                    tooltip: orderLifecycleLabel(
                                      context,
                                      'deleteDraft',
                                    ),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await widget.database.trashOrderDraft(
                                        draftId,
                                      );
                                      setDialogState(() {
                                        future = widget.database.orderDrafts();
                                      });
                                    },
                                  ),
                                ],
                              ),
                        onTap: trash
                            ? null
                            : () async {
                                final route = dialogRoute;
                                Navigator.pop(dialogContext);
                                await route?.completed;
                                if (!mounted) return;
                                final customer = await widget.database
                                    .customerDetails(
                                      _invoiceInt(draft['customer_id']),
                                    );
                                if (customer == null || !mounted) return;
                                await showOrderDialog(
                                  context,
                                  widget.database,
                                  customer,
                                  draftId: draftId,
                                );
                                if (mounted) await _load();
                              },
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  setDialogState(() {
                    trash = !trash;
                    future = widget.database.orderDrafts(trash: trash);
                  });
                },
                icon: Icon(
                  trash ? Icons.description_outlined : Icons.delete_outline,
                ),
                label: Text(
                  orderLifecycleLabel(
                    dialogContext,
                    trash ? 'drafts' : 'trash',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(context.l10n.close),
              ),
            ],
          ),
        );
      },
    );
    await dialogRoute?.completed;
  }

  Future<void> _openInvoice(Map<String, Object?> order) async {
    final id = _invoiceInt(order['id']);
    final garments = await widget.database.orderLines(id);
    final fabrics = await widget.database.orderFabricLines(id);
    final shop = await widget.database.settings();
    if (!mounted) return;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final total = _invoiceInt(order['total']);
    final paid = _invoiceInt(order['paid']);
    final remaining = (total - paid).clamp(0, 1 << 60).toInt();
    final stitching = _invoiceInt(order['stitching_total'], total);
    final fabricTotal = _invoiceInt(order['fabric_total']);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.invoiceDetails),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShopLogo(
                      path: shop['shop_logo_path']?.toString(),
                      size: 52,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (shop['shop_name'] as String?)?.trim().isNotEmpty ==
                                    true
                                ? shop['shop_name'] as String
                                : l10n.shopName,
                            style: Theme.of(dialogContext).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if ((shop['owner_name'] as String?)
                                  ?.trim()
                                  .isNotEmpty ==
                              true)
                            Text('${l10n.ownerName}: ${shop['owner_name']}'),
                          if ((shop['phone'] as String?)?.trim().isNotEmpty ==
                              true)
                            Text('${l10n.mobileNumber}: ${shop['phone']}'),
                          if ((shop['address'] as String?)?.trim().isNotEmpty ==
                              true)
                            Text('${l10n.address}: ${shop['address']}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  '${order['bill_number'] ?? l10n.billNotAssigned}  ·  ${order['number'] ?? ''}',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text('${order['name'] ?? ''}  ·  ${order['phone'] ?? ''}'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Chip(
                      label: Text(
                        localizedStatus(
                          dialogContext,
                          order['status']?.toString() ?? 'Received',
                        ),
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${l10n.advancePayment}: ${formatMoney(paid, locale: locale)} · ${l10n.remainingBalance}: ${formatMoney(remaining, locale: locale)}',
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    if (order['cancellation_status'] == 'Cancelled')
                      Chip(
                        label: Text(
                          orderLifecycleLabel(dialogContext, 'cancelled'),
                        ),
                        backgroundColor: Theme.of(dialogContext)
                            .colorScheme
                            .errorContainer,
                      ),
                    if (order['has_returns'] == 1)
                      Chip(
                        label: Text(
                          orderLifecycleLabel(dialogContext, 'returned'),
                        ),
                        backgroundColor: Theme.of(dialogContext)
                            .colorScheme
                            .primaryContainer,
                      ),
                    if (order['archived'] == 1)
                      Chip(
                        label: Text(
                          orderLifecycleLabel(dialogContext, 'archived'),
                        ),
                      ),
                    if (_invoiceInt(order['revision_no']) > 0)
                      Chip(
                        label: Text(
                          '${orderLifecycleLabel(dialogContext, 'revision')} #${_invoiceInt(order['revision_no'])}',
                        ),
                      ),
                  ],
                ),
                Text(
                  '${l10n.orderDate}: ${formatDate(order['order_date'] as String, locale: locale)}',
                ),
                const Divider(height: 24),
                Text(
                  l10n.orderDetails,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final line in garments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        _GarmentThumbnail(
                          garmentKey: line['garment']?.toString() ?? '',
                          size: 54,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_garmentName(l10n, line['garment']?.toString() ?? '')} × ${_invoiceInt(line['quantity'])}',
                          ),
                        ),
                        Text(
                          formatMoney(
                            _invoiceInt(line['price_each']) *
                                _invoiceInt(line['quantity']),
                            locale: locale,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                if (fabrics.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    l10n.fabricAmount,
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  for (final line in fabrics)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line['ownership'] == 'shop'
                                  ? '${line['fabric_code'] ?? ''} · ${line['fabric_name'] ?? line['description'] ?? ''} (${(_invoiceInt(line['quantity_milli']) / 1000).toStringAsFixed(3)} ${line['fabric_unit'] == 'meter' ? l10n.fabricFormMeter : l10n.fabricFormUnitReview(line['fabric_unit']?.toString() ?? '')})'
                                  : '${line['description'] ?? l10n.customerSuppliedNoCharge} (${(_invoiceInt(line['quantity_milli']) / 1000).toStringAsFixed(3)} ${l10n.fabricFormMeter})',
                            ),
                          ),
                          Text(
                            line['ownership'] == 'shop'
                                ? formatMoney(
                                    ((_invoiceInt(line['quantity_milli']) *
                                                _invoiceInt(
                                                  line['unit_price'],
                                                ) +
                                            500) ~/
                                        1000),
                                    locale: locale,
                                  )
                                : l10n.customerSuppliedNoCharge,
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                ],
                const Divider(height: 24),
                _InvoiceAmount(
                  label: l10n.stitchingAmount,
                  amount: stitching,
                  locale: locale,
                ),
                _InvoiceAmount(
                  label: l10n.fabricAmount,
                  amount: fabricTotal,
                  locale: locale,
                ),
                const Divider(height: 16),
                _InvoiceAmount(
                  label: l10n.total,
                  amount: total,
                  locale: locale,
                  prominent: true,
                ),
                _InvoiceAmount(
                  label: l10n.advancePayment,
                  amount: paid,
                  locale: locale,
                ),
                _InvoiceAmount(
                  label: l10n.remainingBalance,
                  amount: remaining,
                  locale: locale,
                  prominent: true,
                ),
                if ((order['notes'] as String?)?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(l10n.notesLabel(order['notes'] as String)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _closeInvoiceThen(
              dialogContext,
              () => _printOrder(order, locale),
            ),
            icon: const Icon(Icons.print_outlined),
            label: Text(context.l10n.printDocument),
          ),
          if (order['cancellation_status'] != 'Cancelled' &&
              order['archived'] != 1 &&
              order['has_returns'] != 1)
            TextButton.icon(
              onPressed: () =>
                  _closeInvoiceThen(dialogContext, () => _editOrder(order)),
              icon: const Icon(Icons.edit_outlined),
              label: Text(context.l10n.editInvoice),
            ),
          if (order['cancellation_status'] != 'Cancelled' &&
              order['archived'] != 1 &&
              order['has_returns'] != 1 &&
              order['status'] != 'Delivered')
            TextButton.icon(
              onPressed: () =>
                  _closeInvoiceThen(dialogContext, () => _cancelOrder(order)),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(orderLifecycleLabel(dialogContext, 'cancelOrder')),
            ),
          if (order['cancellation_status'] != 'Cancelled' &&
              order['archived'] != 1 &&
              order['status'] == 'Delivered')
            TextButton.icon(
              onPressed: () =>
                  _closeInvoiceThen(dialogContext, () => _returnOrder(order)),
              icon: const Icon(Icons.assignment_return_outlined),
              label: Text(orderLifecycleLabel(dialogContext, 'returnItems')),
            ),
          if (order['has_returns'] == 1 ||
              order['cancellation_status'] == 'Cancelled' ||
              (order['paid'] as num? ?? 0) > 0)
            TextButton.icon(
              onPressed: () =>
                  _closeInvoiceThen(dialogContext, () => _refundOrder(order)),
              icon: const Icon(Icons.payments_outlined),
              label: Text(orderLifecycleLabel(dialogContext, 'refund')),
            ),
          TextButton.icon(
            onPressed: () =>
                _closeInvoiceThen(dialogContext, () => _showHistory(order)),
            icon: const Icon(Icons.history),
            label: Text(orderLifecycleLabel(dialogContext, 'changeHistory')),
          ),
          TextButton.icon(
            onPressed: () =>
                _closeInvoiceThen(dialogContext, () => _archiveOrder(order)),
            icon: Icon(
              order['archived'] == 1
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
            label: Text(
              orderLifecycleLabel(
                dialogContext,
                order['archived'] == 1 ? 'unarchive' : 'archive',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  String _garmentName(AppLocalizations l10n, String key) => switch (key) {
    'shalwar' => l10n.shalwar,
    'waistcoat' => l10n.waistcoat,
    'coat' => l10n.coat,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 28.0;
    final statuses = [
      'All',
      'Received',
      'Cutting',
      'Stitching',
      'Ready',
      'Delivered',
    ];
    final totalOutstanding = rows.fold<int>(
      0,
      (sum, row) =>
          sum +
          ((row['total'] as int) - (row['paid'] as int))
              .clamp(0, 1 << 30)
              .toInt(),
    );

    return CommandScope(commands: _keyboardCommands(), builder: (context) => Padding(
      padding: EdgeInsets.all(padding),
      child: ResponsiveListPage(
        header: [
          sectionTitle(context, _historyMode ? commandText(context, 'nav.history') : l10n.orders),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openDrafts,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(orderLifecycleLabel(context, 'drafts')),
                ),
                CommandButton(register: false, aliases: const ['action.new'], id: 'orders.add', child: FilledButton.icon(
                  onPressed: _newOrder,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newOrder),
                )),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.searchOrderHint,
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.clearSearch,
                            onPressed: () {
                              searchController.clear();
                              query = '';
                              _load();
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) {
                    query = value;
                    _load();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: l10n.refreshDashboard,
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _OrdersMetric(
                  icon: Icons.receipt_long_outlined,
                  label: l10n.orders,
                  value: '${rows.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OrdersMetric(
                  icon: Icons.account_balance_wallet_outlined,
                  label: l10n.outstandingBalance,
                  value: formatMoney(totalOutstanding, locale: locale),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in statuses) ...[
                  ChoiceChip(
                    label: Text(
                      value == 'All'
                          ? l10n.all
                          : localizedStatus(context, value),
                    ),
                    selected: status == value,
                    onSelected: (_) {
                      setState(() => status = value);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(orderLifecycleLabel(context, 'status')),
                const SizedBox(width: 8),
                for (final value in const [
                  'all',
                  'active',
                  'cancelled',
                  'returned',
                  'archived',
                ]) ...[
                  ChoiceChip(
                    label: Text(
                      orderLifecycleLabel(
                        context,
                        value == 'all' ? 'allBills' : value,
                      ),
                    ),
                    selected: lifecycleStatus == value,
                    onSelected: (_) {
                      setState(() {
                        lifecycleStatus = value;
                        if (value == 'cancelled') status = 'All';
                      });
                      _load();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  _periodText('filter'),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                for (final scope in const [
                  'all',
                  'month',
                  'year',
                  'range',
                ]) ...[
                  ChoiceChip(
                    label: Text(
                      _periodText(switch (scope) {
                        'month' => 'monthMode',
                        'year' => 'yearMode',
                        'range' => 'range',
                        _ => 'all',
                      }),
                    ),
                    selected: dateScope == scope,
                    onSelected: (_) async {
                      if (scope == 'range') {
                        final picked = await showAppDateRangePicker(
                          context: context,
                          firstDate: DateTime(1900),
                          lastDate: CalendarService.shopToday(),
                          initialDateRange: customRange,
                        );
                        if (picked == null || !mounted) return;
                        setState(() {
                          customRange = picked;
                          dateScope = 'range';
                          rows = _visibleOrders(_todayKey());
                        });
                        return;
                      }
                      setState(() {
                        dateScope = scope;
                        rows = _visibleOrders(_todayKey());
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                if (dateScope == 'month') ...[
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('month-$_periodMonth'),
                      initialValue: _periodMonth,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _periodText('month'),
                        isDense: true,
                      ),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: month,
                            child: Text(_monthName(month)),
                          ),
                      ],
                      onChanged: (month) {
                        if (month == null) return;
                        setState(() {
                          periodAnchor = _firstDateOfPeriod(_periodYear, month);
                          rows = _visibleOrders(_todayKey());
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (dateScope == 'range' && customRange != null) ...[
                  Text(
                    '${formatDate(customRange!.start.toIso8601String(), locale: locale)} – ${formatDate(customRange!.end.toIso8601String(), locale: locale)}',
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(width: 8),
                ],
                if (dateScope != 'all' && dateScope != 'range')
                  SizedBox(
                    width: 124,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('year-$_periodYear'),
                      initialValue: _periodYear,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: _periodText('year'),
                        isDense: true,
                      ),
                      items: [
                        for (final year in _availableYears)
                          DropdownMenuItem(
                            value: year,
                            child: Text(
                              '$year',
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                      ],
                      onChanged: (year) {
                        if (year == null) return;
                        setState(() {
                          periodAnchor = _firstDateOfPeriod(year, _periodMonth);
                          rows = _visibleOrders(_todayKey());
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.errorGeneric),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              )
            : rows.isEmpty
            ? Center(child: Text(l10n.noOrdersFound))
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 12),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => CommandRecordTarget(kind: 'order', record: rows[index], child: _OrderCard(
                  row: rows[index],
                  locale: locale,
                  onViewInvoice: () => _openInvoice(rows[index]),
                  onEdit: () => _editOrder(rows[index]),
                  onPrint: () => _printOrder(rows[index], locale),
                  onCancel: () => _cancelOrder(rows[index]),
                  onReturn: () => _returnOrder(rows[index]),
                  onRefund: () => _refundOrder(rows[index]),
                  onHistory: () => _showHistory(rows[index]),
                  onArchive: () => _archiveOrder(rows[index]),
                    )),
              ),
      ),
    ));
  }
}

class _OrdersMetric extends StatelessWidget {
  const _OrdersMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InvoiceAmount extends StatelessWidget {
  const _InvoiceAmount({
    required this.label,
    required this.amount,
    required this.locale,
    this.prominent = false,
  });

  final String label;
  final int amount;
  final String locale;
  final bool prominent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: prominent
                ? Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800)
                : null,
          ),
        ),
        Text(
          formatMoney(amount, locale: locale),
          textDirection: TextDirection.ltr,
          style: prominent
              ? Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)
              : null,
        ),
      ],
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.row,
    required this.locale,
    required this.onViewInvoice,
    required this.onEdit,
    required this.onPrint,
    required this.onCancel,
    required this.onReturn,
    required this.onRefund,
    required this.onHistory,
    required this.onArchive,
  });

  final Map<String, Object?> row;
  final String locale;
  final VoidCallback onViewInvoice;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onCancel;
  final VoidCallback onReturn;
  final VoidCallback onRefund;
  final VoidCallback onHistory;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = (row['total'] as num? ?? 0).toInt();
    final status = row['status'] as String? ?? 'Received';
    final due = _orderDatePart(row['due_date']);
    final garments = _orderGarments(row['garment_summary']);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 1050
              ? _wideOrderRow(
                  context,
                  garments: garments,
                  due: due,
                  total: total,
                  status: status,
                  l10n: l10n,
                )
              : _compactOrderRow(
                  context,
                  garments: garments,
                  due: due,
                  total: total,
                  status: status,
                  l10n: l10n,
                ),
        ),
      ),
    );
  }

  Widget _wideOrderRow(
    BuildContext context, {
    required List<(String, int)> garments,
    required String? due,
    required int total,
    required String status,
    required AppLocalizations l10n,
  }) => Row(
    children: [
      SizedBox(width: 112, child: _OrderImages(garments: garments)),
      const SizedBox(width: 10),
      SizedBox(
        width: 145,
        child: _OrderValueCell(
          label: l10n.billNumber,
          value: row['bill_number'] as String? ?? l10n.billNotAssigned,
          ltr: true,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: _OrderValueCell(
          label: l10n.customer,
          value: row['customer_name'] as String? ?? '',
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: _OrderValueCell(
          label: l10n.reportFieldDueDate,
          value: due == null ? l10n.notSet : formatDate(due, locale: locale),
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 118,
        child: _OrderValueCell(
          label: l10n.total,
          value: formatMoney(total, locale: locale),
          ltr: true,
          emphasized: true,
        ),
      ),
      const SizedBox(width: 8),
      _statusChip(context, status),
      if (row['cancellation_status'] == 'Cancelled' ||
          row['has_returns'] == 1 ||
          row['archived'] == 1) ...[
        const SizedBox(width: 4),
        _lifecycleChip(context),
      ],
      if (_invoiceInt(row['revision_no']) > 0) ...[
        const SizedBox(width: 4),
        _revisionChip(context),
      ],
      const SizedBox(width: 4),
      _actions(context, l10n),
    ],
  );

  Widget _compactOrderRow(
    BuildContext context, {
    required List<(String, int)> garments,
    required String? due,
    required int total,
    required String status,
    required AppLocalizations l10n,
  }) => Column(
    children: [
      Row(
        children: [
          SizedBox(width: 104, child: _OrderImages(garments: garments)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderValueCell(
                  label: l10n.billNumber,
                  value: row['bill_number'] as String? ?? l10n.billNotAssigned,
                  ltr: true,
                ),
                const SizedBox(height: 7),
                _OrderValueCell(
                  label: l10n.customer,
                  value: row['customer_name'] as String? ?? '',
                ),
              ],
            ),
          ),
          _statusChip(context, status),
          if (row['cancellation_status'] == 'Cancelled' ||
              row['has_returns'] == 1 ||
              row['archived'] == 1) ...[
            const SizedBox(width: 4),
            _lifecycleChip(context),
          ],
          if (_invoiceInt(row['revision_no']) > 0) ...[
            const SizedBox(width: 4),
            _revisionChip(context),
          ],
        ],
      ),
      const Divider(height: 18),
      Row(
        children: [
          Expanded(
            child: _OrderValueCell(
              label: l10n.reportFieldDueDate,
              value: due == null
                  ? l10n.notSet
                  : formatDate(due, locale: locale),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OrderValueCell(
              label: l10n.total,
              value: formatMoney(total, locale: locale),
              ltr: true,
              emphasized: true,
            ),
          ),
          _actions(context, l10n),
        ],
      ),
    ],
  );

  Widget _statusChip(BuildContext context, String status) {
    final color = _statusColor(context, status);
    return Chip(
      label: Text(localizedStatus(context, status)),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _lifecycleChip(BuildContext context) {
    final key = row['archived'] == 1
        ? 'archived'
        : row['cancellation_status'] == 'Cancelled'
        ? 'cancelled'
        : 'returned';
    final color = key == 'cancelled'
        ? Theme.of(context).colorScheme.error
        : key == 'archived'
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.primary;
    return Chip(
      label: Text(orderLifecycleLabel(context, key)),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color),
    );
  }

  Widget _revisionChip(BuildContext context) => Chip(
    label: Text(
      '${orderLifecycleLabel(context, 'revision')} #${_invoiceInt(row['revision_no'])}',
    ),
    visualDensity: VisualDensity.compact,
    side: BorderSide.none,
  );

  Widget _actions(BuildContext context, AppLocalizations l10n) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: l10n.viewInvoice,
        onPressed: onViewInvoice,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.receipt_long_outlined),
      ),
      if (row['cancellation_status'] != 'Cancelled' &&
          row['archived'] != 1 &&
          row['has_returns'] != 1)
        IconButton(
          tooltip: l10n.editInvoice,
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined),
        ),
      PopupMenuButton<String>(
        tooltip: orderLifecycleLabel(context, 'status'),
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
              break;
            case 'cancel':
              onCancel();
              break;
            case 'return':
              onReturn();
              break;
            case 'refund':
              onRefund();
              break;
            case 'history':
              onHistory();
              break;
            case 'print':
              onPrint();
              break;
            case 'archive':
            case 'unarchive':
              onArchive();
              break;
          }
        },
        itemBuilder: (context) {
          final active =
              row['cancellation_status'] != 'Cancelled' && row['archived'] != 1;
          final returned = row['has_returns'] == 1;
          final archived = row['archived'] == 1;
          final canEdit = active && !returned;
          final canCancel = canEdit && row['status'] != 'Delivered';
          return [
            if (canEdit)
              PopupMenuItem(value: 'edit', child: Text(l10n.editInvoice)),
            if (canCancel)
              PopupMenuItem(
                value: 'cancel',
                child: Text(orderLifecycleLabel(context, 'cancelOrder')),
              ),
            if (active && row['status'] == 'Delivered')
              PopupMenuItem(
                value: 'return',
                child: Text(orderLifecycleLabel(context, 'returnItems')),
              ),
            if (returned ||
                row['cancellation_status'] == 'Cancelled' ||
                (row['paid'] as num? ?? 0) > 0)
              PopupMenuItem(
                value: 'refund',
                child: Text(orderLifecycleLabel(context, 'refund')),
              ),
            PopupMenuItem(
              value: 'print',
              child: Text(orderLifecycleLabel(context, 'print')),
            ),
            PopupMenuItem(
              value: 'history',
              child: Text(orderLifecycleLabel(context, 'changeHistory')),
            ),
            PopupMenuItem(
              value: archived ? 'unarchive' : 'archive',
              child: Text(
                orderLifecycleLabel(
                  context,
                  archived ? 'unarchive' : 'archive',
                ),
              ),
            ),
          ];
        },
      ),
    ],
  );

  Color _statusColor(BuildContext context, String value) => switch (value) {
    'Ready' || 'Delivered' => Theme.of(context).colorScheme.secondary,
    'Cancelled' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.tertiary,
  };
}

List<(String, int)> _orderGarments(Object? summary) {
  final quantities = <String, int>{};
  for (final part in '${summary ?? ''}'.split('|')) {
    final separator = part.lastIndexOf(':');
    if (separator <= 0) continue;
    final key = part.substring(0, separator);
    final quantity = int.tryParse(part.substring(separator + 1)) ?? 0;
    if (garmentFromKey(key) == null || quantity <= 0) continue;
    quantities.update(
      key,
      (current) => current + quantity,
      ifAbsent: () => quantity,
    );
  }
  return quantities.entries.map((entry) => (entry.key, entry.value)).toList();
}

class _OrderImages extends StatelessWidget {
  const _OrderImages({required this.garments});

  final List<(String, int)> garments;

  @override
  Widget build(BuildContext context) {
    if (garments.isEmpty) {
      return SizedBox(
        height: 48,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(
            Icons.checkroom_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final visible = garments.take(2).toList();
    final extraCount = garments.length - visible.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in visible) ...[
          Tooltip(
            message:
                '${item.$2} × ${localizedGarment(context, garmentFromKey(item.$1)!)}',
            child: _GarmentThumbnail(garmentKey: item.$1, size: 46),
          ),
          if (item != visible.last) const SizedBox(width: 4),
        ],
        if (extraCount > 0) ...[
          const SizedBox(width: 4),
          Text('+$extraCount', style: Theme.of(context).textTheme.labelSmall),
        ],
      ],
    );
  }
}

class _OrderValueCell extends StatelessWidget {
  const _OrderValueCell({
    required this.label,
    required this.value,
    this.ltr = false,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool ltr;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: ltr ? TextDirection.ltr : null,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          color: emphasized ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    ],
  );
}

class _GarmentThumbnail extends StatelessWidget {
  const _GarmentThumbnail({required this.garmentKey, required this.size});

  final String garmentKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final garment = garmentFromKey(garmentKey);
    if (garment == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.checkroom_outlined),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Image.asset(
        garment.imageAsset,
        fit: BoxFit.contain,
        semanticLabel: localizedGarment(context, garment),
      ),
    );
  }
}
