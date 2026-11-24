import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/theme_controller.dart';
import 'package:tailor_shop/app/theme_controller_scope.dart';
import 'package:tailor_shop/auth/auth_controller.dart';
import 'package:tailor_shop/auth/auth_service.dart';
import 'package:tailor_shop/data/backup_service.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';
import 'package:tailor_shop/l10n/locale_controller_scope.dart';
import 'package:tailor_shop/reports/order_document_service.dart';
import 'package:tailor_shop/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const printingChannel = MethodChannel('net.nfet.printing');
  late ShopDatabase database;
  late AuthService authService;
  late AuthController authController;
  late LocaleController localeController;
  late ThemeController themeController;
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'tailor-printer-settings-',
    );
    BackupService.localRootOverride = directory;
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    authService = await AuthService.openAt(
      '${directory.path}/auth.db',
      MemorySecureTokenStore(),
      passwordIterations: 10000,
    );
    authController = AuthController(authService);
    localeController = LocaleController(database);
    themeController = ThemeController(database);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(printingChannel, (call) async {
          if (call.method == 'listPrinters') {
            return [
              {'url': 'thermal-printer', 'name': 'Thermal Printer'},
            ];
          }
          throw MissingPluginException(
            'Unexpected printing call: ${call.method}',
          );
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(printingChannel, null);
    authController.dispose();
    localeController.dispose();
    themeController.dispose();
    await database.db.close();
    await authService.close();
    BackupService.localRootOverride = null;
    assert(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
    );
    await directory.delete(recursive: true);
  });

  Widget app() => MaterialApp(
    locale: const Locale('en'),
    supportedLocales: const [Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: LocaleControllerScope(
      controller: localeController,
      child: ThemeControllerScope(
        controller: themeController,
        child: Scaffold(
          body: SettingsScreen(
            database: database,
            authController: authController,
          ),
        ),
      ),
    ),
  );

  Future<void> settleData(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'printer and paper changes save without errors and survive reload',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await settleData(tester);

      Future<void> select(String setting, String previous, String label) async {
        final field = find.byKey(ValueKey('$setting:$previous'));
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await settleData(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(SnackBar), findsNothing);
      }

      for (final setting in [
        orderMeasurementPaperSetting,
        orderBillPaperSetting,
      ]) {
        await select(setting, '55mm', '80 mm roll');
        expect((await tester.runAsync(database.settings))![setting], '80mm');
        await select(setting, '80mm', '55 mm roll');
        expect((await tester.runAsync(database.settings))![setting], '55mm');
        await select(setting, '55mm', '80 mm roll');
      }
      for (final setting in [
        orderMeasurementPrinterSetting,
        orderBillPrinterSetting,
      ]) {
        await select(setting, '', 'Thermal Printer');
        expect(
          (await tester.runAsync(database.settings))![setting],
          'thermal-printer',
        );
      }

      final refresh = find.byIcon(Icons.refresh_outlined);
      await tester.ensureVisible(refresh);
      await tester.pumpAndSettle();
      await tester.tap(refresh);
      await settleData(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await settleData(tester);
      for (final setting in [
        orderMeasurementPaperSetting,
        orderBillPaperSetting,
      ]) {
        expect(find.byKey(ValueKey('$setting:80mm')), findsOneWidget);
      }
      for (final setting in [
        orderMeasurementPrinterSetting,
        orderBillPrinterSetting,
      ]) {
        expect(
          find.byKey(ValueKey('$setting:thermal-printer')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
