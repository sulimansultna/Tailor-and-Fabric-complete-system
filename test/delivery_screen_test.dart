import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/reports/order_payment_receipt_service.dart';
import 'package:tailor_shop/screens/delivery/delivery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late int orderId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    final customerId = await database.addCustomer(
      name: 'Amina Rahimi',
      phone: '0700 123 456',
    );
    await database.createOrder(
      customerId: customerId,
      total: 240000,
      advance: 40000,
      billNumber: '00002',
      dueDate: CalendarService.shopToday().toIso8601String(),
      notes: 'Blue lining',
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 2,
          'measurement_snapshot': '{}',
          'price_each': 100000,
        },
        {
          'garment': 'coat',
          'quantity': 1,
          'measurement_snapshot': '{}',
          'price_each': 40000,
        },
      ],
    );
    orderId = (await database.db.query('orders')).single['id'] as int;
    await database.updateOrderStatus(orderId, 'Cutting');
    await database.updateOrderStatus(orderId, 'Stitching');
    await database.updateOrderStatus(orderId, 'Ready');
    final workerId = await database.addWorker(
      name: 'Farid',
      phone: '0700 999 888',
      role: 'Tailor',
      defaultRate: 1000,
    );
    final orderLineId =
        (await database.db.query(
              'order_lines',
              columns: ['id'],
              where: "order_id=? AND garment='shalwar'",
              whereArgs: [orderId],
              limit: 1,
            )).single['id']
            as int;
    await database.assignWorkerWork(
      workerId: workerId,
      orderLineId: orderLineId,
      task: 'Stitching',
      quantity: 1,
      rate: 1000,
      assignedAt: DateTime.now(),
    );
  });

  tearDown(() async {
    await database.db.close();
  });

  test('receipt action handles orders without saved payments', () async {
    final result = await printLatestOrderPaymentReceipt(database, {
      'id': -1,
    }, locale: 'ps');
    expect(result, isNull);
  });

  testWidgets('ready orders show garments and preserve debt on delivery', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(const Locale('en'), database));

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );

    await tester.pump();

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );

    expect(find.text('00002'), findsOneWidget);
    expect(find.text('Amina Rahimi'), findsOneWidget);
    expect(find.text('Shalwar Kameez'), findsWidgets);
    expect(find.text('Coat'), findsWidgets);
    expect(find.textContaining('Farid'), findsWidgets);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('× 2'), findsOneWidget);
    expect(find.text('Paid'), findsWidgets);
    expect(find.text('Remaining'), findsWidgets);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Print work ticket'), findsOneWidget);
    expect(find.text('Print receipt'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Deliver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Deliver'));

    await _pumpDeliveryDialog(tester);

    expect(
      find.textContaining('Delivering on credit keeps the debt'),
      findsOneWidget,
    );
    expect(find.text('Receive payment'), findsOneWidget);
    await tester.tap(find.text('Cancel'));

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final afterCancel = await tester.runAsync(
      () => database.db.query(
        'orders',
        columns: ['status', 'paid'],
        where: 'id=?',
        whereArgs: [orderId],
      ),
    );
    expect(afterCancel!.single, {'status': 'Ready', 'paid': 40000});

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Deliver'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Deliver'));

    await _pumpDeliveryDialog(tester);

    await tester.tap(find.text('Confirm delivery on credit'));

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    final afterDelivery = await tester.runAsync(
      () => database.db.query(
        'orders',
        columns: ['status', 'paid'],
        where: 'id=?',
        whereArgs: [orderId],
      ),
    );
    expect(afterDelivery!.single, {'status': 'Delivered', 'paid': 40000});
    final deliveredRows = await tester.runAsync(
      () => database.db.query(
        'order_status_history',
        where: "order_id=? AND status='Delivered'",
        whereArgs: [orderId],
      ),
    );
    final deliveredEvent = deliveredRows!.single;
    expect(deliveredEvent['changed_at'], isNotNull);
    expect(find.text('00002'), findsNothing);
  });

  testWidgets('narrow Pashto layout supports larger text', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _app(const Locale('ps'), database, boardView: false, textScale: 1.4),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(DeliveryScreen)),
    )!;
    expect(find.text(l10n.deliveryBoard), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Amina Rahimi'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Amina Rahimi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDeliveryDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump();
}

Widget _app(
  Locale locale,
  ShopDatabase database, {
  bool boardView = true,
  double textScale = 1,
}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa', 'AF')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    TailorShopCupertinoLocalizationsDelegate.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: DeliveryScreen(
      database: database,
      onNavigate: (page, {filter}) {},
      state: DeliveryBoardState()..boardView = boardView,
    ),
  ),
);
