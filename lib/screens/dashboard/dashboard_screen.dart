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
import '../settings/shop_profile_screen.dart';
import '../suppliers/fabric_purchase_screen.dart';
import 'dashboard_data_provider.dart';
import 'dashboard_strings.dart';
import 'widgets/customer_search_section.dart';
import 'widgets/dashboard_activity.dart';
import 'widgets/dashboard_charts.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_panel.dart';
import 'widgets/dashboard_summary_card.dart';
import 'widgets/orders_attention_section.dart';
import 'widgets/premium_illustration.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/shop_identity_card.dart';
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
    this.onShopNameChanged,
    this.onLogoChanged,
    this.deliveryOnly = false,
  });

  final ShopDatabase database;
  final String shopName;
  final ValueChanged<String> onSearch;
  final void Function(int page, {String? filter}) onNavigate;
  final ValueChanged<String>? onShopNameChanged;
  final ValueChanged<String?>? onLogoChanged;
  final bool deliveryOnly;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> future;
  late Future<DashboardStrings> stringsFuture;
  bool actionBusy = false;
  final _searchFocus = FocusNode();
  String period = 'month';
  Future<void> _gate = Future<void>.value();
  Map<String, Object?>? _profile;
  DashboardInsight? _insight;
  bool _insightLoading = true;

  @override
  void dispose() { _searchFocus.dispose(); super.dispose(); }

  Future<T> _serialized<T>(Future<T> Function() task) {
    final result = _gate.then((_) => task());
    _gate = result.then((_) {}, onError: (_, _) {});
    return result;
  }

  ({DateTime from, DateTime through}) _periodRange() {
    final today = CalendarService.shopToday();
    final day = DateTime(today.year, today.month, today.day);
    final calendar = CalendarService.activeCalendar;
    return switch (period) {
      'today' => (from: day, through: day),
      'year' => (
        from: CalendarService.startOfYear(day, calendar: calendar),
        through: day,
      ),
      _ => (
        from: CalendarService.startOfMonth(day, calendar: calendar),
        through: day,
      ),
    };
  }

  Future<DashboardData> _boot() => _serialized(() async {
    final provider = DashboardDataProvider(widget.database);
    final data = await provider.load();
    final profile = await widget.database.settings();
    final range = _periodRange();
    final insight = await provider.loadInsight(
      from: range.from,
      through: range.through,
    );
    _profile = profile;
    _insight = insight;
    _insightLoading = false;
    return data;
  });

  Future<void> _loadInsight() async {
    final range = _periodRange();
    final insight = await _serialized(
      () => DashboardDataProvider(widget.database).loadInsight(
        from: range.from,
        through: range.through,
      ),
    );
    if (!mounted) return;
    setState(() {
      _insight = insight;
      _insightLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    future = _boot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    stringsFuture = Future.value(DashboardStrings.of(context));
  }

  Future<void> _reload() async {
    final next = _boot();
    setState(() {
      future = next;
      _insightLoading = true;
    });
    await next;
    if (mounted) setState(() {});
  }

  void _selectPeriod(String value) {
    if (period == value) return;
    setState(() {
      period = value;
      _insightLoading = true;
    });
    _loadInsight();
  }

  Future<void> _editProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShopProfileScreen(
          database: widget.database,
          onShopNameChanged: widget.onShopNameChanged,
        ),
      ),
    );
    if (!mounted) return;
    final settings = await widget.database.settings();
    if (!mounted) return;
    setState(() => _profile = settings);
    widget.onLogoChanged?.call(settings['shop_logo_path'] as String?);
  }

  Future<void> _purchaseFabric() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => FabricPurchaseScreen(database: widget.database),
      ),
    );
    if (mounted) await _reload();
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
                              onOpenBill: _openOrder,
                              onQueryChanged: widget.onSearch,
                              onViewAll: () {
                                widget.onSearch('');
                                widget.onNavigate(1);
                              },
                            ),
                            SizedBox(height: gap),
                            _periodSelector(),
                            SizedBox(height: gap),
                            _summaryGrid(
                              data,
                              _insight,
                              _insightLoading,
                              columns,
                              gap,
                            ),
                            SizedBox(height: gap),
                            _secondaryMetrics(
                              data,
                              _insight,
                              _insightLoading,
                              gap,
                            ),
                            SizedBox(height: gap),
                            QuickActionsSection(
                              strings: strings,
                              onNewOrder: () => _runAction(_newOrder),
                              onFindCustomer: _searchFocus.requestFocus,
                              onAddCustomer: () =>
                                  _runAction(() => _addCustomer('')),
                              onReceivePayment: () =>
                                  _runAction(() => _receivePayment(null)),
                              onPurchaseFabric: () =>
                                  _runAction(_purchaseFabric),
                              onSellFabric: () => _runAction(() async {
                                await showSellFabricDialog(
                                  context,
                                  widget.database,
                                );
                                if (mounted) await _reload();
                              }),
                            ),
                            SizedBox(height: gap),
                            DashboardCharts(
                              insight: _insight,
                              loading: _insightLoading,
                              onOpenReports: () => widget.onNavigate(7),
                              onRetry: () {
                                setState(() => _insightLoading = true);
                                _loadInsight();
                              },
                            ),
                            SizedBox(height: gap),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TodayDeliveriesSection(
                                      rows: data.dueToday,
                                      strings: strings,
                                      onOpen: _openOrder,
                                      onViewAll: () => widget.onNavigate(
                                        2,
                                        filter: 'dueToday',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
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
                              TodayDeliveriesSection(
                                rows: data.dueToday,
                                strings: strings,
                                onOpen: _openOrder,
                                onViewAll: () => widget.onNavigate(
                                  2,
                                  filter: 'dueToday',
                                ),
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
                            SizedBox(height: gap),
                            OrdersAttentionSection(
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
                            SizedBox(height: gap),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: RecentOrdersSection(
                                      rows: data.recentOrders,
                                      strings: strings,
                                      onOpen: _openOrder,
                                      onViewAll: () => widget.onNavigate(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: LowStockSection(
                                      rows: data.lowStock,
                                      onOpenFabric: () => widget.onNavigate(4),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              RecentOrdersSection(
                                rows: data.recentOrders,
                                strings: strings,
                                onOpen: _openOrder,
                                onViewAll: () => widget.onNavigate(2),
                              ),
                              SizedBox(height: gap),
                              LowStockSection(
                                rows: data.lowStock,
                                onOpenFabric: () => widget.onNavigate(4),
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

  Widget _periodSelector() {
    final l10n = context.l10n;
    final options = [
      ('today', l10n.dashPeriodToday),
      ('month', l10n.dashPeriodMonth),
      ('year', l10n.dashPeriodYear),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.$2),
                selected: period == option.$1,
                onSelected: (_) => _selectPeriod(option.$1),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.dashPeriodScope,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _accent(Color color) => Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, .18)!
      : color;

  String _money(int? value, String locale, {required String unavailable}) =>
      value == null ? unavailable : formatMoney(value, locale: locale);

  Widget _summaryGrid(
    DashboardData data,
    DashboardInsight? insight,
    bool insightLoading,
    int columns,
    double gap,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final periodLabel = switch (period) {
      'today' => l10n.dashPeriodToday,
      'year' => l10n.dashPeriodYear,
      _ => l10n.dashPeriodMonth,
    };
    final netValue = insightLoading
        ? l10n.dashLoadingFigures
        : insight == null || insight.failed
        ? '—'
        : _money(
            insight.netProfit,
            locale,
            unavailable: l10n.dashProfitUnavailableShort,
          );
    final netColor = insight?.netProfit == null
        ? dashboardToneColor(context, DashboardTone.warning)
        : insight!.netProfit! < 0
        ? dashboardToneColor(context, DashboardTone.due)
        : null;
    final customerDue = data.customerDebt;
    final supplierDue = data.supplierDebt;
    final items = [
      _CardSpec(
        key: const ValueKey('dashboard-card-today'),
        label: l10n.dashTodayOrders,
        value: '${data.metrics['today'] ?? 0}',
        description: l10n.dashTodayOrdersHint,
        mark: PremiumMark.orders,
        accent: _accent(const Color(0xff2563eb)),
        badge: l10n.dashBadgeToday,
        onTap: () => widget.onNavigate(2, filter: 'newToday'),
      ),
      _CardSpec(
        key: const ValueKey('dashboard-card-ready'),
        label: l10n.dashReadyCollection,
        value: '${data.metrics['ready'] ?? 0}',
        description: l10n.dashReadyCollectionHint,
        mark: PremiumMark.ready,
        accent: _accent(const Color(0xff15803d)),
        badge: l10n.dashBadgeToday,
        onTap: () => widget.onNavigate(2, filter: 'ready'),
      ),
      _CardSpec(
        key: const ValueKey('dashboard-card-customer-due'),
        label: l10n.dashCustomerDue,
        value: formatMoney(customerDue, locale: locale),
        description: customerDue == 0
            ? l10n.dashNothingDue
            : l10n.dashCustomerDueHint,
        mark: PremiumMark.customers,
        accent: _accent(const Color(0xffea580c)),
        badge: l10n.dashBadgeBalance,
        valueColor: customerDue == 0
            ? dashboardToneColor(context, DashboardTone.good)
            : dashboardToneColor(context, DashboardTone.due),
        onTap: () => widget.onNavigate(1, filter: 'owing'),
      ),
      _CardSpec(
        key: const ValueKey('dashboard-card-supplier-due'),
        label: l10n.dashSupplierDue,
        value: formatMoney(supplierDue, locale: locale),
        description: supplierDue == 0
            ? l10n.dashNothingDue
            : l10n.dashSupplierDueHint,
        mark: PremiumMark.suppliers,
        accent: _accent(const Color(0xffdc2626)),
        badge: l10n.dashBadgeBalance,
        valueColor: supplierDue == 0
            ? dashboardToneColor(context, DashboardTone.good)
            : dashboardToneColor(context, DashboardTone.due),
        onTap: () => widget.onNavigate(5),
      ),
      _CardSpec(
        key: const ValueKey('dashboard-card-fabric'),
        label: l10n.dashFabricAvailable,
        value: '${dashboardMeters(data.availableMeters)} ${l10n.fabricFormMeter}',
        description: l10n.dashFabricAvailableHint,
        mark: PremiumMark.fabric,
        accent: _accent(const Color(0xff0f766e)),
        badge: l10n.dashBadgeBalance,
        onTap: () => widget.onNavigate(4),
      ),
      _CardSpec(
        key: const ValueKey('dashboard-card-profit'),
        label: l10n.dashNetProfit,
        value: netValue,
        description: insightLoading
            ? l10n.dashLoadingFigures
            : insight == null || insight.failed
            ? l10n.dashInsightFailed
            : insight.netProfit == null
            ? l10n.dashProfitUnavailableHint
            : '$periodLabel · ${l10n.dashNetProfitHint}',
        mark: PremiumMark.profit,
        accent: _accent(const Color(0xff7c3aed)),
        badge: l10n.dashBadgePeriod,
        valueColor: netColor,
        onTap: () => widget.onNavigate(7),
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
                  key: item.key,
                  label: item.label,
                  value: item.value,
                  description: item.description,
                  mark: item.mark,
                  accent: item.accent,
                  badge: item.badge,
                  valueColor: item.valueColor,
                  onTap: item.onTap,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _secondaryMetrics(
    DashboardData data,
    DashboardInsight? insight,
    bool insightLoading,
    double gap,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final periodLabel = switch (period) {
      'today' => l10n.dashPeriodToday,
      'year' => l10n.dashPeriodYear,
      _ => l10n.dashPeriodMonth,
    };
    String periodMoney(int? value) => insightLoading
        ? l10n.dashLoadingFigures
        : insight == null || insight.failed
        ? '—'
        : _money(value, locale, unavailable: l10n.dashProfitUnavailableShort);
    final items = [
      (
        l10n.dueToday,
        '${data.metrics['due'] ?? 0}',
        l10n.toHandOverToday,
        PremiumMark.delivery,
        const Color(0xffea580c),
        () => widget.onNavigate(2, filter: 'dueToday'),
        null as Color?,
      ),
      (
        l10n.overdue,
        '${data.metrics['overdue'] ?? 0}',
        l10n.pastDueDate,
        PremiumMark.delivery,
        const Color(0xffdc2626),
        () => widget.onNavigate(2, filter: 'overdue'),
        (data.metrics['overdue'] ?? 0) > 0
            ? dashboardToneColor(context, DashboardTone.due)
            : null,
      ),
      (
        l10n.paymentsToday,
        formatMoney(data.metrics['paidToday'] ?? 0, locale: locale),
        l10n.dashCashCollected,
        PremiumMark.payments,
        const Color(0xff15803d),
        () => widget.onNavigate(8),
        null,
      ),
      (
        l10n.customerBalance,
        formatMoney(data.metrics['balance'] ?? 0, locale: locale),
        l10n.currentLedgerBalance,
        PremiumMark.customers,
        const Color(0xff0f766e),
        () => widget.onNavigate(1),
        null,
      ),
      (
        l10n.reportMetricSales,
        periodMoney(insight?.sales),
        periodLabel,
        PremiumMark.reports,
        const Color(0xff2563eb),
        () => widget.onNavigate(7),
        null,
      ),
      (
        l10n.reportNetStitchingRevenue,
        periodMoney(insight?.stitchingRevenue),
        periodLabel,
        PremiumMark.stitching,
        const Color(0xff7c3aed),
        () => widget.onNavigate(7),
        null,
      ),
      (
        l10n.reportMetricGrossProfit,
        periodMoney(insight?.grossProfit),
        periodLabel,
        PremiumMark.profit,
        const Color(0xff0f766e),
        () => widget.onNavigate(7),
        insight != null && !insight.failed && insight.grossProfit == null
            ? dashboardToneColor(context, DashboardTone.warning)
            : null,
      ),
      (
        l10n.reportMetricExpenses,
        periodMoney(insight?.expenses),
        periodLabel,
        PremiumMark.expenses,
        const Color(0xffea580c),
        () => widget.onNavigate(6),
        null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashMoreFigures,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width < 520
                ? 1
                : width < 900
                ? 2
                : 4;
            final itemWidth = (width - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: DashboardMiniMetric(
                      label: item.$1,
                      value: item.$2,
                      description: item.$3,
                      mark: item.$4,
                      accent: _accent(item.$5),
                      onTap: item.$6,
                      valueColor: item.$7,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _shopProfileCard() {
    final profile = _profile;
    return ShopIdentityCard(
      shopName: (profile?['shop_name'] as String? ?? widget.shopName).trim(),
      owner: (profile?['owner_name'] as String? ?? '').trim(),
      phone: (profile?['phone'] as String? ?? '').trim(),
      address: (profile?['address'] as String? ?? '').trim(),
      logoPath: profile?['shop_logo_path'] as String?,
      onEdit: _editProfile,
    );
  }

  Widget _dashboardHeader(DashboardStrings strings) => DashboardHeader(
    now: CalendarService.shopToday(),
    strings: strings,
    onNewOrder: () => _runAction(_newOrder),
    onRefresh: _reload,
  );
}

class _CardSpec {
  const _CardSpec({
    required this.key,
    required this.label,
    required this.value,
    required this.description,
    required this.mark,
    required this.accent,
    required this.badge,
    required this.onTap,
    this.valueColor,
  });

  final Key key;
  final String label;
  final String value;
  final String description;
  final PremiumMark mark;
  final Color accent;
  final String badge;
  final VoidCallback onTap;
  final Color? valueColor;
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
      width: fitContentWidth(context, 480),
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
