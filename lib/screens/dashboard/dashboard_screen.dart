import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';

import '../../widgets/responsive_layout.dart';

import '../../core/formatters.dart';
import '../../core/phone.dart';
import '../../data/shop_database.dart';
import '../../core/calendar_service.dart';
import '../../dialogs/customer_dialog.dart';
import '../../dialogs/order_dialog.dart';
import '../../dialogs/payment_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../customers/customer_profile_screen.dart';
import 'dashboard_data_provider.dart';
import 'dashboard_strings.dart';
import 'widgets/customer_search_section.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_summary_card.dart';
import 'widgets/orders_attention_section.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/upcoming_deliveries_section.dart';
import 'widgets/sell_fabric_dialog.dart';

Future<Map<String, Object?>?> showOrderCustomerPicker(
  BuildContext context,
  ShopDatabase database,
) => showDialog<Map<String, Object?>>(
  context: context,
  builder: (_) => _CustomerPickerDialog(database: database),
);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.database,
    required this.shopName,
    required this.onSearch,
    required this.onNavigate,
    this.deliveryOnly = false,
  });

  final ShopDatabase database;
  final String shopName;
  final ValueChanged<String> onSearch;
  final void Function(int page, {String? filter}) onNavigate;
  final bool deliveryOnly;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> future;
  late Future<Map<String, Object?>> profileFuture;
  late Future<DashboardStrings> stringsFuture;
  bool actionBusy = false;
  final _searchFocus = FocusNode();

  @override
  void dispose() { _searchFocus.dispose(); super.dispose(); }

  @override
  void initState() {
    super.initState();
    future = DashboardDataProvider(widget.database).load();
    profileFuture = widget.database.settings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    stringsFuture = Future.value(DashboardStrings.of(context));
  }

  Future<void> _reload() async {
    final next = DashboardDataProvider(widget.database).load();
    setState(() {
      future = next;
      profileFuture = widget.database.settings();
    });
    await next;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (actionBusy) return;
    setState(() => actionBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => actionBusy = false);
    }
  }

  Future<void> _newOrder() async {
    final customer = await showOrderCustomerPicker(context, widget.database);
    if (!mounted) return;
    if (customer == null) {
      await _reload();
      return;
    }
    await showOrderDialog(context, widget.database, customer);
    if (mounted) await _reload();
  }

  Future<void> _addCustomer(String initialPhone) async {
    await showCustomerDialog(
      context,
      widget.database,
      initialPhone: normalizePhone(initialPhone),
    );
    if (mounted) await _reload();
  }

  Future<void> _receivePayment(Map<String, Object?>? customer) async {
    await showPaymentDialog(context, widget.database, customer: customer);
    if (mounted) await _reload();
  }

  Future<void> _selectCustomer(Map<String, Object?> customer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomerProfileScreen(
          database: widget.database,
          customer: customer,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _markDelivered(Map<String, Object?> order) async {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final remaining =
        ((order['total'] as int?) ?? 0) - ((order['paid'] as int?) ?? 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.orderDeliveredConfirm),
        content: Text(
          remaining > 0
              ? l10n.stillOutstanding(formatMoney(remaining, locale: locale))
              : l10n.confirmHandedOver('${order['number']}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.markDelivered),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.database.updateOrderStatus(
        order['id'] as int,
        'Delivered',
        note: 'Marked delivered from dashboard',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.orderDelivered)));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      debugPrint('Dashboard delivery update failed: $error');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.orderUpdateFailed)));
    }
  }

  void _openOrder(Map<String, Object?> order) {
    widget.onNavigate(2, filter: 'order:${order['number']}');
  }

  @override
  Widget build(BuildContext context) => CommandScope(commands: [
    AppCommand('orders.add', () => _runAction(_newOrder), aliases: [CommandKey.add]),
    AppCommand(CommandKey.search, _searchFocus.requestFocus),
    AppCommand(CommandKey.refresh, _reload),
  ], child: FutureBuilder<DashboardStrings>(
    future: stringsFuture,
    builder: (context, languageSnapshot) {
      if (!languageSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final strings = languageSnapshot.data!;
      return Directionality(
        textDirection: strings.direction,
        child: FutureBuilder<DashboardData>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return _DashboardLoadError(onRetry: _reload);
              }
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                final wide = constraints.maxWidth >= 1000;
                final columns = ResponsiveLayout.columns(
                  context,
                  constraints.maxWidth - (compact ? 24 : 36),
                  minWidth: 250,
                  maxColumns: 3,
                );
                final gap = compact ? 8.0 : 12.0;
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(compact ? 12 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dashboardHeader(strings),
                        const SizedBox(height: 8),
                        _shopProfileCard(),
                        SizedBox(height: gap),
                        CustomerSearchSection(
                          searchFocusNode: _searchFocus,
                          database: widget.database,
                          strings: strings,
                          onSelect: _selectCustomer,
                          onAddCustomer: _addCustomer,
                          onQueryChanged: widget.onSearch,
                          onViewAll: () {
                            widget.onSearch('');
                            widget.onNavigate(1);
                          },
                        ),
                        SizedBox(height: gap),
                        _summaryGrid(data, strings, columns, gap),
                        SizedBox(height: gap),
                        QuickActionsSection(
                          strings: strings,
                          onNewOrder: () => _runAction(_newOrder),
                          onAddCustomer: () =>
                              _runAction(() => _addCustomer('')),
                          onReceivePayment: () =>
                              _runAction(() => _receivePayment(null)),
                          onSellFabric: () => _runAction(() async {
                            await showSellFabricDialog(
                              context,
                              widget.database,
                            );
                            if (mounted) await _reload();
                          }),
                        ),
                        SizedBox(height: gap),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: OrdersAttentionSection(
                                  dueToday: data.dueToday,
                                  overdue: data.overdue,
                                  ready: data.ready,
                                  strings: strings,
                                  onViewAll: () => widget.onNavigate(2),
                                  onOpenCustomer: _openOrder,
                                  onReceivePayment: (order) =>
                                      _receivePayment(order),
                                  onMarkDelivered: _markDelivered,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: UpcomingDeliveriesSection(
                                  rows: data.upcoming,
                                  now: CalendarService.shopToday(),
                                  strings: strings,
                                  onOpenCustomer: _openOrder,
                                  onViewAll: () => widget.onNavigate(3),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          OrdersAttentionSection(
                            dueToday: data.dueToday,
                            overdue: data.overdue,
                            ready: data.ready,
                            strings: strings,
                            onViewAll: () => widget.onNavigate(2),
                            onOpenCustomer: _openOrder,
                            onReceivePayment: (order) => _receivePayment(order),
                            onMarkDelivered: _markDelivered,
                          ),
                          SizedBox(height: gap),
                          UpcomingDeliveriesSection(
                            rows: data.upcoming,
                            now: CalendarService.shopToday(),
                            strings: strings,
                            onOpenCustomer: _openOrder,
                            onViewAll: () => widget.onNavigate(3),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    },
  ));

  Widget _summaryGrid(
    DashboardData data,
    DashboardStrings strings,
    int columns,
    double gap,
  ) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final colors = Theme.of(context).colorScheme;
    final items = [
      (
        strings.get('newToday'),
        '${data.metrics['today'] ?? 0}',
        strings.get('ordersReceivedToday'),
        Icons.receipt_long_outlined,
        colors.secondary,
        'newToday',
      ),
      (
        strings.get('dueToday'),
        '${data.metrics['due'] ?? 0}',
        strings.get('toHandOverToday'),
        Icons.event_available_outlined,
        colors.tertiary,
        'dueToday',
      ),
      (
        strings.get('overdue'),
        '${data.metrics['overdue'] ?? 0}',
        strings.get('pastDueDate'),
        Icons.warning_amber_rounded,
        colors.error,
        'overdue',
      ),
      (
        strings.get('ready'),
        '${data.metrics['ready'] ?? 0}',
        strings.get('readyForPickup'),
        Icons.check_circle_outline,
        colors.secondary,
        'ready',
      ),
      (
        strings.get('paymentsToday'),
        formatMoney(data.metrics['paidToday'] ?? 0, locale: locale),
        strings.get('paymentsRecordedToday'),
        Icons.payments_outlined,
        colors.primary,
        'payments',
      ),
      (
        strings.get('customerBalance'),
        formatMoney(data.metrics['balance'] ?? 0, locale: locale),
        strings.get('currentLedgerBalance'),
        Icons.account_balance_wallet_outlined,
        colors.onSurfaceVariant,
        'customers',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: DashboardSummaryCard(
                  label: item.$1,
                  value: item.$2,
                  description: item.$3,
                  icon: item.$4,
                  accent: item.$5,
                  direction:
                      item.$6 == 'newToday' ||
                          item.$6 == 'dueToday' ||
                          item.$6 == 'overdue' ||
                          item.$6 == 'ready'
                      ? TextDirection.ltr
                      : TextDirection.ltr,
                  onTap: () {
                    switch (item.$6) {
                      case 'newToday':
                        widget.onNavigate(2, filter: 'newToday');
                      case 'dueToday':
                        widget.onNavigate(2, filter: 'dueToday');
                      case 'overdue':
                        widget.onNavigate(2, filter: 'overdue');
                      case 'ready':
                        widget.onNavigate(2, filter: 'ready');
                      case 'customers':
                        widget.onNavigate(1, filter: 'owing');
                      case 'payments':
                        widget.onNavigate(8);
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _shopProfileCard() => FutureBuilder<Map<String, Object?>>(
    future: profileFuture,
    builder: (context, snapshot) {
      final profile = snapshot.data;
      if (profile == null) return const SizedBox.shrink();
      final name = (profile['shop_name'] as String? ?? widget.shopName).trim();
      final owner = (profile['owner_name'] as String? ?? '').trim();
      final phone = (profile['phone'] as String? ?? '').trim();
      final address = (profile['address'] as String? ?? '').trim();
      final contacts = [
        if (owner.isNotEmpty) _profileValue(Icons.person_outline, owner),
        if (phone.isNotEmpty) _profileValue(Icons.phone_outlined, phone),
        if (address.isNotEmpty)
          _profileValue(Icons.location_on_outlined, address),
      ];
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primary.withValues(alpha: .06),
              ],
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heading = Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              );
              final editButton = IconButton.filledTonal(
                tooltip: context.l10n.settings,
                onPressed: () => widget.onNavigate(9),
                icon: const Icon(Icons.edit_outlined),
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: heading),
                        editButton,
                      ],
                    ),
                    if (contacts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 6, children: contacts),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        if (contacts.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 12, runSpacing: 6, children: contacts),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  editButton,
                ],
              );
            },
          ),
        ),
      );
    },
  );

  Widget _dashboardHeader(DashboardStrings strings) =>
      FutureBuilder<Map<String, Object?>>(
        future: profileFuture,
        builder: (context, snapshot) => DashboardHeader(
          shopName: (snapshot.data?['shop_name'] as String? ?? widget.shopName)
              .trim(),
          logoPath: snapshot.data?['shop_logo_path'] as String?,
          now: CalendarService.shopToday(),
          strings: strings,
          onNewOrder: () => _runAction(_newOrder),
          onRefresh: _reload,
        ),
      );

  Widget _profileValue(IconData icon, String value) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 17,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

class _DashboardLoadError extends StatelessWidget {
  const _DashboardLoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.dashboardLoadError),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(context.l10n.tryAgain),
          ),
        ],
      ),
    ),
  );
}

class _CustomerPickerDialog extends StatefulWidget {
  const _CustomerPickerDialog({required this.database});
  final ShopDatabase database;

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  final controller = TextEditingController();
  List<Map<String, Object?>> rows = [];
  bool loading = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = value.trim().isEmpty
          ? await widget.database.searchCustomers('')
          : await widget.database.searchCustomers(value);
      if (!mounted) return;
      setState(() {
        rows = results;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = context.l10n.errorGeneric;
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.chooseCustomer),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: context.l10n.searchNamePhone,
            ),
            onChanged: _search,
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            TextButton.icon(
              onPressed: () => _search(controller.text),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                return ListTile(
                  title: Text(row['name'] as String),
                  subtitle: Text(
                    '${row['phone']} · ${row['code'] ?? row['id']}',
                    textDirection: TextDirection.ltr,
                  ),
                  onTap: () => Navigator.pop(context, row),
                );
              },
            ),
          ),
          if (!loading && error == null && rows.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(context.l10n.noCustomerToOrder),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      if (rows.isEmpty && !loading)
        TextButton.icon(
          onPressed: () async {
            await showCustomerDialog(
              context,
              widget.database,
              initialPhone: normalizePhone(controller.text),
            );
            if (mounted) await _search(controller.text);
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(context.l10n.addCustomer),
        ),
    ],
  );
}
