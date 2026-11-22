import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/expenses/expenses_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    await database.addExpense(
      category: 'Transport',
      amount: 100000,
      description: 'Taxi to the market',
      date: DateTime.now(),
      method: 'Cash',
    );
  });

  tearDown(() async => database.db.close());

  for (final size in const [Size(390, 844), Size(800, 900), Size(1280, 800)]) {
    testWidgets('expenses screen fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(const Locale('en'), database));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Expenses'), findsWidgets);
      expect(find.text('Add expense'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.text('Taxi to the market'),
        400,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Taxi to the market'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Add expense').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add expense').first);
      await tester.pumpAndSettle();
      expect(find.text('Amount *'), findsOneWidget);
      expect(find.text('Save expense'), findsOneWidget);
      expect(find.text('Transport'), findsWidgets);
      expect(find.text('Cash'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expenses screen fits a Pashto laptop window', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1.25;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(const Locale('ps'), database, textScale: 1.2));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(find.text('لګښتونه'), findsWidgets);
    expect(find.text('لګښت زیاتول'), findsWidgets);
    await tester.tap(find.text('لګښت زیاتول').first);
    await tester.pumpAndSettle();
    expect(find.text('مبلغ *'), findsOneWidget);
    expect(find.text('لګښت ساتل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Locale locale, ShopDatabase database, {double textScale = 1}) =>
    MaterialApp(
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
      home: Scaffold(body: ExpensesScreen(database: database)),
    );
