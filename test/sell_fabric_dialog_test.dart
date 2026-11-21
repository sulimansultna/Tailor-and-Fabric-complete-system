import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/dashboard/widgets/sell_fabric_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late String databasePath;
  late int cottonId;
  late int silkId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databasePath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'sell_fabric_${DateTime.now().microsecondsSinceEpoch}.db';
    database = await ShopDatabase.openAt(databasePath);
    cottonId = await database.addFabric(
      name: 'White Cotton',
      code: 'COT-A',
      color: 'White',
      unit: 'meter',
      cost: 15000,
      price: 20000,
      lowStock: 1,
      openingQuantity: 20,
    );
    silkId = await database.addFabric(
      name: 'Blue Silk',
      code: 'SILK-B',
      color: 'Blue',
      unit: 'meter',
      cost: 25000,
      price: 35000,
      lowStock: 1,
      openingQuantity: 8,
    );
    final archivedId = await database.addFabric(
      name: 'Archived Silk',
      code: 'SILK-OLD',
      color: 'Grey',
      unit: 'meter',
      cost: 10000,
      price: 15000,
      lowStock: 1,
      openingQuantity: 10,
    );
    await database.db.update(
      'fabrics',
      {'archived': 1},
      where: 'id=?',
      whereArgs: [archivedId],
    );
  });

  tearDown(() async {
    await database.db.close();
    final file = File(databasePath);
    if (await file.exists()) await file.delete();
  });

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  void expectNoLayoutErrors(WidgetTester tester) {
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? exception.diagnostics.map((node) => node.toStringDeep()).join('\n')
          : '$exception',
    );
  }

  Future<AppLocalizations> openSale(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Size size = const Size(800, 700),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSellFabricDialog(
                context,
                database,
                initialFabricId: cottonId,
              ),
              child: const Text('Open sale'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sale'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expectNoLayoutErrors(tester);
    return AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
  }

  Future<void> openPicker(WidgetTester tester) async {
    final selector = find.byKey(const ValueKey('sell-fabric-selector'));
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
  }

  testWidgets('search by ID, code, or name selects the fabric that is sold', (
    tester,
  ) async {
    final l10n = await openSale(tester);
    await openPicker(tester);
    final search = find.byKey(const ValueKey('sell-fabric-search'));
    final picker = find.byType(AlertDialog).last;
    final results = find.descendant(
      of: picker,
      matching: find.byType(ListTile),
    );
    expect(results, findsNWidgets(2));

    final localizedId = silkId
        .toString()
        .split('')
        .map((digit) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(digit)])
        .join();
    for (final query in [' silk-b ', 'bLuE sILk', '$silkId', localizedId]) {
      await tester.enterText(search, query);
      await tester.pumpAndSettle();
      expect(results, findsOneWidget, reason: 'Search: $query');
      expect(
        find.descendant(
          of: results,
          matching: find.text('SILK-B · Blue Silk · Blue'),
        ),
        findsOneWidget,
      );
    }

    await tester.enterText(search, 'no matching fabric');
    await tester.pumpAndSettle();
    expect(find.text(l10n.fabricSearchEmpty), findsOneWidget);
    expect(results, findsNothing);
    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(results, findsNWidgets(2));
    await tester.enterText(search, 'SILK-B');
    await tester.pumpAndSettle();
    await tester.tap(results);
    await tester.pumpAndSettle();

    expect(find.text('SILK-B · Blue Silk · Blue'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(field(l10n.fabricFormSellingPrice))
          .controller!
          .text,
      '350',
    );
    expect(find.text(l10n.reportFieldCostRate), findsNothing);
    expect(find.text(l10n.reportFieldRecordedCost), findsNothing);
    expect(find.text(l10n.reportColumnFabricProfit), findsNothing);
    await tester.enterText(field(l10n.reportFieldQuantityMeters), '2');
    await tester.enterText(field(l10n.paidNow), '700');
    await tester.ensureVisible(find.text(l10n.recordSale));
    await tester.tap(find.text(l10n.recordSale));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.runAsync(() async {
      final line = (await database.db.query('fabric_sale_lines')).single;
      expect(line['fabric_id'], silkId);
      expect(line['unit_price'], 35000);
      expect(line['quantity_milli'], 2000);
      final fabrics = await database.fabrics();
      expect(fabrics.singleWhere((row) => row['id'] == silkId)['available'], 6);
      expect(
        fabrics.singleWhere((row) => row['id'] == cottonId)['available'],
        20,
      );
    });
  });

  testWidgets(
    'cancelling a fabric search preserves selection and edited price',
    (tester) async {
      final l10n = await openSale(tester);
      await tester.enterText(field(l10n.fabricFormSellingPrice), '225');
      for (final query in ['Silk', 'no matching fabric']) {
        await openPicker(tester);
        await tester.enterText(
          find.byKey(const ValueKey('sell-fabric-search')),
          query,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog).last,
            matching: find.widgetWithText(TextButton, l10n.cancel),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('COT-A · White Cotton · White'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(field(l10n.fabricFormSellingPrice))
              .controller!
              .text,
          '225',
        );
      }
    },
  );

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('fabric search fits a small screen and keyboard in $locale', (
      tester,
    ) async {
      final l10n = await openSale(
        tester,
        locale: locale,
        size: const Size(390, 640),
      );
      await openPicker(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('sell-fabric-search')),
        'SILK',
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.fabricSearchHint), findsOneWidget);
      final result = find.descendant(
        of: find.byType(AlertDialog).last,
        matching: find.byType(ListTile),
      );
      expect(result, findsOneWidget);
      expectNoLayoutErrors(tester);
      await tester.tap(result);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('SILK-B · Blue Silk · Blue'), findsOneWidget);
      expectNoLayoutErrors(tester);
    });
  }
}
