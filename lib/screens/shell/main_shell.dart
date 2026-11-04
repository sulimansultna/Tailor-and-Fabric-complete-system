import 'package:flutter/material.dart';
import '../../commands/app_commands.dart';
import '../../dialogs/measurement_dialog.dart';
import '../../dialogs/measurement_history_dialog.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../models/garment.dart';
import '../customers/customer_profile_screen.dart';
import '../suppliers/fabric_purchase_screen.dart';
import '../workers/workers_screen.dart';

import '../../data/shop_database.dart';
import '../dashboard/dashboard_screen.dart';
import '../customers/customers_screen.dart';
import '../orders/orders_screen.dart';
import '../delivery/delivery_screen.dart';
import '../settings/settings_screen.dart';
import '../payments/payments_screen.dart';
import '../shared/coming_soon_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/locale_controller_scope.dart';
import '../fabric/fabric_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../expenses/expenses_screen.dart';
import '../../widgets/shop_logo.dart';
import '../../reports/report_service.dart';
import '../../auth/auth_controller.dart';
import '../reports/reports_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.database,
    required this.shopName,
    required this.authController,
    this.onBusinessRestored,
  });
  final ShopDatabase database;
  final String shopName;
  final AuthController authController;
  final Future<void> Function()? onBusinessRestored;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int page = 0;
  late String currentShopName;
  String? shopLogoPath;
  String search = '';
  String? orderFilter;
  String orderSearch = '';
  bool onlyOwing = false;
  String? reportSection;
  DeliveryBoardState deliveryState = DeliveryBoardState();
  bool dataOperationBusy = false;
  bool? sidebarExpanded;

  @override
  void initState() {
    super.initState();
    currentShopName = widget.shopName;
    widget.database.settings().then((settings) {
      if (mounted) {
        setState(() => shopLogoPath = settings['shop_logo_path'] as String?);
      }
    });
  }

  List<(String, IconData)> _items(AppLocalizations l10n) => [
    (l10n.dashboard, Icons.dashboard_outlined),
    (l10n.customers, Icons.people_outline),
    (l10n.orders, Icons.receipt_long_outlined),
    (l10n.deliveryBoard, Icons.event_available_outlined),
    (l10n.fabric, Icons.inventory_2_outlined),
    (l10n.reportSuppliers, Icons.storefront_outlined),
    (l10n.expenses, Icons.payments_outlined),
    (l10n.reports, Icons.bar_chart_outlined),
    (l10n.payments, Icons.payments_outlined),
    (l10n.settings, Icons.settings_outlined),
  ];

  Future<void> _navigate(int value, {String? filter}) async {
    final registry = AppCommandRegistry.maybeOf(context);
    if (registry != null && !await registry.allowNavigation()) return;
    if (mounted) _setPage(value, filter: filter);
  }

  void _setPage(int value, {String? filter}) {
    setState(() {
      page = value;
      if (value == 2) {
        orderFilter = filter;
        orderSearch = filter != null && filter.startsWith('order:')
            ? filter.substring('order:'.length)
            : '';
      }
      if (value == 1) onlyOwing = filter == 'owing';
      if (value == 7) {
        reportSection = switch (filter) {
          'fabric_profit' => 'Fabric profit',
          'fabric_price_profit' => 'Fabric price profit',
          _ => null,
        };
      }
    });
  }

  Future<void> _commandNavigate(int value, {String? filter}) async {
    final registry = AppCommandRegistry.maybeOf(context);
    if (dataOperationBusy || registry == null || !await registry.allowNavigation() || !mounted) return;
    final shellRoute = ModalRoute.of(context);
    Navigator.of(context).popUntil((route) => route == shellRoute);
    _setPage(value, filter: filter);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<Map<String, Object?>?> _commandCustomer() async {
    final rows = await widget.database.searchCustomers('');
    if (!mounted) return null;
    return commandRecord(context, 'customer', rows);
  }

  Future<void> _customerLedger() async {
    final customer = await _commandCustomer();
    if (!mounted || customer == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerProfileScreen(
      database: widget.database, customer: customer, initialTabIndex: 1)));
  }

  Future<void> _measurements({bool history = false}) async {
    final customer = await _commandCustomer();
    if (!mounted || customer == null) return;
    final choice = await pickCommandRecord(context, 'garment', [
      for (final garment in Garment.values) {'id': garment.index, 'name': localizedGarment(context, garment)},
    ], title: context.l10n.garment);
    if (!mounted || choice == null) return;
    final garment = Garment.values[choice['id'] as int];
    if (history) {
      await showMeasurementHistoryDialog(context, widget.database, customer, garment);
    } else {
      final profiles = await widget.database.measurements(customer['id'] as int, garment.key);
      if (!mounted) return;
      await showMeasurementDialog(context, widget.database, customer, garment,
        existing: profiles.where((profile) => profile['active'] == 1).firstOrNull, onSaved: () async {});
    }
  }

  List<AppCommand> _shellCommands() {
    final registry = AppCommandRegistry.maybeOf(context)!;
    String? busy() => dataOperationBusy ? localizedCommandText(context,
      'Wait for the backup or restore operation to finish.', 'بیک اپ یا بیا رغولو ته انتظار وکړئ.', 'منتظر پایان پشتیبان‌گیری یا بازیابی بمانید.') : null;
    final navigation = <String, int>{'nav.dashboard':0, 'nav.customers':1, 'nav.orders':2,
      'nav.delivery':3, 'nav.fabric':4, 'nav.suppliers':5, 'nav.payments':8,
      'nav.workers':10, 'nav.reports':7, 'nav.expenses':6, 'nav.settings':9};
    final features = <int, List<String>>{
      1:['customers.add','customers.edit','customers.remove','customers.profile','customers.restore','customers.archive'],
      2:['orders.add','orders.edit','orders.drafts','orders.print','orders.printBoth','orders.measurementPrint','orders.history','orders.refund',
        'order.deliver','order.archive','order.cancel','order.return','order.restore'],
      4:['fabric.add','fabric.edit','fabric.remove','fabric.sale','fabric.stockIn','fabric.adjust','fabric.archive','fabric.details'],
      5:['suppliers.add','suppliers.edit','suppliers.remove','suppliers.archive','suppliers.payment','purchases.drafts'],
      8:['payments.add','payments.details','payments.print','payments.reverse'],
      10:['workers.add','workers.edit','workers.profile','workers.salary'],
      6:['expenses.add','expenses.reverse','expenses.categories','expenses.templates','expenses.csv','expenses.print'],
      7:['reports.generate','reports.range','reports.pdf','reports.csv','reports.print','reports.overview','reports.stitching','reports.fabric'],
      9:['settings.language','settings.calendar','settings.theme','settings.printing','settings.profile','settings.backup','settings.restore','settings.signOut'],
    };
    return [
      for (final entry in navigation.entries) AppCommand(entry.key, () => _commandNavigate(entry.value), disabledReason: busy),
      AppCommand('nav.purchases', () async {
        if (!await registry.allowNavigation() || !mounted) return;
        final shellRoute = ModalRoute.of(context);
        Navigator.of(context).popUntil((route) => route == shellRoute);
        await Navigator.of(context).push(MaterialPageRoute<String>(builder: (_) => FabricPurchaseScreen(database: widget.database)));
      }, disabledReason: busy),
      AppCommand('nav.customerLedger', _customerLedger, disabledReason: busy),
      AppCommand('nav.supplierLedger', () => registry.forward(() => _commandNavigate(5), 'nav.supplierLedger'), disabledReason: busy),
      AppCommand('nav.measurements', () => _measurements(), disabledReason: busy),
      AppCommand('measurements.add', () => _measurements(), disabledReason: busy),
      AppCommand('measurements.history', () => _measurements(history: true), disabledReason: busy),
      AppCommand('nav.history', () => registry.forward(() => _commandNavigate(2), 'nav.history'), disabledReason: busy),
      AppCommand('nav.backup', () => registry.forward(() => _commandNavigate(9), 'nav.backup'), disabledReason: busy),
      for (final section in features.entries)
        for (final feature in section.value)
          AppCommand('go.$feature', () => registry.forward(() => _commandNavigate(section.key), feature), disabledReason: busy),
    ];
  }

  Future<void> _showMore() async {
    final l10n = AppLocalizations.of(context)!;
    final items = _items(l10n);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var index = 4; index < items.length; index++)
              ListTile(
                leading: Icon(items[index].$2),
                title: Text(items[index].$1),
                selected: page == index,
                trailing: Text(_navigationShortcut(index), textDirection: TextDirection.ltr),
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      ),
    );
    if (selected != null) _navigate(selected);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      LocaleControllerScope.maybeOf(context);
      final l10n = AppLocalizations.of(context)!;
      final items = _items(l10n);
      final compact = constraints.maxWidth < 700;
      final extended = sidebarExpanded ?? constraints.maxWidth >= 1180;
      final language = Localizations.localeOf(context).languageCode;
      final toggleLabel = language == 'ps'
          ? (extended ? 'مینو کوچنۍ کړئ' : 'مینو پراخه کړئ')
          : language == 'fa'
          ? (extended ? 'کوچک کردن منو' : 'باز کردن منو')
          : (extended ? 'Collapse sidebar' : 'Expand sidebar');
      final sidebarToggle = IconButton(
        key: const ValueKey('sidebar-toggle'),
        tooltip: toggleLabel,
        onPressed: dataOperationBusy
            ? null
            : () => setState(() => sidebarExpanded = !extended),
        icon: Icon(extended ? Icons.menu_open_rounded : Icons.menu_rounded),
        color: const Color(0xffd0d8e2),
      );
      final shellBody = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) ...[
            NavigationRail(
              extended: extended,
              minWidth: 72,
              minExtendedWidth: 240,
              scrollable: true,
                  selectedIndex: page == 10 ? 6 : page,
              onDestinationSelected: dataOperationBusy ? null : _navigate,
              leading: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: extended
                    ? SizedBox(
                        width: 216,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShopLogo(path: shopLogoPath, size: 32),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentShopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            sidebarToggle,
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShopLogo(path: shopLogoPath, size: 32),
                          const SizedBox(height: 8),
                          sidebarToggle,
                        ],
                      ),
              ),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.$2),
                    selectedIcon: Icon(item.$2),
                    label: Tooltip(message: '${item.$1} · ${_navigationShortcut(items.indexOf(item))}', child: Text(item.$1)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
          ],
          Expanded(
            key: const ValueKey('active-page-host'),
            child: SafeArea(child: _responsiveContent(l10n)),
          ),
        ],
      );
      return CommandScope(global: true, priority: 0,
        commands: AppCommandRegistry.maybeOf(context) == null ? const [] : _shellCommands(),
        child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned.fill(child: shellBody),
            if (dataOperationBusy) ...[
              const ModalBarrier(dismissible: false, color: Colors.black26),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
        bottomNavigationBar: compact
            ? NavigationBar(
                selectedIndex: page <= 3 ? page : 4,
                onDestinationSelected: dataOperationBusy
                    ? null
                    : (index) {
                        if (index == 4) {
                          _showMore();
                        } else {
                          _navigate(index);
                        }
                      },
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    label: l10n.home,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline),
                    label: l10n.customers,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    label: l10n.orders,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_available_outlined),
                    label: l10n.delivery,
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    label: l10n.more,
                  ),
                ],
              )
            : null,
      ));
    },
  );

  String _navigationShortcut(int index) => const ['Ctrl+1','Ctrl+2','Ctrl+3','Ctrl+4','Ctrl+5','Ctrl+6','Ctrl+Shift+4','Ctrl+9','Ctrl+7','Ctrl+,'][index];

  Widget _responsiveContent(AppLocalizations l10n) => LayoutBuilder(
    builder: (context, constraints) => MediaQuery(
      // Page breakpoints must use the space left after navigation and safe areas.
      data: MediaQuery.of(context)
          .copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
      child: _content(l10n),
    ),
  );

  Widget _content(AppLocalizations l10n) => switch (page) {
    0 => DashboardScreen(
      database: widget.database,
      shopName: currentShopName,
      onSearch: (value) => search = value,
      onNavigate: _navigate,
    ),
    1 => CustomersScreen(
      database: widget.database,
      initialSearch: search,
      initialOnlyOwing: onlyOwing,
    ),
    2 => OrdersScreen(
      database: widget.database,
      initialFilter: orderFilter,
      initialSearch: orderSearch,
    ),
    3 => DeliveryScreen(
      database: widget.database,
      onNavigate: _navigate,
      state: deliveryState,
      onStateChanged: (value) => deliveryState = value,
    ),
    4 => FabricScreen(
      database: widget.database,
      onOpenProfitReport: () => _navigate(7, filter: 'fabric_price_profit'),
    ),
    5 => SuppliersScreen(database: widget.database),
    6 => ExpensesScreen(database: widget.database),
    7 => ReportsScreen(
      service: ReportService(widget.database),
      initialSection: reportSection,
    ),
    8 => PaymentsScreen(database: widget.database),
    10 => WorkersScreen(database: widget.database),
    9 => SettingsScreen(
      database: widget.database,
      authController: widget.authController,
      onShopNameChanged: (value) => setState(() => currentShopName = value),
      onOperationBusyChanged: (value) {
        if (mounted) setState(() => dataOperationBusy = value);
      },
      onDataRestored: () async {
        final settings = await widget.database.settings();
        if (mounted) {
          setState(() {
            page = 0;
            currentShopName =
                settings['shop_name']?.toString() ?? currentShopName;
            shopLogoPath = settings['shop_logo_path'] as String?;
            search = '';
            orderFilter = null;
            orderSearch = '';
            onlyOwing = false;
            deliveryState = DeliveryBoardState();
          });
        }
        await widget.onBusinessRestored?.call();
      },
    ),
    _ => ComingSoonScreen(
      title: page == 4 ? l10n.fabricInventory : _items(l10n)[page].$1,
    ),
  };
}
