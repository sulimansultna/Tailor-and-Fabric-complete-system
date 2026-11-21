import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/core/formatters.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/reports/report_service.dart';
import 'package:tailor_shop/screens/dashboard/dashboard_data_provider.dart';
import 'package:tailor_shop/screens/dashboard/widgets/dashboard_charts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late String databasePath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'dashboard_metrics_${DateTime.now().microsecondsSinceEpoch}.db';
    database = await ShopDatabase.openAt(databasePath);
    await database.saveSettings({
      'language': 'English',
      'shop_name': 'A very long tailor shop name for the identity card',
    });
  });

  tearDown(() async {
    await database.db.close();
    final file = File(databasePath);
    if (await file.exists()) await file.delete();
  });

  test('dashboard balances and profit match their source reports', () async {
    final today = CalendarService.shopToday();
    final todayKey = _iso(today);
    await database.addCustomer(
      name: 'Ahmad',
      phone: '0700111222',
      opening: 150000,
    );
    await database.addSupplier(
      name: 'Kabul Fabric',
      phone: '0799000111',
      openingBalance: 250000,
    );
    await database.addFabric(
      name: 'Cotton',
      color: 'Navy',
      unit: 'meter',
      cost: 10000,
      price: 20000,
      lowStock: 2,
      openingQuantity: 20,
      openingDate: DateTime.now(),
    );
    await database.addFabric(
      name: 'Silk',
      color: 'Red',
      unit: 'meter',
      cost: 10000,
      price: 20000,
      lowStock: 5,
      openingQuantity: 1,
      openingDate: DateTime.now(),
    );
    final customerId = (await database.searchCustomers('Ahmad')).single['id']
        as int;
    await database.createOrder(
      customerId: customerId,
      total: 200000,
      advance: 0,
      billNumber: '00125',
      dueDate: todayKey,
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 200000,
        },
      ],
    );

    final provider = DashboardDataProvider(database);
    final data = await provider.load();
    final from = CalendarService.startOfMonth(
      today,
      calendar: CalendarService.activeCalendar,
    );
    final insight = await provider.loadInsight(from: from, through: today);
    final report = await ReportService(database).generate(
      fromDate: _iso(from),
      throughDate: todayKey,
    );
    final overview = (report['overview'] as Map).cast<String, Object?>();
    final profit =
        (((report['sections'] as Map)['profit'] as Map)).cast<String, Object?>();

    expect(data.customerDebt, overview['customer_debt']);
    expect(data.supplierDebt, overview['supplier_payable']);
    expect(data.customerDebt, greaterThan(0));
    expect(data.supplierDebt, 250000);
    expect(data.availableMeters, 21);
    expect(data.lowStock, hasLength(1));
    expect(data.lowStock.single['name'], 'Silk');
    expect(insight.failed, isFalse);
    expect(insight.netProfit, profit['net_profit']);
    expect(insight.grossProfit, profit['gross_profit']);
    expect(insight.stitchingRevenue, profit['net_stitching_revenue']);
    expect(insight.stitchingProfit, profit['stitching_profit']);
    expect(insight.fabricProfit, profit['fabric_profit']);
    expect(insight.expenses, profit['expenses']);
    expect(insight.sales, overview['sales']);
    expect(insight.cashCollected, overview['receipts']);
    expect(data.dueToday, isNotEmpty);
  });

  testWidgets('profit chart keeps stitching revenue separate from profit', (
    tester,
  ) async {
    final insight = DashboardInsight(
      from: DateTime(2026, 11, 1),
      through: DateTime(2026, 11, 21),
      orders: [
        DashboardOrderPoint(bucket: DateTime(2026, 11, 2), count: 2),
      ],
      ordersMonthly: false,
      expenses: 20000,
      sales: 700000,
      cashCollected: 100000,
      fabricProfit: 100000,
      stitchingRevenue: 500000,
      stitchingProfit: null,
      grossProfit: null,
      netProfit: null,
    );
    await tester.pumpWidget(
      _app(
        home: Scaffold(
          body: DashboardCharts(
            insight: insight,
            loading: false,
            onOpenReports: () {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Net Stitching Revenue'), findsOneWidget);
    expect(find.text('Stitching Gross Profit'), findsOneWidget);
    expect(find.text('Unavailable'), findsNWidgets(3));
    expect(find.text(formatMoney(500000, locale: 'en')), findsOneWidget);
    expect(find.text('Net profit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}

Widget _app({required Widget home, ThemeData? theme}) => MaterialApp(
  theme: theme ?? buildAppTheme(),
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa', 'AF')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    TailorShopCupertinoLocalizationsDelegate.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: home,
);

String _iso(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
