import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/app/theme_controller.dart';
import 'package:tailor_shop/app/theme_controller_scope.dart';
import 'package:tailor_shop/auth/auth_controller.dart';
import 'package:tailor_shop/auth/auth_service.dart';
import 'package:tailor_shop/commands/app_commands.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/dialogs/payment_dialog.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';
import 'package:tailor_shop/l10n/locale_controller_scope.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/screens/customers/customers_screen.dart';
import 'package:tailor_shop/screens/dashboard/dashboard_screen.dart';
import 'package:tailor_shop/screens/delivery/delivery_screen.dart';
import 'package:tailor_shop/screens/fabric/fabric_screen.dart';
import 'package:tailor_shop/screens/orders/orders_screen.dart';
import 'package:tailor_shop/screens/payments/payments_screen.dart';
import 'package:tailor_shop/screens/reports/reports_screen.dart';
import 'package:tailor_shop/screens/settings/settings_screen.dart';
import 'package:tailor_shop/screens/shell/main_shell.dart';
import 'package:tailor_shop/screens/suppliers/fabric_purchase_screen.dart';
import 'package:tailor_shop/screens/suppliers/suppliers_screen.dart';
import 'package:tailor_shop/screens/workers/workers_screen.dart';

Future<void> keys(WidgetTester tester, LogicalKeyboardKey key, {bool control = false, bool shift = false, bool alt = false, PhysicalKeyboardKey? physicalKey}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
  if (physicalKey == null) {
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
  } else {
    final down = KeyDownEvent(physicalKey: physicalKey, logicalKey: key, timeStamp: Duration.zero);
    final up = KeyUpEvent(physicalKey: physicalKey, logicalKey: key, timeStamp: const Duration(milliseconds: 1));
    for (final event in [down, up]) {
      HardwareKeyboard.instance.handleKeyEvent(event);
      // flutter_test's legacy key-code maps do not include Afghan Unicode keys.
      // Feed the same framework key message after updating hardware-key state.
      // ignore: deprecated_member_use
      ServicesBinding.instance.keyEventManager.keyMessageHandler?.call(KeyMessage([event], null));
    }
  }
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Future<void> settleData(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

Widget testApp(AppCommandRegistry registry, Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
  theme: buildAppTheme(), locale: locale,
  navigatorObservers: [registry.observer],
  supportedLocales: const [Locale('en'), Locale('ps'), Locale('fa', 'AF')],
  localizationsDelegates: const [AppLocalizations.delegate, TailorShopCupertinoLocalizationsDelegate.delegate,
    GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
  builder: (context, child) => AppCommandHost(registry: registry, child: Directionality(
    textDirection: locale.languageCode == 'en' ? TextDirection.ltr : TextDirection.rtl, child: child!)),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { sqfliteFfiInit(); databaseFactory = databaseFactoryFfi; });

  testWidgets('editing keys stay in text fields, AltGr is ignored, and commands do not repeat', (tester) async {
    final registry = AppCommandRegistry();
    final text = TextEditingController(text: 'abc');
    var removed = 0;
    var added = 0;
    addTearDown(registry.dispose);
    addTearDown(text.dispose);
    await tester.pumpWidget(testApp(registry, Scaffold(body: CommandScope(commands: [
      AppCommand(CommandKey.remove, () => removed++),
      AppCommand(CommandKey.add, () => added++),
    ], child: TextField(controller: text)))));
    await tester.tap(find.byType(TextField));
    text.selection = const TextSelection.collapsed(offset: 1);
    await keys(tester, LogicalKeyboardKey.delete);
    expect(text.text, 'ac');
    expect(removed, 0);
    await keys(tester, LogicalKeyboardKey.keyA, control: true);
    expect(text.selection, const TextSelection(baseOffset: 0, extentOffset: 2));
    await keys(tester, LogicalKeyboardKey.keyN, control: true, alt: true);
    expect(added, 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('physical Ctrl keys work in $locale and modal commands isolate the background', (tester) async {
      final registry = AppCommandRegistry();
      addTearDown(registry.dispose);
      var navigated = 0;
      var saved = 0;
      final saveGate = Completer<void>();
      await tester.pumpWidget(testApp(registry, Scaffold(body: Builder(builder: (context) => CommandScope(global: true, commands: [
        AppCommand('nav.customers', () => navigated++),
        AppCommand(CommandKey.add, () => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('Active form'), actions: [CommandButton(id: CommandKey.save, child: FilledButton(
            onPressed: () async { saved++; await saveGate.future; if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('Save')))],
        ))),
      ], child: const Text('Home')))), locale: locale));
      await keys(tester, const LogicalKeyboardKey(0x0646), physicalKey: PhysicalKeyboardKey.keyN, control: true);
      await tester.pumpAndSettle();
      expect(find.text('Active form'), findsOneWidget);
      await keys(tester, LogicalKeyboardKey.digit2, control: true);
      expect(navigated, 0);
      await keys(tester, const LogicalKeyboardKey(0x0633), physicalKey: PhysicalKeyboardKey.keyS, control: true);
      await keys(tester, const LogicalKeyboardKey(0x0633), physicalKey: PhysicalKeyboardKey.keyS, control: true);
      expect(saved, 1);
      saveGate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Active form'), findsNothing);
      await keys(tester, LogicalKeyboardKey.digit2, control: true);
      expect(navigated, 1);
      await keys(tester, LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('command-palette-search')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Ctrl+K is searchable and unavailable commands explain why', (tester) async {
    final registry = AppCommandRegistry();
    addTearDown(registry.dispose);
    await tester.pumpWidget(testApp(registry, Scaffold(body: CommandScope(commands: [
      AppCommand('reports.pdf', () {}, disabledReason: () => 'Generate a report first.'),
    ], child: const Text('Reports')))));
    await keys(tester, LogicalKeyboardKey.keyK, control: true);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('command-palette-search')), 'PDF');
    await tester.pump();
    expect(find.text('Save report PDF'), findsOneWidget);
    expect(find.text('Generate a report first.'), findsOneWidget);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Save report PDF')).enabled, isFalse);
    await keys(tester, LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  group('existing workflows', () {
    late ShopDatabase db;
    late AuthService auth;
    late AuthController authController;
    late Directory directory;
    late AppCommandRegistry registry;
    late LocaleController localeController;
    late ThemeController themeController;
    late Map<String, Object?> customer;
    late Map<String, Object?> order;
    setUp(() async {
      db = await ShopDatabase.openAt(inMemoryDatabasePath);
      final id = await db.addCustomer(name: 'Keyboard Customer', phone: '0700123456');
      customer = (await db.customerDetails(id))!;
      await db.createOrder(customerId: id, total: 100000, advance: 0, billNumber: 'KEY-001',
        lines: [{'garment': 'shalwar', 'quantity': 1, 'price_each': 100000, 'measurement_snapshot': '{}'}]);
      order = (await db.db.query('orders')).single;
      directory = await Directory.systemTemp.createTemp('tailor-keyboard-test-');
      auth = await AuthService.openAt('${directory.path}/auth.db', MemorySecureTokenStore(), passwordIterations: 10000);
      authController = AuthController(auth);
      registry = AppCommandRegistry();
      localeController = LocaleController(db);
      themeController = ThemeController(db);
      await localeController.load(db.settings());
      await themeController.load(db.settings());
    });
    tearDown(() async {
      registry.dispose(); localeController.dispose(); themeController.dispose(); authController.dispose();
      await db.db.close(); await auth.close(); await directory.delete(recursive: true);
    });
    Future<void> shell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(registry, LocaleControllerScope(controller: localeController,
        child: ThemeControllerScope(controller: themeController,
          child: MainShell(database: db, shopName: 'Keyboard shop', authController: authController)))));
      await settleData(tester);
    }

    testWidgets('screen shortcut map reaches all nine destinations and settings', (tester) async {
      await shell(tester);
      const destinations = [DashboardScreen, CustomersScreen, OrdersScreen, DeliveryScreen, FabricScreen,
        SuppliersScreen, PaymentsScreen, WorkersScreen, ReportsScreen];
      const digits = [LogicalKeyboardKey.digit1, LogicalKeyboardKey.digit2, LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4, LogicalKeyboardKey.digit5, LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7, LogicalKeyboardKey.digit8, LogicalKeyboardKey.digit9];
      for (var index = 0; index < digits.length; index++) {
        await keys(tester, digits[index], control: true);
        await settleData(tester);
        expect(find.byType(destinations[index]), findsOneWidget, reason: 'Ctrl+${index+1}');
        expect(tester.takeException(), isNull);
      }
      await keys(tester, LogicalKeyboardKey.comma, control: true);
      await settleData(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('Ctrl+N and Ctrl+S use customer validation and preserve normal editing', (tester) async {
      await shell(tester);
      await keys(tester, LogicalKeyboardKey.digit2, control: true);
      await settleData(tester);
      await keys(tester, LogicalKeyboardKey.keyN, control: true);
      await tester.pumpAndSettle();
      await keys(tester, LogicalKeyboardKey.keyS, control: true);
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect((await tester.runAsync(() => db.searchCustomers('')) )!, hasLength(1));
      await tester.enterText(find.byType(TextFormField).first, 'New Keyboard Customer');
      await tester.enterText(find.byType(TextFormField).at(1), '0799123456');
      await keys(tester, LogicalKeyboardKey.keyS, control: true);
      await settleData(tester);
      expect((await tester.runAsync(() => db.searchCustomers('New Keyboard')))!, hasLength(1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('payment Save key-repeat posts one payment and one allocation', (tester) async {
      await tester.pumpWidget(testApp(registry, Scaffold(body: Builder(builder: (ctx) => CommandScope(commands: [
        AppCommand(CommandKey.add, () => showPaymentDialog(ctx, db, customer: customer)),
      ], child: const Text('Payments'))))));
      await keys(tester, LogicalKeyboardKey.keyN, control: true);
      await settleData(tester);
      await tester.enterText(find.byKey(const ValueKey('payment-amount')), '250');
      await tester.pump();
      await keys(tester, LogicalKeyboardKey.keyP, control: true);
      expect((await tester.runAsync(() => db.db.query('payments')))!, isEmpty);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settleData(tester);
      final payments = (await tester.runAsync(() => db.db.query('payments')))!;
      final allocations = (await tester.runAsync(() => db.db.query('payment_allocations')))!;
      final fresh = (await tester.runAsync(() => db.db.query('orders')))!;
      expect(payments, hasLength(1)); expect(allocations, hasLength(1));
      expect(payments.single['amount'], 25000); expect(fresh.single['paid'], 25000);
      expect(tester.takeException(), isNull);
    });

    testWidgets('order actions enforce eligibility and open the existing cancellation workflow', (tester) async {
      await shell(tester);
      await keys(tester, LogicalKeyboardKey.digit3, control: true);
      await settleData(tester);
      registry.select('order', order);
      await keys(tester, LogicalKeyboardKey.keyD, control: true, shift: true);
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      await keys(tester, LogicalKeyboardKey.keyX, control: true, shift: true);
      await settleData(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      final before = (await tester.runAsync(() => db.db.query('orders')))!;
      expect(before.single['cancellation_status'], isNot('Cancelled'));
      await keys(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect((await tester.runAsync(() => db.db.query('orders')))!.single['cancellation_status'], isNot('Cancelled'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('navigation from a dirty purchase asks before leaving', (tester) async {
      await shell(tester);
      await keys(tester, LogicalKeyboardKey.digit1, control: true, shift: true);
      await settleData(tester);
      expect(find.byType(FabricPurchaseScreen), findsOneWidget);
      // Supplier text changes use the same dirty-state listener as mouse entry.
      final tabs = find.text('View invoice (0)');
      if (tabs.evaluate().isNotEmpty) { await tester.tap(tabs); await tester.pumpAndSettle(); }
      final invoice = find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Supplier invoice / bill number');
      expect(invoice, findsOneWidget);
      await tester.enterText(invoice, 'UNSAVED-001');
      await keys(tester, LogicalKeyboardKey.digit1, control: true);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await keys(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(FabricPurchaseScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
