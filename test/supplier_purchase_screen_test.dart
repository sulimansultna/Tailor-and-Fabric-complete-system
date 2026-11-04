import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/suppliers/fabric_purchase_screen.dart';

void main() {
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    await database.addSupplier(name: 'Cotton House', phone: '0700123456');
    await database.addFabric(
      name: 'White Cotton',
      color: 'White',
      unit: 'meter',
      cost: 100,
      price: 180,
      lowStock: 0,
    );
  });

  tearDown(() async => database.db.close());

  for (final size in [
    const Size(390, 800),
    const Size(800, 600),
    const Size(1440, 900),
  ]) {
    testWidgets('purchase form lays out at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            TailorShopCupertinoLocalizationsDelegate.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supportedLocales,
          home: FabricPurchaseScreen(database: database),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.text('Purchase Fabric'), findsOneWidget);
      if (size.width < 1000) {
        await tester.tap(find.text('View invoice (0)'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Confirm purchase'), findsOneWidget);
      expect(find.text('Confirm & print'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('purchase screen preselects the requested fabric', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fabricId =
        (await tester.runAsync(() => database.fabrics()))!.single['id'] as int;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: LocaleController.supportedLocales,
        home: FabricPurchaseScreen(database: database, fabricId: fabricId),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final quantityField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Quantity (meters)',
    );
    expect(quantityField, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'supplier setup keeps invoice entries and posts decimal quantity',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            TailorShopCupertinoLocalizationsDelegate.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: LocaleController.supportedLocales,
          home: FabricPurchaseScreen(database: database),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      Finder textField(String label) => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == label,
      );

      await tester.tap(find.text('Waistcoat / coat fabric'));
      await tester.pumpAndSettle();
      expect(find.text('White Cotton'), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('White Cotton'), findsOneWidget);

      await tester.enterText(
        textField('Search fabric by name, code, or color'),
        'White Cotton',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to invoice'));
      await tester.pumpAndSettle();

      await tester.enterText(textField('Quantity (meters)'), '2.5');
      await tester.enterText(textField('Actual buying price / meter'), '150');
      await tester.pumpAndSettle();
      expect(find.textContaining('375'), findsWidgets);

      for (final (size, dpi) in const [
        (Size(1280, 720), 1.5),
        (Size(1366, 768), 1.25),
        (Size(1920, 1080), 1.0),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpi;
        await tester.pumpAndSettle();
        if (size.width / dpi < 1000 &&
            find.text('View invoice (1)').evaluate().isNotEmpty) {
          await tester.tap(find.text('View invoice (1)'));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<TextField>(textField('Quantity (meters)'))
              .controller!
              .text,
          '2.5',
        );
        expect(
          tester
              .widget<TextField>(textField('Actual buying price / meter'))
              .controller!
              .text,
          '150',
        );
        expect(find.text('Confirm purchase').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.byTooltip('Add supplier'));
      await tester.pumpAndSettle();
      await tester.enterText(textField('Supplier *').last, 'New Supplier');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(textField('Amount paid now'), '100');
      await tester.tap(find.text('Confirm purchase'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm purchase').last,
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();

      final fabric = (await tester.runAsync(() => database.fabrics()))!
          .singleWhere((row) => row['name'] == 'White Cotton');
      final supplier = (await tester.runAsync(() => database.suppliers()))!
          .singleWhere((row) => row['name'] == 'New Supplier');
      expect(fabric['on_hand'], 2.5);
      expect(supplier['balance'], 27500);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new fabric from purchase is created with zero stock', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: LocaleController.supportedLocales,
        home: FabricPurchaseScreen(database: database),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add fabric'));
    await tester.pumpAndSettle();
    final nameField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Fabric *',
    );
    await tester.enterText(nameField, 'New Indigo Fabric');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final created = (await tester.runAsync(() => database.fabrics()))!
        .singleWhere((row) => row['name'] == 'New Indigo Fabric');
    expect(created['on_hand'], 0);
    expect(find.text('New Indigo Fabric'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchase form presents Pashto text and RTL direction', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ps'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: LocaleController.supportedLocales,
        home: FabricPurchaseScreen(database: database),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final title = find.text(
      '\u062f \u067c\u0648\u06a9\u0631 \u067e\u06d0\u0631\u0648\u062f',
    );
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
