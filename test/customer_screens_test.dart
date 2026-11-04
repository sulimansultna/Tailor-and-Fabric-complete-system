import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/customers/customer_profile_screen.dart';
import 'package:tailor_shop/screens/customers/customers_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    final customerId = await database.addCustomer(
      name: 'Amina Rahimi',
      phone: '0700 123 456',
      phone2: '0799 555 444',
      address: 'Kabul',
      notes: 'Prefers a relaxed fit',
      opening: 125000,
    );
    await database.saveMeasurement(
      customerId: customerId,
      garment: 'shalwar',
      name: 'Winter',
      unit: 'in',
      json: '{"Chest":"40"}',
    );
    await database.createOrder(
      customerId: customerId,
      total: 200000,
      advance: 50000,
      billNumber: '00125',
      dueDate: DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 1,
          'measurement_profile': 'Winter',
          'measurement_snapshot': '{"Chest":"40"}',
          'price_each': 200000,
        },
      ],
    );
    await database.addCustomer(name: 'Bilal Khan', phone: '+93 700 777 888');
  });

  tearDown(() async => database.db.close());

  for (final size in const [Size(390, 844), Size(800, 900), Size(1440, 1000)]) {
    testWidgets('customer list and profile fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(const Locale('en'), database));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Amina Rahimi'), findsOneWidget);
      await tester.tap(find.text('Amina Rahimi'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.byType(CustomerProfileScreen), findsOneWidget);
      expect(find.text('Total billed'), findsOneWidget);
      expect(find.text('Total paid'), findsOneWidget);
      expect(find.text('Shalwar Kameez'), findsWidgets);
      for (
        var attempt = 0;
        attempt < 4 && find.byType(TabBar).evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(
          find.byWidgetPredicate((widget) => widget is CustomScrollView).last,
          const Offset(0, -650),
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(TabBar), findsOneWidget);
      for (
        var attempt = 0;
        attempt < 5 && find.byType(TabBar).evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(
          find.byWidgetPredicate((widget) => widget is CustomScrollView).first,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byType(TabBar));
      await tester.pumpAndSettle();
      expect(find.textContaining('00125'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('customer list search survives an RTL locale rebuild', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_LocaleFixture(database: database));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'C00001');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Amina Rahimi'), findsOneWidget);
    await tester.tap(find.text('Change language'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Amina Rahimi'), findsOneWidget);
    expect(find.text('C00001'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add and edit customer refreshes the visible list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const Locale('en'), database));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add customer').first);
    await tester.pumpAndSettle();
    final addFields = find.byType(TextFormField);
    await tester.enterText(addFields.at(0), 'Mariam Safi');
    await tester.enterText(addFields.at(1), '0700555666');
    await tester.tap(find.text('Save customer'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      await tester.runAsync(() => database.searchCustomers('Mariam')),
      isNotEmpty,
      reason: 'the form should save before refreshing the list',
    );
    await tester.scrollUntilVisible(
      find.text('Mariam Safi'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mariam Safi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit customer'));
    await tester.pumpAndSettle();
    final editFields = find.byType(TextFormField);
    await tester.enterText(editFields.at(0), 'Mariam Safi Updated');
    await tester.tap(find.text('Save customer'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pumpAndSettle();
    expect(
      await tester.runAsync(
        () async =>
            (await database.searchCustomers('Mariam Safi Updated')).length,
      ),
      1,
    );
    await tester.scrollUntilVisible(
      find.text('Mariam Safi Updated'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mariam Safi Updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer screens handle increased text scaling', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const Locale('en'), database, textScale: 1.3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amina Rahimi'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await tester.pump();
    expect(find.byType(CustomerProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('customer ledger tabs fit scaled laptop sizes in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final customer = (await tester.runAsync(
        () => database.searchCustomers('Amina'),
      ))!.single;
      await tester.pumpWidget(
        _app(
          locale,
          database,
          textScale: 1.25,
          home: CustomerProfileScreen(
            database: database,
            customer: customer,
            initialTabIndex: 1,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pumpAndSettle();
      for (
        var attempt = 0;
        attempt < 5 && find.byType(TabBar).evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(
          find.byWidgetPredicate((widget) => widget is CustomScrollView).first,
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byType(TabBar));
      await tester.pumpAndSettle();
      for (final (size, dpi) in const [
        (Size(1280, 720), 1.5),
        (Size(1366, 768), 1.25),
        (Size(1920, 1080), 1.0),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpi;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$size at $dpi in $locale',
        );
      }
    });
  }
}

Widget _app(
  Locale locale,
  ShopDatabase database, {
  double textScale = 1,
  Widget? home,
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
  home: home ?? Scaffold(body: CustomersScreen(database: database)),
);

class _LocaleFixture extends StatefulWidget {
  const _LocaleFixture({required this.database});
  final ShopDatabase database;
  @override
  State<_LocaleFixture> createState() => _LocaleFixtureState();
}

class _LocaleFixtureState extends State<_LocaleFixture> {
  Locale locale = const Locale('en');
  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa', 'AF')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      TailorShopCupertinoLocalizationsDelegate.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => setState(() => locale = const Locale('ps')),
            child: const Text('Change language'),
          ),
          Expanded(child: CustomersScreen(database: widget.database)),
        ],
      ),
    ),
  );
}
