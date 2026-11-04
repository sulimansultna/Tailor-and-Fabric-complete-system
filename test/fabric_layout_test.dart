import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/fabric/fabric_screen.dart';

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
        'fabric_layout_${DateTime.now().microsecondsSinceEpoch}.db';
    database = await ShopDatabase.openAt(databasePath);
    await database.addFabric(
      name: 'White Cotton',
      code: 'FAB-001',
      category: 'Clothing Fabric',
      color: 'White',
      unit: 'meter',
      cost: 15000,
      price: 20000,
      lowStock: 10,
      openingQuantity: 100,
    );
  });

  tearDown(() async {
    await database.db.close();
    final file = File(databasePath);
    if (await file.exists()) await file.delete();
  });

  for (final size in const [
    Size(390, 640),
    Size(800, 600),
    Size(1440, 500),
    Size(1440, 900),
  ]) {
    testWidgets('fabric inventory fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [
            Locale('en'),
            Locale('ps'),
            Locale('fa', 'AF'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            TailorShopCupertinoLocalizationsDelegate.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: Scaffold(body: FabricScreen(database: database)),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      expect(find.text('White Cotton'), findsWidgets);
      final exception = tester.takeException();
      final diagnostics = exception is FlutterError
          ? exception.diagnostics.map((node) => node.toStringDeep()).join('\n')
          : '$exception';
      expect(exception, isNull, reason: diagnostics);
    });
  }

  testWidgets('fabric inventory supports Pashto RTL layout', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ps'),
        supportedLocales: const [
          Locale('en'),
          Locale('ps'),
          Locale('fa', 'AF'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: FabricScreen(database: database)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(FabricScreen))),
      TextDirection.rtl,
    );
    expect(find.text('White Cotton'), findsWidgets);
    expect(find.text('د ټوکر کوډ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fabric summary uses available stock and average cost', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [
          Locale('en'),
          Locale('ps'),
          Locale('fa', 'AF'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: FabricScreen(database: database)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('100 Meter'), findsOneWidget);
    expect(find.textContaining('15,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fabric inventory keeps fractional meters and AFN prices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => database.addFabric(
        name: 'Cotton Blend',
        code: 'FAB-002',
        category: 'Clothing Fabric',
        color: 'Blue',
        unit: 'meter',
        cost: 15050,
        price: 20075,
        lowStock: 1,
        openingQuantity: 2.375,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [
          Locale('en'),
          Locale('ps'),
          Locale('fa', 'AF'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(body: FabricScreen(database: database)),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cotton Blend'), findsWidgets);
    expect(find.text('2.375'), findsNWidgets(2));
    expect(find.textContaining('150.50'), findsOneWidget);
    expect(find.textContaining('200.75'), findsOneWidget);
    expect(find.textContaining('50.25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
