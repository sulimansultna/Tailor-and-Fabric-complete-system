import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/reports/report_service.dart';
import 'package:tailor_shop/screens/reports/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late String path;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    path =
        '${Directory.systemTemp.path}${Platform.pathSeparator}reports_${DateTime.now().microsecondsSinceEpoch}.db';
    database = await ShopDatabase.openAt(path);
  });

  tearDown(() async {
    await database.db.close();
    final file = File(path);
    if (await file.exists()) await file.delete();
  });

  for (final size in const [Size(800, 600), Size(1440, 900)]) {
    testWidgets('reports fit $size and generate a period snapshot', (
      tester,
    ) async {
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
          home: Scaffold(body: ReportsScreen(service: ReportService(database))),
        ),
      );
      await tester.tap(find.text('Generate Report').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsWidgets);
      expect(
        find.textContaining('Total fabric profit + Net Stitching Revenue'),
        findsOneWidget,
      );
      await tester.tap(find.text('Stitching Report').first);
      await tester.pumpAndSettle();
      expect(find.text('Stitching Report'), findsWidgets);
      expect(find.text('Net Stitching Revenue'), findsOneWidget);
      await tester.tap(find.text('Fabric Report').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Report').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total meters sold'), findsOneWidget);
      await tester.tap(find.text('Sales Transactions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('source-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Direct Fabric Sales').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Needs regeneration'), findsNothing);
      expect(
        find.text('No activity in this period, or no rows match the search.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('source-all')), findsOneWidget);
      await tester.tap(find.text('Generate Report').first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Needs regeneration'), findsNothing);
      await tester.enterText(find.byType(TextField).last, 'no matching fabric');
      await tester.pumpAndSettle();
      expect(
        find.text('No activity in this period, or no rows match the search.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('filtered fabric print includes every matching transaction', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = CalendarService.shopToday();
    late int customerId;
    late int otherCustomerId;
    late int fabricId;
    await tester.runAsync(() async {
      customerId = await database.addCustomer(
        name: 'Filtered Report Customer',
        phone: '0700999000',
      );
      otherCustomerId = await database.addCustomer(
        name: 'Other Report Customer',
        phone: '0700888000',
      );
      fabricId = await database.addFabric(
        name: 'Report Cotton',
        color: 'Navy',
        unit: 'meter',
        cost: 10000,
        price: 20000,
        lowStock: 0,
        openingQuantity: 13,
        openingDate: today.subtract(const Duration(days: 1)),
      );
      await database.db.transaction((txn) async {
        for (var index = 0; index < 12; index++) {
          final saleNumber =
              'FILTERED-PRINT-${index.toString().padLeft(2, '0')}';
          final saleId = await txn.insert('fabric_sales', {
            'number': saleNumber,
            'bill_number': saleNumber,
            'customer_id': customerId,
            'date': today.toIso8601String(),
            'total': 20000,
            'paid': 20000,
            'cost_total': 10000,
            'status': 'Posted',
          });
          await txn.insert('fabric_sale_lines', {
            'sale_id': saleId,
            'fabric_id': fabricId,
            'quantity': 1.0,
            'quantity_milli': 1000,
            'unit_price': 20000,
            'unit_cost': 10000,
            'line_total': 20000,
          });
        }
        const saleNumber = 'UNFILTERED-PRINT';
        final saleId = await txn.insert('fabric_sales', {
          'number': saleNumber,
          'bill_number': saleNumber,
          'customer_id': otherCustomerId,
          'date': today.toIso8601String(),
          'total': 20000,
          'paid': 20000,
          'cost_total': 10000,
          'status': 'Posted',
        });
        await txn.insert('fabric_sale_lines', {
          'sale_id': saleId,
          'fabric_id': fabricId,
          'quantity': 1.0,
          'quantity_milli': 1000,
          'unit_price': 20000,
          'unit_cost': 10000,
          'line_total': 20000,
        });
      });
    });
    String? printedHtml;
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
        home: Scaffold(
          body: ReportsScreen(
            service: ReportService(database),
            printHandler: (html, {required savePdf}) async {
              printedHtml = html;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Generate Report').first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fabric Report').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Filtered Report Customer',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print Full Report'));
    await tester.pumpAndSettle();

    expect(printedHtml, isNotNull);
    for (var index = 0; index < 12; index++) {
      expect(
        printedHtml,
        contains('FILTERED-PRINT-${index.toString().padLeft(2, '0')}'),
      );
    }
    expect(printedHtml, isNot(contains('UNFILTERED-PRINT')));
    expect(printedHtml, contains('Filtered Report Customer'));
    expect(printedHtml, contains('Filters'));
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('reports use RTL for $locale', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
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
          home: Scaffold(body: ReportsScreen(service: ReportService(database))),
        ),
      );
      await tester.pumpAndSettle();
      final screen = tester.element(find.byType(ReportsScreen));
      expect(Directionality.of(screen), TextDirection.rtl);
      final l10n = AppLocalizations.of(screen)!;
      await tester.tap(find.text(l10n.reportGenerate).first);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
