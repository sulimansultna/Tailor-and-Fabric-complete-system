import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/suppliers/fabric_purchase_screen.dart';
import 'package:tailor_shop/screens/suppliers/supplier_ledger_statement.dart';
import 'package:tailor_shop/screens/suppliers/suppliers_screen.dart';
import 'package:tailor_shop/screens/suppliers/widgets/supplier_ledger_view.dart';

List<Map<String, Object?>> _entries() => [
  {
    'id': 5,
    'date': '2026-11-24T14:00:00',
    'reference': 'REV-SP-0002',
    'description': 'Payment reversal: wrong amount',
    'charge': 0,
    'payment': -50000,
  },
  {
    'id': 4,
    'date': '2026-11-24T13:00:00',
    'reference': 'PR-0001',
    'description': 'Purchase return: damaged fabric',
    'charge': 0,
    'payment': 20000,
  },
  {
    'id': 3,
    'date': '2026-11-23T10:00:00',
    'reference': 'SP-0002',
    'description': 'Supplier payment',
    'charge': 0,
    'payment': 150000,
    'payment_voucher': 'BANK-VOUCHER',
    'supplier_bill': 'BILL-017',
    'purchase_number': 'FP-0001',
    'linked_purchase_bills': 'FP-0001 [BILL-017]',
  },
  {
    'id': 2,
    'date': '2026-11-23T10:00:00',
    'reference': 'FP-0001',
    'description': 'Fabric purchase',
    'charge': 200000,
    'payment': 0,
    'supplier_bill': 'BILL-017',
  },
  {
    'id': 1,
    'date': '2026-11-20T08:00:00',
    'reference': 'OPEN-S00001',
    'description': 'Opening balance',
    'charge': 100000,
    'payment': 0,
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (const bool.fromEnvironment('CAPTURE_SUPPLIER_LEDGER')) {
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

  test(
    'statement distinguishes purchases, return credits and payment reversals',
    () {
      final original = _entries();
      final statement = SupplierLedgerStatement(original);
      expect(statement.rows.map((row) => row.data['id']), [1, 2, 3, 4, 5]);
      expect(statement.rows.map((row) => row.balance), [
        100000,
        300000,
        150000,
        130000,
        180000,
      ]);
      expect(statement.openingBalance, 100000);
      expect(statement.totalIncreases, 250000);
      expect(statement.totalDecreases, 170000);
      expect(statement.closingBalance, 180000);
      expect(
        original.first['id'],
        5,
        reason: 'Reading must not reorder source records.',
      );
    },
  );

  test(
    'overpayments remain supplier credit instead of becoming an amount owed',
    () {
      final statement = SupplierLedgerStatement([
        {
          'id': 1,
          'date': '2026-11-20',
          'reference': 'OPEN-S00001',
          'charge': 0,
          'payment': 25000,
        },
        {
          'id': 2,
          'date': '2026-11-21',
          'reference': 'FP-1',
          'charge': 50000,
          'payment': 0,
        },
        {
          'id': 3,
          'date': '2026-11-22',
          'reference': 'SP-1',
          'charge': 0,
          'payment': 50000,
        },
      ]);
      expect(statement.openingBalance, -25000);
      expect(statement.closingBalance, -25000);
      expect(
        statement.totalDecreases,
        50000,
        reason: 'Opening credit is separate from later payments.',
      );
    },
  );

  test('statement preserves minor units and negative charge corrections', () {
    final statement = SupplierLedgerStatement([
      {
        'id': 1,
        'date': '2026-11-20',
        'reference': 'FP-1',
        'charge': 1001,
        'payment': 0,
      },
      {
        'id': 2,
        'date': '2026-11-21',
        'reference': 'CORRECTION',
        'charge': -333,
        'payment': 0,
      },
    ]);
    expect(statement.closingBalance, 668);
    expect(statement.totalDecreases, 333);
  });

  test(
    'legacy opening balance is used only when there are no ledger records',
    () {
      expect(
        SupplierLedgerStatement(
          [],
          fallbackOpeningBalance: -7555,
        ).closingBalance,
        -7555,
      );
      expect(
        SupplierLedgerStatement(
          _entries(),
          fallbackOpeningBalance: 999999,
        ).closingBalance,
        180000,
      );
    },
  );

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets(
      'supplier statement stays readable and search preserves balances in $locale',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          _app(
            locale,
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => showSupplierLedger(
                      context: context,
                      supplier: {
                        'name': 'Kabul Cotton House',
                        'code': 'S00001',
                        'phone': '0700123456',
                      },
                      entries: _entries(),
                    ),
                    child: const Text('Open statement'),
                  ),
                ),
              ),
            ),
            captureKey: captureKey,
          ),
        );
        await tester.tap(find.text('Open statement'));
        await tester.pumpAndSettle();
        for (final (size, dpi) in const [
          (Size(1280, 720), 1.0),
          (Size(1366, 768), 1.25),
          (Size(1280, 720), 1.5),
          (Size(1920, 1080), 1.0),
          (Size(390, 844), 1.0),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = dpi;
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$size at $dpi in $locale',
          );
          expect(
            find
                .byTooltip(
                  AppLocalizations.of(
                    tester.element(find.byType(SupplierLedgerView)),
                  )!.close,
                )
                .hitTestable(),
            findsOneWidget,
          );
          if (const bool.fromEnvironment('CAPTURE_SUPPLIER_LEDGER')) {
            await tester.runAsync(() async {
              final boundary =
                  captureKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final rendered = await boundary.toImage(pixelRatio: 1);
              final bytes = await rendered.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = await Directory('tmp/supplier_ledger_preview')
                  .create(recursive: true);
              await File(
                '${directory.path}/${locale.toLanguageTag()}-${size.width.toInt()}-${dpi}x.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              rendered.dispose();
            });
          }
        }
        tester.view.physicalSize = const Size(1280, 720);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('supplier-ledger-search')),
          'BANK-VOUCHER',
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('supplier-ledger-row-2')),
          findsNothing,
        );
        final balance = find.byKey(const ValueKey('supplier-ledger-balance-3'));
        final expectedMoney = locale.languageCode == 'en' ? '1,500 AFN' : null;
        if (expectedMoney != null) {
          expect(
            find.descendant(of: balance, matching: find.text(expectedMoney)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('supplier-ledger-closing')),
              matching: find.text('1,800 AFN'),
            ),
            findsOneWidget,
          );
        }
        await tester.tap(find.byKey(const ValueKey('supplier-ledger-row-3')));
        await tester.pumpAndSettle();
        expect(find.text('FP-0001 [BILL-017]'), findsOneWidget);
        expect(find.text('BANK-VOUCHER'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('credit and fractional AFN amounts are labeled clearly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Locale('en'),
        const Scaffold(
          body: SupplierLedgerView(entries: [], fallbackOpeningBalance: -7555),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final closing = find.byKey(const ValueKey('supplier-ledger-closing'));
    expect(
      find.descendant(of: closing, matching: find.text('75.55 AFN')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: closing, matching: find.text('Supplier credit')),
      findsOneWidget,
    );
    expect(find.text('No transactions recorded.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'light statement supports enlarged text in a short laptop window',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          const Locale('en'),
          Scaffold(body: SupplierLedgerView(entries: _entries())),
          dark: false,
          textScale: 1.4,
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('supplier-ledger-scroll')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('supplier-ledger-row-5')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Suppliers and Purchase Fabric open the same read-only statement',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = (await tester.runAsync(
        () => ShopDatabase.openAt(inMemoryDatabasePath),
      ))!;
      addTearDown(() => database.db.close());
      late int supplierId;
      await tester.runAsync(() async {
        supplierId = await database.addSupplier(
          name: 'Cotton House',
          openingBalance: 100000,
          openingDate: DateTime(2026, 11, 1),
        );
        final fabricId = await database.addFabric(
          name: 'White Cotton',
          color: 'White',
          unit: 'meter',
          cost: 10000,
          price: 15000,
          lowStock: 0,
        );
        await database.createFabricPurchase(
          supplierId: supplierId,
          lines: [
            {'fabric_id': fabricId, 'quantity': 2.0, 'unit_cost': 100000},
          ],
          date: DateTime(2026, 11, 2),
          discount: 0,
          extraCost: 0,
          paid: 50000,
          method: 'Cash',
          invoiceReference: 'BILL-42',
        );
      });
      final before = (await tester.runAsync(
        () => database.supplierLedger(supplierId),
      ))!;
      await tester.pumpWidget(
        _app(
          const Locale('en'),
          Scaffold(body: SuppliersScreen(database: database)),
        ),
      );
      await _settleDatabase(tester);
      await tester.tap(find.byTooltip('Supplier ledger').first);
      await _settleDatabase(tester);
      expect(find.byType(SupplierLedgerView), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('supplier-ledger-closing')),
          matching: find.text('2,500 AFN'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close'));
      await _settleDatabase(tester);
      await tester.tap(find.byTooltip('View profile').first);
      await _settleDatabase(tester);
      await tester.tap(find.widgetWithText(Tab, 'Supplier ledger'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.5;
      await tester.pumpAndSettle();
      expect(find.byType(SupplierLedgerView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await _settleDatabase(tester);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _app(
          const Locale('en'),
          FabricPurchaseScreen(database: database, supplierId: supplierId),
        ),
      );
      await _settleDatabase(tester);
      await tester.ensureVisible(find.text('View supplier ledger').first);
      await tester.tap(find.text('View supplier ledger').first);
      await _settleDatabase(tester);
      expect(find.byType(SupplierLedgerView), findsOneWidget);
      expect(
        await tester.runAsync(() => database.supplierLedger(supplierId)),
        before,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _settleDatabase(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();
}

Widget _app(
  Locale locale,
  Widget home, {
  GlobalKey? captureKey,
  bool dark = true,
  double textScale = 1,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildAppTheme(),
  darkTheme: buildDarkAppTheme(),
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa', 'AF')],
  localizationsDelegates: const [
    AppLocalizations.delegate,
    TailorShopCupertinoLocalizationsDelegate.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  builder: (context, child) => RepaintBoundary(
    key: captureKey,
    child: MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: locale.languageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: child!,
      ),
    ),
  ),
  home: home,
);
