import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';
import '../../reports/order_document_service.dart';

import '../../core/app_date_picker.dart';

import 'package:flutter/services.dart';

import '../../core/formatters.dart';
import '../../core/calendar_service.dart';
import '../../data/shop_database.dart';
import '../../dialogs/order_dialog.dart';
import '../../dialogs/payment_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../models/garment.dart';
import '../../reports/order_payment_receipt_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'delivery_board_logic.dart';

class DeliveryBoardState {
  String dateFilter = 'all';
  String search = '';
  String garment = '';
  String production = 'All';
  int? workerId;
  int upcomingDays = 7;
  bool? boardView;
  double scrollOffset = 0;
  double boardScrollOffset = 0;
}

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({
    super.key,
    required this.database,
    required this.onNavigate,
    this.state,
    this.onStateChanged,
  });

  final ShopDatabase database;
  final void Function(int page, {String? filter}) onNavigate;
  final DeliveryBoardState? state;
  final ValueChanged<DeliveryBoardState>? onStateChanged;

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late final DeliveryBoardState prefs = widget.state ?? DeliveryBoardState();
  List<Map<String, Object?>> rows = [];
  bool loading = true;
  bool failed = false;
  final Set<int> busy = {};
  late final TextEditingController searchController;
  late final ScrollController _scrollController;
  late final ScrollController _boardScrollController;
  List<Map<String, Object?>> workers = [];
  bool refreshing = false;

  void _changed() {
    widget.onStateChanged?.call(prefs);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: prefs.search);
    _scrollController = ScrollController(
      initialScrollOffset: prefs.scrollOffset,
    )..addListener(() => prefs.scrollOffset = _scrollController.offset);
    _boardScrollController =
        ScrollController(initialScrollOffset: prefs.boardScrollOffset)
          ..addListener(
            () => prefs.boardScrollOffset = _boardScrollController.offset,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    prefs.scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : prefs.scrollOffset;
    prefs.boardScrollOffset = _boardScrollController.hasClients
        ? _boardScrollController.offset
        : prefs.boardScrollOffset;
    _scrollController.dispose();
    _boardScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted && rows.isNotEmpty) setState(() => refreshing = true);
    try {
      final result = await widget.database.db.rawQuery('''
        SELECT o.*, c.name AS customer_name, c.phone AS customer_phone,
          c.name AS name, c.phone AS phone,
          (SELECT GROUP_CONCAT(g.garment || ':' || g.quantity, '|')
             FROM (
               SELECT ol.garment, SUM(ol.quantity) AS quantity, MIN(ol.id) AS first_id
               FROM order_lines ol WHERE ol.order_id=o.id
               GROUP BY ol.garment ORDER BY first_id
             ) g) AS garment_summary,
          (SELECT GROUP_CONCAT(DISTINCT wa.worker_id)
             FROM worker_assignments wa
             JOIN order_lines ol ON ol.id=wa.order_line_id
             WHERE ol.order_id=o.id AND wa.status!='Cancelled') AS assigned_worker_ids,
          (SELECT GROUP_CONCAT(DISTINCT w.name)
             FROM worker_assignments wa
             JOIN workers w ON w.id=wa.worker_id
             JOIN order_lines ol ON ol.id=wa.order_line_id
             WHERE ol.order_id=o.id AND wa.status!='Cancelled') AS assigned_worker_names,
          COALESCE(
            NULLIF(TRIM(o.notes),''),
            (SELECT NULLIF(TRIM(ol.notes),'') FROM order_lines ol
             WHERE ol.order_id=o.id AND TRIM(COALESCE(ol.notes,''))!=''
             ORDER BY ol.id LIMIT 1)
          ) AS instruction,
          (SELECT h.changed_at FROM order_status_history h
             WHERE h.order_id=o.id AND h.status='Ready'
             ORDER BY h.changed_at DESC, h.id DESC LIMIT 1) AS ready_at
        FROM orders o JOIN customers c ON c.id=o.customer_id
        WHERE o.status IN ('Received','Cutting','Stitching','Ready')
        ORDER BY o.id DESC
      ''');
      final workerRows = await widget.database.db.rawQuery('''
        SELECT DISTINCT w.id, w.name
        FROM workers w
        JOIN worker_assignments wa ON wa.worker_id=w.id
        JOIN order_lines ol ON ol.id=wa.order_line_id
        JOIN orders o ON o.id=ol.order_id
        WHERE o.status IN ('Received','Cutting','Stitching','Ready')
          AND wa.status!='Cancelled'
        ORDER BY LOWER(w.name), w.id
      ''');
      if (!mounted) return;
      setState(() {
        rows = result;
        workers = workerRows;
        loading = false;
        refreshing = false;
        failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
        failed = true;
      });
    }
  }

  List<Map<String, Object?>> get filtered {
    final now = CalendarService.shopToday();
    return DeliveryBoardLogic.sort(
      rows.where(
        (order) => DeliveryBoardLogic.matches(
          order: order,
          dateFilter: prefs.dateFilter,
          search: prefs.search,
          garmentFilter: prefs.garment,
          productionFilter: prefs.production,
          workerIdFilter: prefs.workerId,
          today: now,
          upcomingDays: prefs.upcomingDays,
        ),
      ),
      now,
      dateFilter: prefs.dateFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final strings = _Copy(Localizations.localeOf(context).languageCode);
    return CommandScope(commands: _keyboardCommands(), builder: (context) => LayoutBuilder(
      builder: (context, constraints) {
        final useBoard = prefs.boardView ?? constraints.maxWidth >= 1050;
        final counts = DeliveryBoardLogic.counts(
          rows,
          CalendarService.shopToday(),
          upcomingDays: prefs.upcomingDays,
        );

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.deliveryBoard,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strings.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${strings.today}: ${formatDate(CalendarService.shopToday().toIso8601String(), locale: locale)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: l10n.refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 8),
                  if (constraints.maxWidth < 560)
                    IconButton.filled(
                      onPressed: _newOrder,
                      tooltip: l10n.newOrder,
                      icon: const Icon(Icons.add),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _newOrder,
                      icon: const Icon(Icons.add),
                      label: Text(l10n.newOrder),
                    ),
                ],
              ),
              if (refreshing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              if (failed) ...[
                const SizedBox(height: 10),
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.errorGeneric,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                        TextButton(onPressed: _load, child: Text(l10n.retry)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _summaryCards(counts, strings),
              const SizedBox(height: 6),
              Text(
                strings.overlapNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _filters(strings, useBoard),
              const SizedBox(height: 12),
              if (loading && rows.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (failed && rows.isEmpty)
                Center(
                  child: Column(
                    children: [
                      Text(l10n.errorGeneric),
                      TextButton(onPressed: _load, child: Text(l10n.retry)),
                    ],
                  ),
                )
              else if (filtered.isEmpty)
                _empty(strings)
              else if (useBoard)
                _board(
                  filtered,
                  locale,
                  strings,
                  height: (constraints.maxHeight - 350)
                      .clamp(320.0, 600.0)
                      .toDouble(),
                )
              else
                ...filtered.map((row) => _orderCard(row, locale, strings)),
            ],
          ),
        );
      },
    ));
  }

  List<AppCommand> _keyboardCommands() => [
    AppCommand('orders.add', _newOrder, aliases: [CommandKey.add]),
    AppCommand(CommandKey.search, () => focusCommandSearch(searchController)),
    AppCommand(CommandKey.refresh, _load),
    AppCommand('order.deliver', () => withCommandRecord(context, 'order', rows,
      (row) => _deliver(row, _Copy(Localizations.localeOf(context).languageCode)),
      eligible: (row) => row['status'] == 'Ready' && row['cancellation_status'] != 'Cancelled')),
    AppCommand('orders.print', () => withCommandRecord(context, 'order', rows, (row) => previewOrderDocument(context, widget.database, row['id'] as int, kind: OrderDocumentKind.customerBill, locale: Localizations.localeOf(context).toLanguageTag())), aliases: [CommandKey.print]),
    AppCommand('orders.printBoth', () => withCommandRecord(context, 'order', rows, (row) => showSavedOrderPrintOptions(context, widget.database, row['id'] as int, locale: Localizations.localeOf(context).toLanguageTag(), focusPrintBoth: true)), aliases: [CommandKey.printBoth]),
    AppCommand('orders.measurementPrint', () => withCommandRecord(context, 'order', rows, _printWorkTicket)),
  ];

  Widget _summaryCards(DeliveryCounts counts, _Copy strings) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = <(String, int, IconData, Color)>[
        (
          'today',
          counts.dueToday,
          Icons.today,
          Theme.of(context).colorScheme.primary,
        ),
        (
          'overdue',
          counts.overdue,
          Icons.warning_amber_rounded,
          Theme.of(context).colorScheme.error,
        ),
        (
          'ready',
          counts.ready,
          Icons.check_circle_outline,
          Theme.of(context).colorScheme.secondary,
        ),
        (
          'upcoming',
          counts.upcoming,
          Icons.upcoming_outlined,
          Theme.of(context).colorScheme.tertiary,
        ),
      ];
      final columns = constraints.maxWidth < 600 ? 2 : 4;
      const spacing = 10.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final cardHeight =
          76 + ((textScale - 1) * 42).clamp(0.0, 36.0).toDouble();
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final card in cards)
            SizedBox(
              width: width,
              height: cardHeight,
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: prefs.dateFilter == card.$1
                    ? card.$4.withValues(alpha: .08)
                    : Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: prefs.dateFilter == card.$1
                        ? card.$4
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    prefs.dateFilter = card.$1;
                    _changed();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Row(
                      children: [
                        Icon(card.$3, color: card.$4, size: 21),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                strings.filter(card.$1),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                card.$2.toString(),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: card.$4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
  Widget _filters(_Copy strings, bool useBoard) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 270,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: strings.search,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                prefs.search = value;
                _changed();
              },
              controller: searchController,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButton<String>(
              isExpanded: true,
              value: prefs.dateFilter,
              items:
                  [
                        'all',
                        'today',
                        'overdue',
                        'ready',
                        'upcoming',
                        'unscheduled',
                      ]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(
                            strings.filter(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  prefs.dateFilter = value;
                  _changed();
                }
              },
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButton<String>(
              isExpanded: true,
              value: prefs.garment,
              items: ['', 'shalwar', 'waistcoat', 'coat']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value.isEmpty ? strings.allGarments : _garment(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                prefs.garment = value ?? '';
                _changed();
              },
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButton<String>(
              isExpanded: true,
              value: prefs.production,
              items: ['All', 'Received', 'Cutting', 'Stitching', 'Ready']
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        value == 'All' ? strings.allStatuses : _status(value),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                prefs.production = value ?? 'All';
                _changed();
              },
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButton<int?>(
              isExpanded: true,
              value: workers.any((worker) => worker['id'] == prefs.workerId)
                  ? prefs.workerId
                  : null,
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    strings.allWorkers,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final worker in workers)
                  DropdownMenuItem<int?>(
                    value: worker['id'] as int,
                    child: Text(
                      worker['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                prefs.workerId = value;
                _changed();
              },
            ),
          ),
          SizedBox(
            width: 175,
            child: DropdownButton<int>(
              isExpanded: true,
              value: prefs.upcomingDays,
              items: [7, 14, 30]
                  .map(
                    (days) => DropdownMenuItem(
                      value: days,
                      child: Text(
                        strings.nextDays(days),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                prefs.upcomingDays = value ?? 7;
                _changed();
              },
            ),
          ),
          SizedBox(
            width: 270,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: Text(
                    strings.list,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.view_kanban_outlined),
                  label: Text(
                    strings.board,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              selected: {useBoard},
              onSelectionChanged: (selection) {
                prefs.boardView = selection.first;
                _changed();
              },
            ),
          ),
          Text(
            strings.results(filtered.length),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          TextButton(
            onPressed: () {
              prefs.dateFilter = 'all';
              prefs.search = '';
              searchController.clear();
              prefs.garment = '';
              prefs.production = 'All';
              prefs.workerId = null;
              prefs.upcomingDays = 7;
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
              if (_boardScrollController.hasClients) {
                _boardScrollController.jumpTo(0);
              }
              _changed();
            },
            child: Text(strings.clear),
          ),
        ],
      ),
    ),
  );

  Widget _board(
    List<Map<String, Object?>> orders,
    String locale,
    _Copy strings, {
    required double height,
  }) {
    const statuses = ['Received', 'Cutting', 'Stitching', 'Ready'];
    const columnWidth = 342.0;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      child: Scrollbar(
        controller: _boardScrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _boardScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final status in statuses)
                SizedBox(
                  width: columnWidth,
                  child: Card(
                    elevation: 0,
                    margin: const EdgeInsetsDirectional.only(
                      end: 10,
                      bottom: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _DeliveryColumnHeader(
                          title: _status(status),
                          count: orders
                              .where((row) => row['status'] == status)
                              .length,
                          color: _statusColor(status),
                          icon: _statusIcon(status),
                        ),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final columnOrders = orders
                                  .where((row) => row['status'] == status)
                                  .toList();
                              if (columnOrders.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.checklist_rtl_outlined,
                                          color: colors.outline,
                                          size: 28,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          strings.emptyColumn,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: columnOrders.length,
                                itemBuilder: (context, index) => _orderCard(
                                  columnOrders[index],
                                  locale,
                                  strings,
                                  compact: true,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderCard(
    Map<String, Object?> row,
    String locale,
    _Copy strings, {
    bool compact = false,
  }) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final due = DeliveryBoardLogic.daysFromToday(
      row['due_date'],
      CalendarService.shopToday(),
    );
    final dueDate = DeliveryBoardLogic.dateOf(row['due_date']);
    final status = row['status'].toString();
    final total = (row['total'] as num?)?.toInt() ?? 0;
    final paid = (row['paid'] as num?)?.toInt() ?? 0;
    final remaining = math.max(0, total - paid).toInt();
    final name = row['customer_name']?.toString() ?? '';
    final phone = row['customer_phone']?.toString() ?? '';
    final orderId = row['id'] as int;
    final garments = _parseGarments(row['garment_summary']);

    return CommandRecordTarget(kind: 'order', record: row, child: Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (row['bill_number'] as String?)?.trim().isNotEmpty ==
                                true
                            ? row['bill_number'].toString()
                            : l10n.billNotAssigned,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.orderReference(
                          row['number']?.toString() ?? '—',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_OrderMenuAction>(
                  tooltip: strings.moreActions,
                  onSelected: (action) =>
                      _handleMoreAction(action, row, strings),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _OrderMenuAction.receivePayment,
                      child: _menuItem(
                        Icons.payments_outlined,
                        strings.receivePayment,
                      ),
                    ),
                    PopupMenuItem(
                      value: _OrderMenuAction.changeDate,
                      child: _menuItem(
                        Icons.event_outlined,
                        strings.changeDate,
                      ),
                    ),
                    PopupMenuItem(
                      value: _OrderMenuAction.printWorkTicket,
                      child: _menuItem(
                        Icons.content_cut_outlined,
                        strings.printWorkTicket,
                      ),
                    ),
                    PopupMenuItem(
                      value: _OrderMenuAction.printReceipt,
                      child: _menuItem(
                        Icons.receipt_long_outlined,
                        strings.printReceipt,
                      ),
                    ),
                    PopupMenuItem(
                      value: _OrderMenuAction.printInvoice,
                      child: _menuItem(
                        Icons.print_outlined,
                        strings.printInvoice,
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
                _pill(_status(status), _statusColor(status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (phone.trim().isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      phone,
                      textDirection: TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: strings.copyPhone,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _copyPhone(phone, strings),
                    icon: const Icon(Icons.copy, size: 17),
                  ),
                ],
              ),
            const SizedBox(height: 3),
            _DeliveryGarmentList(garments: garments, strings: strings),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(9, 7, 9, 7),
              decoration: BoxDecoration(
                color: (due != null && due < 0 ? colors.error : colors.primary)
                    .withValues(alpha: .07),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 17,
                    color: due != null && due < 0
                        ? colors.error
                        : colors.primary,
                  ),
                  Text(
                    _dueText(due, row, strings),
                    style: TextStyle(
                      color: due != null && due < 0
                          ? colors.error
                          : colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dueDate == null
                        ? strings.unscheduled
                        : formatDate(dueDate.toIso8601String(), locale: locale),
                    textDirection: dueDate == null ? null : TextDirection.ltr,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DeliveryPaymentSummary(
              total: total,
              paid: paid,
              remaining: remaining,
              locale: locale,
              strings: strings,
            ),
            if ((row['assigned_worker_names'] as String?)?.trim().isNotEmpty ==
                true)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.person_outline, size: 17),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${strings.assignedWorker}: ${row['assigned_worker_names']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if ((row['instruction'] as String?)?.trim().isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined, size: 17),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        row['instruction'].toString().trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            if (status == 'Ready' && row['ready_at'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  _readyText(row['ready_at'], strings),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openDetails(row),
                  icon: const Icon(Icons.open_in_new, size: 17),
                  label: Text(strings.viewDetails),
                ),
                FilledButton.icon(
                  onPressed: busy.contains(orderId)
                      ? null
                      : status == 'Ready'
                      ? () => _deliver(row, strings)
                      : () => _advance(row, strings),
                  icon: busy.contains(orderId)
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          status == 'Ready'
                              ? Icons.local_shipping_outlined
                              : Icons.arrow_forward,
                          size: 18,
                        ),
                  label: Text(
                    status == 'Ready'
                        ? strings.deliver
                        : _action(status, strings),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }

  Widget _menuItem(IconData icon, String label) => Row(
    children: [
      Icon(icon, size: 19),
      const SizedBox(width: 10),
      Flexible(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Future<void> _handleMoreAction(
    _OrderMenuAction action,
    Map<String, Object?> row,
    _Copy strings,
  ) async {
    switch (action) {
      case _OrderMenuAction.receivePayment:
        await showPaymentDialog(context, widget.database, order: row);
        await _load();
        break;
      case _OrderMenuAction.changeDate:
        await _reschedule(row, strings);
        break;
      case _OrderMenuAction.printWorkTicket:
        await _printWorkTicket(row);
        break;
      case _OrderMenuAction.printReceipt:
        await _printReceipt(row, strings);
        break;
      case _OrderMenuAction.printInvoice:
        await _printInvoice(row);
        break;
    }
  }

  void _openDetails(Map<String, Object?> row) {
    widget.onNavigate(2, filter: 'order:${row['number']}');
  }

  Future<void> _printInvoice(Map<String, Object?> row) async {
    await showSavedOrderPrintOptions(
      context,
      widget.database,
      row['id'] as int,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
  }

  Future<void> _printWorkTicket(Map<String, Object?> row) async {
    await showSavedOrderPrintOptions(
      context,
      widget.database,
      row['id'] as int,
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
  }

  Future<void> _printReceipt(Map<String, Object?> row, _Copy strings) async {
    try {
      final printed = await printLatestOrderPaymentReceipt(
        widget.database,
        row,
        locale: Localizations.localeOf(context).toLanguageTag(),
      );
      if (!mounted) return;
      final message = printed == null
          ? strings.noSavedReceipt
          : printed
          ? null
          : strings.printingUnavailable;
      if (message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.actionFailed)));
      }
    }
  }

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    ),
  );

  Widget _empty(_Copy strings) => Padding(
    padding: const EdgeInsets.all(48),
    child: Column(
      children: [
        const Icon(Icons.event_available_outlined, size: 42),
        const SizedBox(height: 10),
        Text(
          strings.emptyState,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        TextButton(
          onPressed: () {
            prefs.dateFilter = 'all';
            prefs.search = '';
            searchController.clear();
            prefs.garment = '';
            prefs.production = 'All';
            prefs.workerId = null;
            prefs.upcomingDays = 7;
            _changed();
          },
          child: Text(strings.clear),
        ),
      ],
    ),
  );

  Future<void> _newOrder() async {
    final customer = await showOrderCustomerPicker(context, widget.database);
    if (customer == null || !mounted) return;
    await showOrderDialog(context, widget.database, customer);
    await _load();
  }

  Future<void> _advance(Map<String, Object?> row, _Copy strings) async {
    final id = row['id'] as int;
    if (!busy.add(id)) return;
    setState(() {});
    try {
      final next = DeliveryBoardLogic.nextStatus(row['status'] as String?);
      if (next != null) {
        await widget.database.updateOrderStatus(id, next);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.updated)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.actionFailed)));
      }
    } finally {
      busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deliver(Map<String, Object?> row, _Copy strings) async {
    final id = row['id'] as int;
    if (!busy.add(id)) return;
    setState(() {});
    try {
      final fresh = (await widget.database.db.rawQuery(
        '''SELECT o.*, c.name AS customer_name, c.phone AS customer_phone,
                  c.name AS name, c.phone AS phone
           FROM orders o JOIN customers c ON c.id=o.customer_id
           WHERE o.id=?''',
        [id],
      )).firstOrNull;
      if (!mounted || fresh == null) return;
      if (fresh['status'] != 'Ready') {
        await _load();
        return;
      }
      final lines = await widget.database.db.query(
        'order_lines',
        where: 'order_id=?',
        whereArgs: [id],
        orderBy: 'id ASC',
      );
      if (!mounted) return;
      final garments = <_GarmentQuantity>[];
      for (final line in lines) {
        final key = line['garment']?.toString() ?? '';
        final quantity = (line['quantity'] as num?)?.toInt() ?? 0;
        if (key.isNotEmpty && quantity > 0) {
          garments.add(_GarmentQuantity(key, quantity));
        }
      }
      final total = (fresh['total'] as num?)?.toInt() ?? 0;
      final paid = (fresh['paid'] as num?)?.toInt() ?? 0;
      final balance = math.max(0, total - paid).toInt();
      final locale = Localizations.localeOf(context).toLanguageTag();
      final dueDate = DeliveryBoardLogic.dateOf(fresh['due_date']);
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.confirmDelivery),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fresh['customer_name']?.toString() ?? '',
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.billReference(
                      fresh['bill_number']?.toString() ??
                          fresh['number']?.toString() ??
                          '—',
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    strings.orderReference(fresh['number']?.toString() ?? '—'),
                    textDirection: TextDirection.ltr,
                  ),
                  const SizedBox(height: 10),
                  _DeliveryGarmentList(garments: garments, strings: strings),
                  const SizedBox(height: 10),
                  Text(
                    '${strings.deliveryDate}: ${dueDate == null ? strings.unscheduled : formatDate(dueDate.toIso8601String(), locale: locale)}',
                  ),
                  const Divider(height: 22),
                  _DeliveryPaymentSummary(
                    total: total,
                    paid: paid,
                    remaining: balance,
                    locale: locale,
                    strings: strings,
                  ),
                  if (balance > 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        strings.outstandingAmount(
                          formatMoney(balance, locale: locale),
                        ),
                        style: TextStyle(
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            if (balance > 0)
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext, 'pay'),
                child: Text(strings.receivePayment),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'deliver'),
              child: Text(
                balance > 0 ? strings.deliverOutstanding : strings.deliver,
              ),
            ),
          ],
        ),
      );
      if (choice == 'pay') {
        if (!mounted) return;
        await showPaymentDialog(context, widget.database, order: fresh);
        await _load();
        return;
      }
      if (choice != 'deliver') return;

      final currentStatus = await widget.database.db.query(
        'orders',
        columns: ['status'],
        where: 'id=?',
        whereArgs: [id],
        limit: 1,
      );
      if (currentStatus.isEmpty || currentStatus.single['status'] != 'Ready') {
        await _load();
        return;
      }
      await widget.database.updateOrderStatus(
        id,
        'Delivered',
        note: balance > 0
            ? strings.deliveredWithBalance(formatMoney(balance, locale: locale))
            : strings.delivered,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.delivered)));
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.actionFailed)));
      }
    } finally {
      busy.remove(id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _reschedule(Map<String, Object?> row, _Copy strings) async {
    final current = DeliveryBoardLogic.dateOf(row['due_date']);
    DateTime? date = current;
    final reason = TextEditingController();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(strings.changeDate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${strings.currentDate}: ${current == null ? '—' : formatDate(current.toIso8601String(), locale: locale)}',
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showAppDatePicker(
                    context: context,
                    initialDate: date ?? CalendarService.shopToday(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setDialog(() => date = picked);
                },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  date == null
                      ? strings.newDate
                      : formatDate(date!.toIso8601String(), locale: locale),
                ),
              ),
              TextField(
                controller: reason,
                decoration: InputDecoration(labelText: strings.reason),
                maxLines: 2,
              ),
              if (date != null &&
                  DeliveryBoardLogic.day(date!).isBefore(
                    DeliveryBoardLogic.day(CalendarService.shopToday()),
                  ))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    strings.pastWarning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                MaterialLocalizations.of(dialogContext).cancelButtonLabel,
              ),
            ),
            FilledButton(
              onPressed: date == null
                  ? null
                  : () => Navigator.pop(dialogContext, date),
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
    if (selected == null) {
      reason.dispose();
      return;
    }
    try {
      await widget.database.rescheduleOrder(
        orderId: row['id'] as int,
        dueDate: selected,
        reason: reason.text,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.rescheduled)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.actionFailed)));
      }
    } finally {
      reason.dispose();
    }
  }

  Future<void> _copyPhone(String phone, _Copy strings) async {
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.copied)));
    }
  }

  String _dueText(int? due, Map<String, Object?> row, _Copy strings) =>
      due == null
      ? strings.unscheduled
      : due < 0
      ? strings.overdueDays(-due)
      : due == 0
      ? strings.dueToday
      : due == 1
      ? strings.tomorrow
      : strings.dueDays(due);

  String _readyText(Object? value, _Copy strings) {
    final parsed = DeliveryBoardLogic.dateOf(value);
    if (parsed == null) return '';
    final days = DeliveryBoardLogic.day(CalendarService.shopToday())
        .difference(DeliveryBoardLogic.day(parsed))
        .inDays;
    return days <= 0 ? strings.readyToday : strings.readyDays(days);
  }

  String _garment(String key) => localizedGarmentKey(context, key);

  String _status(String value) => switch (value) {
    'Received' => context.l10n.received,
    'Cutting' => context.l10n.cutting,
    'Stitching' => context.l10n.stitching,
    'Ready' => context.l10n.ready,
    _ => value,
  };

  String _action(String status, _Copy strings) => switch (status) {
    'Received' => strings.startCutting,
    'Cutting' => strings.startStitching,
    _ => strings.markReady,
  };

  Color _statusColor(String status) => switch (status) {
    'Received' => Theme.of(context).colorScheme.primary,
    'Cutting' => Theme.of(context).colorScheme.tertiary,
    'Stitching' => Theme.of(context).colorScheme.secondary,
    'Ready' => Theme.of(context).colorScheme.secondary,
    _ => Theme.of(context).colorScheme.primary,
  };

  IconData _statusIcon(String status) => switch (status) {
    'Received' => Icons.inbox_outlined,
    'Cutting' => Icons.content_cut_outlined,
    'Stitching' => Icons.checkroom_outlined,
    'Ready' => Icons.task_alt_outlined,
    _ => Icons.circle_outlined,
  };
}

enum _OrderMenuAction {
  receivePayment,
  changeDate,
  printWorkTicket,
  printReceipt,
  printInvoice,
}

class _GarmentQuantity {
  const _GarmentQuantity(this.key, this.quantity);

  final String key;
  final int quantity;

  Garment get garment => switch (key) {
    'shalwar' => Garment.shalwar,
    'waistcoat' => Garment.waistcoat,
    'coat' => Garment.coat,
    _ => Garment.shalwar,
  };
}

List<_GarmentQuantity> _parseGarments(Object? summary) {
  final garments = <_GarmentQuantity>[];
  for (final part in (summary?.toString() ?? '').split('|')) {
    final separator = part.lastIndexOf(':');
    if (separator <= 0) continue;
    final key = part.substring(0, separator).trim();
    final quantity = int.tryParse(part.substring(separator + 1).trim());
    if (key.isNotEmpty && quantity != null && quantity > 0) {
      garments.add(_GarmentQuantity(key, quantity));
    }
  }
  return garments;
}

class _DeliveryColumnHeader extends StatelessWidget {
  const _DeliveryColumnHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsetsDirectional.fromSTEB(12, 11, 12, 11),
    color: color.withValues(alpha: .09),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            count.toString(),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _DeliveryGarmentList extends StatefulWidget {
  const _DeliveryGarmentList({required this.garments, required this.strings});

  final List<_GarmentQuantity> garments;
  final _Copy strings;

  @override
  State<_DeliveryGarmentList> createState() => _DeliveryGarmentListState();
}

class _DeliveryGarmentListState extends State<_DeliveryGarmentList> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.garments.isEmpty) {
      return Text(
        widget.strings.noGarments,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final visibleCount = expanded
        ? widget.garments.length
        : math.min(2, widget.garments.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in widget.garments.take(visibleCount))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                _DeliveryGarmentThumbnail(garment: item.garment, size: 68),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    localizedGarment(context, item.garment),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '× ${item.quantity}',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        if (widget.garments.length > 2)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(
                expanded
                    ? widget.strings.showFewerGarments
                    : widget.strings.moreGarments(widget.garments.length - 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeliveryGarmentThumbnail extends StatelessWidget {
  const _DeliveryGarmentThumbnail({required this.garment, this.size = 68});

  final Garment garment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.of(context).devicePixelRatio;
    return Semantics(
      image: true,
      label: localizedGarment(context, garment),
      child: Tooltip(
        message: localizedGarment(context, garment),
        child: Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: .55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Image.asset(
            garment.imageAsset,
            fit: BoxFit.contain,
            cacheWidth: (size * ratio).round(),
            cacheHeight: (size * ratio).round(),
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                garment.icon,
                size: 34,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryPaymentSummary extends StatelessWidget {
  const _DeliveryPaymentSummary({
    required this.total,
    required this.paid,
    required this.remaining,
    required this.locale,
    required this.strings,
  });

  final int total;
  final int paid;
  final int remaining;
  final String locale;
  final _Copy strings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _amountCell(context, strings.total, total, colors.onSurface),
        const SizedBox(width: 8),
        _amountCell(context, strings.paid, paid, colors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                remaining == 0 ? strings.paidInFull : strings.remaining,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: remaining == 0 ? colors.secondary : colors.error,
                ),
              ),
              if (remaining > 0)
                Text(
                  formatMoney(remaining, locale: locale),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountCell(
    BuildContext context,
    String label,
    int amount,
    Color color,
  ) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Text(
          formatMoney(amount, locale: locale),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _Copy {
  _Copy(String language) : ps = language == 'ps', fa = language == 'fa';

  final bool ps;
  final bool fa;

  String _text(String english, String dari, String pashto) => ps
      ? pashto
      : fa
      ? dari
      : english;

  String get description => _text(
    'Track upcoming deliveries and orders ready for collection.',
    'سفارش‌های نزدیک و آمادهٔ تحویل را پیگیری کنید.',
    'نږدې سپارښتنې او د سپارلو لپاره چمتو فرمایشونه وڅارئ.',
  );
  String get today => _text('Today', 'امروز', 'نن');
  String get overlapNote => _text(
    'Counts can overlap; each summary card counts orders independently.',
    'شمارش‌ها هم‌پوشانی دارند؛ هر کارت سفارش‌ها را جداگانه می‌شمارد.',
    'دا شمېرې یو له بل سره تکرارېدای شي؛ هر کارت سپارښتنې جلا شمېري.',
  );
  String get search => _text(
    'Search customer, mobile, bill, or order number',
    'جستجوی مشتری، موبایل، شمارهٔ بل یا سفارش',
    'پېرودونکی، موبایل، د بل یا فرمایش شمېره ولټوئ',
  );
  String filter(String key) => switch (key) {
    'today' => _text('Due today', 'تحویل امروز', 'نن سپارل'),
    'overdue' => _text('Overdue', 'دیرشده', 'له وخته تېره'),
    'ready' => _text(
      'Ready for collection',
      'آمادهٔ دریافت',
      'د اخیستلو لپاره چمتو',
    ),
    'upcoming' => _text('Upcoming', 'روزهای آینده', 'راتلونکې'),
    'unscheduled' => _text('Unscheduled', 'بدون تاریخ', 'نېټه نه ده ټاکل شوې'),
    _ => _text('All active', 'همهٔ فعال', 'ټولې فعالې'),
  };
  String get allGarments => _text('All garments', 'همهٔ لباس‌ها', 'ټولې جامې');
  String get allStatuses => _text('All stages', 'همهٔ مرحله‌ها', 'ټول پړاوونه');
  String get allWorkers =>
      _text('All workers', 'همهٔ کارمندان', 'ټول کارکوونکي');
  String nextDays(int days) =>
      _text('Next $days days', '$days روز آینده', 'راتلونکې $days ورځې');
  String get list => _text('List', 'فهرست', 'لېست');
  String get board => _text('Board', 'تخته', 'تخته');
  String get clear =>
      _text('Clear filters', 'پاک‌کردن فیلترها', 'فلټرونه پاک کړئ');
  String results(int count) =>
      _text('$count results', 'نتیجه: $count', 'پایلې: $count');
  String orderReference(String number) =>
      _text('Order $number', 'سفارش $number', 'فرمایش $number');
  String billReference(String number) =>
      _text('Bill $number', 'بل $number', 'بل $number');
  String get moreActions => _text('More actions', 'کارهای بیشتر', 'نورې کړنې');
  String get receivePayment =>
      _text('Receive payment', 'دریافت پرداخت', 'پیسې ترلاسه کړئ');
  String get changeDate => _text(
    'Change delivery date',
    'تغییر تاریخ تحویل',
    'د سپارلو نېټه بدله کړئ',
  );
  String get printInvoice => _text('Print invoice', 'چاپ بل', 'بل چاپ کړئ');
  String get printWorkTicket =>
      _text('Print work ticket', 'چاپ برگهٔ کار', 'کاري پاڼه چاپ کړئ');
  String get printReceipt => _text('Print receipt', 'چاپ رسید', 'رسید چاپ کړئ');
  String get noSavedReceipt => _text(
    'No saved payment receipt is linked to this order.',
    'برای این سفارش رسید پرداخت ذخیره‌شده‌ای نیست.',
    'له دې فرمایش سره د تادیې خوندي رسید نشته.',
  );
  String get copyPhone => _text(
    'Copy phone number',
    'کپی شمارهٔ موبایل',
    'د موبایل شمېره کاپي کړئ',
  );
  String get copied => _text(
    'Phone number copied.',
    'شمارهٔ موبایل کپی شد.',
    'د موبایل شمېره کاپي شوه.',
  );
  String get viewDetails =>
      _text('View details', 'دیدن جزئیات', 'جزییات وګورئ');
  String get emptyColumn => _text(
    'No active orders in this stage.',
    'در این مرحله سفارش فعالی نیست.',
    'په دې پړاو کې فعاله سپارښتنه نشته.',
  );
  String get noGarments => _text(
    'No garment details',
    'جزئیات لباس موجود نیست',
    'د جامو جزئیات نشته',
  );
  String get showFewerGarments =>
      _text('Show fewer', 'کمتر نشان بده', 'لږ وښایئ');
  String moreGarments(int count) =>
      _text('Show $count more', 'نمایش $count مورد دیگر', '$count نور وښایئ');
  String get assignedWorker => _text('Worker', 'کارمند', 'کارکوونکی');
  String get deliver => _text('Deliver', 'تحویل', 'وسپارئ');
  String get unscheduled =>
      _text('Unscheduled', 'بدون تاریخ', 'نېټه نه ده ټاکل شوې');
  String get dueToday => _text('Due today', 'تحویل امروز', 'نن سپارل');
  String get tomorrow => _text('Due tomorrow', 'تحویل فردا', 'سبا سپارل');
  String dueDays(int days) => _text(
    'Due in $days days',
    'تحویل تا $days روز دیگر',
    'په $days ورځو کې سپارل',
  );
  String overdueDays(int days) =>
      _text('$days days overdue', '$days روز تأخیر', '$days ورځې ځنډېدلې');
  String get readyToday =>
      _text('Ready today', 'امروز آماده شد', 'نن چمتو شوه');
  String readyDays(int days) => _text(
    'Ready $days days ago',
    '$days روز پیش آماده شد',
    '$days ورځې مخکې چمتو شوه',
  );
  String get startCutting =>
      _text('Start cutting', 'شروع برش', 'پرې کول پیل کړئ');
  String get startStitching =>
      _text('Start stitching', 'شروع دوخت', 'ګنډل پیل کړئ');
  String get markReady =>
      _text('Mark ready', 'علامت‌گذاری آماده', 'چمتو وټاکئ');
  String get confirmDelivery =>
      _text('Confirm delivery', 'تأیید تحویل', 'د سپارلو تایید');
  String get deliverOutstanding => _text(
    'Confirm delivery on credit',
    'تأیید تحویل با بدهی',
    'د پاتې پور سره سپارل تایید کړئ',
  );
  String get outstandingWarning => _text(
    'Outstanding amount: {amount}. Delivering on credit keeps the debt on the customer ledger.',
    'مبلغ باقی‌مانده: {amount}. تحویل نسیه، بدهی را در حساب مشتری نگه می‌دارد.',
    'پاتې پیسې: {amount}. په پور سپارل به پور د پېرودونکي په حساب کې وساتي.',
  );
  String outstandingAmount(String amount) =>
      outstandingWarning.replaceAll('{amount}', amount);
  String deliveredWithBalance(String amount) => _text(
    'Delivered with balance $amount AFN',
    'تحویل با ماندهٔ $amount افغانی',
    'د $amount افغانیو پاتې پور سره وسپارل شو',
  );
  String get deliveryDate =>
      _text('Delivery date', 'تاریخ تحویل', 'د سپارلو نېټه');
  String get currentDate => _text('Current date', 'تاریخ فعلی', 'اوسنۍ نېټه');
  String get newDate => _text('New date', 'تاریخ جدید', 'نوې نېټه');
  String get reason =>
      _text('Reason (optional)', 'دلیل (اختیاری)', 'لامل (اختیاري)');
  String get pastWarning => _text(
    'This date is in the past; the order will show as overdue.',
    'این تاریخ گذشته است؛ سفارش دیرشده نمایش داده می‌شود.',
    'دا نېټه تېره ده؛ سپارښتنه به ځنډېدلې وښودل شي.',
  );
  String get save => _text('Save', 'ذخیره', 'وساتئ');
  String get updated => _text(
    'Order stage updated.',
    'مرحلهٔ سفارش به‌روز شد.',
    'د سپارښتنې پړاو تازه شو.',
  );
  String get delivered =>
      _text('Order delivered.', 'سفارش تحویل شد.', 'سپارښتنه وسپارل شوه.');
  String get rescheduled => _text(
    'Delivery date updated.',
    'تاریخ تحویل به‌روز شد.',
    'د سپارلو نېټه تازه شوه.',
  );
  String get total => _text('Total', 'مجموع', 'ټول');
  String get paid => _text('Paid', 'پرداخت‌شده', 'ورکړل شوي');
  String get remaining => _text('Remaining', 'باقی‌مانده', 'پاتې');
  String get paidInFull =>
      _text('Paid in full', 'کامل پرداخت شده', 'بشپړ ورکړل شوی');
  String get actionFailed => _text(
    'The action could not be completed. Please try again.',
    'این کار انجام نشد. دوباره تلاش کنید.',
    'کړنه بشپړه نه شوه. بیا هڅه وکړئ.',
  );
  String get printingUnavailable => _text(
    'Printing is available on Windows.',
    'چاپ در ویندوز در دسترس است.',
    'چاپ په وینډوز کې شونی دی.',
  );
  String get emptyState => _text(
    'No active orders match these filters.',
    'هیچ سفارش فعالی با این فیلترها پیدا نشد.',
    'له دغو فلټرونو سره فعاله سپارښتنه ونه موندل شوه.',
  );
}
