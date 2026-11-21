import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/reports/report_service.dart';
import 'package:tailor_shop/screens/suppliers/fabric_purchase_screen.dart';
import 'package:tailor_shop/screens/suppliers/widgets/purchase_invoice_line_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late int supplierId;
  late List<int> fabricIds;
  final captureKey = GlobalKey();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (const bool.fromEnvironment('CAPTURE_PURCHASE')) {
      for (final family in ['Roboto', 'NotoSansArabic', 'Ahem']) {
        await (FontLoader(
          family,
        )..addFont(rootBundle.load('assets/fonts/NotoSansArabic.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    supplierId = await database.addSupplier(
      name: 'Kabul Cotton House',
      phone: '0700123456',
      openingBalance: 30000,
    );
    fabricIds = [];
    for (final (name, color, category, cost) in [
      ('White Cotton', 'White', 'Clothing Fabric', 12000),
      ('Navy Wool', 'Navy', 'Waistcoat / Coat Fabric', 25000),
      ('Cream Linen', 'Cream', 'Clothing Fabric', 18000),
      ('Grey Suiting', 'Grey', 'Waistcoat / Coat Fabric', 30000),
      ('Blue Cotton', 'Blue', 'Clothing Fabric', 15000),
    ]) {
      fabricIds.add(
        await database.addFabric(
          name: name,
          color: color,
          category: category,
          unit: 'meter',
          cost: cost,
          price: cost + 5000,
          lowStock: 0,
        ),
      );
    }
  });
  tearDown(() async => database.db.close());

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
  Finder quantityFields() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        widget.focusNode != null &&
        widget.decoration?.suffixText == 'm',
  );
  Finder amount(String key) => find
      .descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text))
      .last;

  void checkErrors(WidgetTester tester) {
    final error = tester.takeException();
    expect(
      error,
      isNull,
      reason: error is FlutterError
          ? error.diagnostics.map((e) => e.toStringDeep()).join('\n')
          : '$error',
    );
  }

  Future<void> settleDatabase(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 160)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPage(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    bool dark = false,
    int? draftId,
    int? selectedSupplier,
    int? initialFabric,
    FabricPurchasePrinter? printer,
  }) async {
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: LocaleController.supportedLocales,
        theme: dark ? buildDarkAppTheme() : buildAppTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) =>
            RepaintBoundary(key: captureKey, child: child!),
        home: FabricPurchaseScreen(
          database: database,
          supplierId: selectedSupplier,
          draftId: draftId,
          fabricId: initialFabric,
          printInvoice: printer ?? (_, _, {required locale}) async => true,
        ),
      ),
    );
    await settleDatabase(tester);
    checkErrors(tester);
  }

  Future<void> addFabric(WidgetTester tester, int id) async {
    final card = find.byKey(ValueKey('purchase-fabric-$id'));
    final list = find
        .descendant(
          of: find.byKey(const PageStorageKey('supplier-purchase-fabrics')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(list).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(card, 180, scrollable: list);
    final button = find.descendant(of: card, matching: find.byType(TextButton));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PURCHASE')) return;
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 1);
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final directory = await Directory('artifacts/purchase-redesign')
          .create(recursive: true);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    for (final dark in [false, true]) {
      testWidgets(
        'purchase panels, footer, and entries survive scaling in $locale dark=$dark',
        (tester) async {
          final draftId = (await tester.runAsync(
            () => database.saveFabricPurchaseDraft(
              supplierId: supplierId,
              date: CalendarService.shopToday(),
              discount: 5000,
              extraCost: 2000,
              plannedPayment: 200000,
              invoiceReference: 'SUP-00017',
              lines: [
                for (var index = 0; index < 3; index++)
                  {
                    'fabric_id': fabricIds[index],
                    'quantity': index == 0 ? 100.0 : 2.5,
                    'unit_cost': [12000, 25000, 18000][index],
                  },
              ],
            ),
          ))!;
          await openPage(tester, locale: locale, dark: dark, draftId: draftId);
          for (final (size, dpi) in const [
            (Size(1280, 720), 1.0),
            (Size(1366, 768), 1.0),
            (Size(1920, 1080), 1.0),
            (Size(1280, 720), 1.25),
            (Size(1366, 768), 1.5),
            (Size(1280, 720), 1.5),
            (Size(1366, 768), 2.0),
          ]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = dpi;
            await tester.pumpAndSettle();
            final small = size.width / dpi < 1000;
            if (small &&
                find
                    .byKey(const ValueKey('purchase-footer'))
                    .evaluate()
                    .isEmpty) {
              // The second navigation tab opens the invoice in a narrow window.
              final tab = find.byType(OutlinedButton).first;
              await tester.tap(tab);
              await tester.pumpAndSettle();
            }
            expect(quantityFields(), findsNWidgets(3));
            expect(
              tester.widget<TextField>(quantityFields().first).controller!.text,
              '100.0',
            );
            expect(
              tester
                  .widget<TextField>(quantityFields().first)
                  .focusNode!
                  .hasFocus,
              isFalse,
            );
            if (!small) {
              final left = tester.getRect(
                find.byKey(const ValueKey('purchase-fabric-panel')),
              );
              final right = tester.getRect(
                find.byKey(const ValueKey('purchase-invoice-panel')),
              );
              expect(left.right, lessThan(right.left));
              expect(right.width, greaterThan(left.width));
            }
            final footer = tester.getRect(
              find.byKey(const ValueKey('purchase-footer')),
            );
            expect(
              tester
                  .getRect(find.byKey(const ValueKey('purchase-remaining')))
                  .bottom,
              lessThanOrEqualTo(footer.bottom),
            );
            expect(
              find.byKey(const ValueKey('purchase-confirm')).hitTestable(),
              findsOneWidget,
            );
            checkErrors(tester);
            if (dpi == 1 && size.width != 1920 ||
                dpi == 1.5 && size.width == 1280) {
              await capture(
                tester,
                '${locale.languageCode}-${dark ? 'dark' : 'light'}-${size.width.toInt()}-$dpi',
              );
            }
          }
        },
      );
    }
  }

  testWidgets(
    'adding a fabric again focuses its edited line without changing quantity',
    (tester) async {
      await openPage(tester, selectedSupplier: supplierId);
      await addFabric(tester, fabricIds.first);
      await tester.enterText(field('Quantity (meters)'), '100');
      await tester.enterText(field('Actual buying price / meter'), '125');
      await addFabric(tester, fabricIds[1]);
      await addFabric(tester, fabricIds.first);
      expect(find.byType(PurchaseInvoiceLineCard), findsNWidgets(2));
      final cotton = tester.widget<TextField>(quantityFields().first);
      expect(cotton.controller!.text, '100');
      expect(cotton.focusNode!.hasFocus, isTrue);
      expect(
        cotton.controller!.selection.textInside(cotton.controller!.text),
        '100',
      );
      checkErrors(tester);
    },
  );

  testWidgets(
    'supplier search closes after choosing a phone and preserves invoice entries',
    (tester) async {
      await openPage(tester, initialFabric: fabricIds.first);
      await tester.enterText(field('Quantity (meters)'), '100');
      final picker = find.byKey(const ValueKey('purchase-supplier-picker'));
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('purchase-supplier-search')),
        '070012',
      );
      await tester.pumpAndSettle();
      expect(find.text('0700123456'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Kabul Cotton House'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.byKey(const ValueKey('purchase-supplier-search')),
        findsNothing,
      );
      expect(
        tester.widget<TextField>(field('Quantity (meters)')).controller!.text,
        '100',
      );
      expect(find.textContaining('Existing payable: 300 AFN'), findsOneWidget);
      checkErrors(tester);
    },
  );

  testWidgets(
    '100 meters at 120 AFN posts once and print failure can retry safely',
    (tester) async {
      var printCalls = 0;
      final printedNumbers = <String>[];
      await openPage(
        tester,
        selectedSupplier: supplierId,
        initialFabric: fabricIds.first,
        printer: (_, number, {required locale}) async {
          printCalls++;
          printedNumbers.add(number);
          if (printCalls == 1) throw StateError('Printer unavailable');
          return true;
        },
      );
      await tester.enterText(field('Quantity (meters)'), '100');
      await tester.ensureVisible(field('Amount paid now'));
      await tester.enterText(field('Amount paid now'), '2000');
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(amount('purchase-grand-total')).data,
        '12,000 AFN',
      );
      expect(
        tester.widget<Text>(amount('purchase-remaining')).data,
        '10,000 AFN',
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Confirm & print'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      // Rapid repeat commands are ignored while the review is open.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('purchase-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirm purchase').last,
      );
      await settleDatabase(tester);
      expect(printCalls, 1);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reprint'));
      await settleDatabase(tester);
      expect(printCalls, 2);
      expect(printedNumbers.toSet(), hasLength(1));
      await tester.runAsync(() async {
        expect(
          (await database.db.query('fabric_purchases')).single['total'],
          1200000,
        );
        expect(
          (await database.fabrics()).singleWhere(
            (row) => row['id'] == fabricIds.first,
          )['on_hand'],
          100,
        );
        expect((await database.suppliers()).single['balance'], 1030000);
        expect(
          (await database.db.query(
            'stock_movements',
            where: "source_type='purchase'",
          )).length,
          1,
        );
        expect(
          (await database.supplierLedger(supplierId))
              .where((row) => row['description'] == 'Fabric purchase')
              .length,
          1,
        );
        expect(await database.db.query('fabric_sales'), isEmpty);
        final today = CalendarService.shopToday()
            .toIso8601String()
            .split('T')
            .first;
        final report = await ReportService(database)
            .generate(fromDate: today, throughDate: today);
        final profit = (report['sections'] as Map)['profit'] as Map;
        expect(profit['fabric_profit'], 0);
        expect(profit['gross_profit'], 0);
      });
      checkErrors(tester);
    },
  );

  testWidgets(
    'invalid item entries stay in place beside localized validation messages',
    (tester) async {
      await openPage(
        tester,
        selectedSupplier: supplierId,
        initialFabric: fabricIds.first,
      );
      await tester.enterText(field('Quantity (meters)'), '2.1234');
      await tester.enterText(field('Actual buying price / meter'), 'invalid');
      await tester.tap(find.byKey(const ValueKey('purchase-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a positive quantity with up to three decimals.'),
        findsOneWidget,
      );
      expect(
        find.text('Enter a valid buying price per meter.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(field('Quantity (meters)')).controller!.text,
        '2.1234',
      );
      expect(
        tester
            .widget<TextField>(field('Actual buying price / meter'))
            .controller!
            .text,
        'invalid',
      );
      await tester.runAsync(() async {
        expect(await database.db.query('fabric_purchases'), isEmpty);
      });
      checkErrors(tester);
    },
  );

  testWidgets('save failure keeps the invoice and a retry posts it once', (
    tester,
  ) async {
    await openPage(
      tester,
      selectedSupplier: supplierId,
      initialFabric: fabricIds.first,
    );
    await tester.enterText(field('Quantity (meters)'), '100');
    await tester.runAsync(() => database.archiveSupplier(supplierId));
    await tester.tap(find.byKey(const ValueKey('purchase-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Confirm purchase').last,
    );
    await settleDatabase(tester);
    expect(find.byKey(const ValueKey('purchase-save-error')), findsOneWidget);
    expect(
      tester.widget<TextField>(field('Quantity (meters)')).controller!.text,
      '100',
    );
    await tester.runAsync(() async {
      expect(await database.db.query('fabric_purchases'), isEmpty);
      expect(
        (await database.fabrics()).singleWhere(
          (row) => row['id'] == fabricIds.first,
        )['on_hand'],
        0,
      );
      await database.archiveSupplier(supplierId, archived: false);
    });
    await tester.tap(find.byKey(const ValueKey('purchase-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Confirm purchase').last,
    );
    await settleDatabase(tester);
    await tester.runAsync(() async {
      expect(find.byKey(const ValueKey('purchase-save-error')), findsNothing);
      expect(await database.db.query('fabric_purchases'), hasLength(1));
      expect(
        (await database.fabrics()).singleWhere(
          (row) => row['id'] == fabricIds.first,
        )['on_hand'],
        100,
      );
    });
    checkErrors(tester);
  });

  testWidgets(
    'draft reload preserves money precision without posting inventory',
    (tester) async {
      final draftId = (await tester.runAsync(
        () => database.saveFabricPurchaseDraft(
          supplierId: supplierId,
          date: CalendarService.shopToday(),
          lines: [
            {'fabric_id': fabricIds.first, 'quantity': 2.5, 'unit_cost': 12000},
          ],
          discount: 5050,
          extraCost: 2050,
          plannedPayment: 10000,
        ),
      ))!;
      await openPage(tester, draftId: draftId);
      expect(
        tester
            .widget<TextField>(field('Discount (fixed AFN)'))
            .controller!
            .text,
        '50.50',
      );
      expect(
        tester
            .widget<TextField>(field('Purchase-related costs'))
            .controller!
            .text,
        '20.50',
      );
      expect(
        tester.widget<Text>(amount('purchase-grand-total')).data,
        '270 AFN',
      );
      expect(tester.widget<Text>(amount('purchase-remaining')).data, '170 AFN');
      await tester.runAsync(() async {
        expect((await database.fabrics()).first['on_hand'], 0);
        expect(
          (await database.supplierLedger(supplierId)).length,
          1,
        ); // Opening balance only.
        expect(
          (await database.db.query('fabric_purchases')).single['status'],
          'Draft',
        );
      });
      checkErrors(tester);
    },
  );

  testWidgets(
    'payment shortcuts respect existing advance and allow partial or credit payment',
    (tester) async {
      final advanceSupplier = (await tester.runAsync(() async {
        final id = await database.addSupplier(name: 'Advance Supplier');
        await database.recordSupplierPayment(
          supplierId: id,
          amount: 50000,
          date: CalendarService.shopToday(),
          method: 'Cash',
          allocations: const {},
        );
        return id;
      }))!;
      await openPage(
        tester,
        selectedSupplier: advanceSupplier,
        initialFabric: fabricIds.first,
      );
      await tester.enterText(field('Quantity (meters)'), '10');
      final apply = find.byType(CheckboxListTile);
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.pumpAndSettle();
      final payFull = find.byKey(const ValueKey('purchase-pay-full'));
      await tester.ensureVisible(payFull);
      await tester.tap(payFull);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Amount paid now')).controller!.text,
        '700.00',
      );
      expect(tester.widget<Text>(amount('purchase-remaining')).data, '0 AFN');
      await tester.enterText(field('Amount paid now'), '200');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(amount('purchase-remaining')).data, '500 AFN');
      final credit = find.byKey(const ValueKey('purchase-buy-credit'));
      await tester.ensureVisible(credit);
      await tester.tap(credit);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field('Amount paid now')).controller!.text,
        '0',
      );
      expect(tester.widget<CheckboxListTile>(apply).value, isFalse);
      expect(
        tester.widget<Text>(amount('purchase-remaining')).data,
        '1,200 AFN',
      );
      checkErrors(tester);
    },
  );
}
