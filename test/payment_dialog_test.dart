import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/core/formatters.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/dialogs/payment_dialog.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<ShopDatabase> openDialog(
    WidgetTester tester, {
    String language = 'en',
    bool selectedBill = false,
    Size size = const Size(1366, 768),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CalendarService.activeCalendar = CalendarService.solarHijri;
    CalendarService.activeLocale = language;
    final db = (await tester.runAsync(() async {
      final db = await ShopDatabase.openAt(inMemoryDatabasePath);
      final id = await db.addCustomer(
        name: 'Ahmad Khan',
        phone: '0700123456',
        opening: 125000,
      );
      await db.createOrder(
        customerId: id,
        total: 200000,
        advance: 50000,
        billNumber: '00125',
        lines: [
          {
            'garment': 'shalwar',
            'quantity': 1,
            'measurement_snapshot': '{}',
            'price_each': 200000,
          },
        ],
      );
      return db;
    }))!;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => db.db.close());
    });
    final customer = (await tester.runAsync(() => db.db.query('customers')))!
        .single;
    final order = (await tester.runAsync(() => db.db.query('orders')))!.single;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPaymentDialog(
                context,
                db,
                customer: customer,
                order: selectedBill ? order : null,
              ),
              child: const Text('Open payment'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open payment'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    return db;
  }

  final amount = find.byKey(const ValueKey('payment-amount'));
  final preview = find.byKey(const ValueKey('payment-balance-preview'));

  testWidgets(
    'loads ledger balance immediately and previews partial, full and excess payments',
    (tester) async {
      await openDialog(tester);
      expect(
        find.descendant(
          of: preview,
          matching: find.text('2,750 AFN · Customer owes'),
        ),
        findsNWidgets(2),
      );
      expect(find.text('More details (optional)'), findsOneWidget);
      expect(find.text('Bill allocation details'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save Payment'),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(amount, '750.50');
      await tester.pump();
      expect(
        find.descendant(
          of: preview,
          matching: find.text('1,999.50 AFN · Customer owes'),
        ),
        findsOneWidget,
      );
      await tester.enterText(amount, '2750');
      await tester.pump();
      expect(
        find.descendant(of: preview, matching: find.text('0 AFN · Settled')),
        findsOneWidget,
      );
      await tester.enterText(amount, '3000');
      await tester.pump();
      expect(
        find.descendant(
          of: preview,
          matching: find.text('250 AFN · Customer advance'),
        ),
        findsOneWidget,
      );
      await tester.enterText(amount, '');
      await tester.pump();
      expect(
        find.descendant(
          of: preview,
          matching: find.text('2,750 AFN · Customer owes'),
        ),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected bill saves exact decimal payment and ledger matches preview',
    (tester) async {
      final db = await openDialog(tester, selectedBill: true);
      await tester.enterText(amount, '750.50');
      await tester.pump();
      await tester.tap(find.text('Save Payment'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final summary = (await tester.runAsync(
        () => db.customerFinancialSummary(1),
      ))!;
      expect(summary['balance'], 199950);
      final allocations = (await tester.runAsync(
        () => db.db.query('payment_allocations'),
      ))!;
      expect(allocations.last['amount'], 75050);
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['ps', 'fa']) {
    testWidgets(
      'balance supports $language digits and RTL on a narrow screen',
      (tester) async {
        await openDialog(
          tester,
          language: language,
          size: const Size(390, 844),
        );
        await tester.enterText(amount, '۷۵۰٫۵۰');
        await tester.pump();
        expect(
          find.descendant(
            of: preview,
            matching: find.textContaining(
              formatPaymentMoney(199950, locale: language),
            ),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
