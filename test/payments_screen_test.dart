import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/orders/orders_screen.dart';
import 'package:tailor_shop/screens/payments/payments_screen.dart';

void main() {
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('payment rows keep bill, receipt, amount, and method separate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CalendarService.activeCalendar = CalendarService.gregorian;
    CalendarService.activeLocale = 'en';
    CalendarService.showBothDates = false;
    database = (await tester.runAsync(() async {
      final db = await ShopDatabase.openAt(inMemoryDatabasePath);
      final customerId = await db.addCustomer(
        name: 'Bashir Ahmad',
        phone: '0700550000',
      );
      await db.createOrder(
        customerId: customerId,
        total: 100000,
        advance: 0,
        billNumber: '00125',
        lines: [
          {
            'garment': 'Shalwar Kameez',
            'quantity': 2,
            'measurement_snapshot': '{}',
            'price_each': 50000,
          },
        ],
      );
      final order = (await db.db.query('orders')).single;
      await db.receivePayment(
        customerId: customerId,
        amount: 24050,
        date: CalendarService.shopToday(),
        method: 'Cash',
        description: 'Screen test',
        allocations: {order['id'] as int: 24050},
      );
      return db;
    }))!;
    addTearDown(() async {
      await tester.runAsync(() => database.db.close());
    });

    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('ltr'),
        locale: const Locale('en'),
        supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: PaymentsScreen(database: database)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bill 00125'), findsOneWidget);
    expect(find.text('Shalwar Kameez ×2'), findsOneWidget);
    expect(find.text('R-0000001'), findsOneWidget);
    expect(find.text('240.50 AFN'), findsNWidgets(3));
    expect(find.text('Cash'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('View Payment'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Payment details'), findsOneWidget);
    expect(find.text('Allocated from this payment'), findsOneWidget);
    expect(find.text('759.50 AFN'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Open Bill'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsNothing);
    expect(find.byType(PaymentsScreen), findsOneWidget);
    expect(find.text('Bill 00125'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(640, 900);
    await tester.pumpWidget(
      MaterialApp(
        key: const ValueKey('rtl'),
        locale: const Locale('ps'),
        supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(body: PaymentsScreen(database: database)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('00125'), findsOneWidget);
    expect(find.text('R-0000001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
