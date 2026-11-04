import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'dart:ui' as ui;

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/screens/shell/main_shell.dart';
import 'package:tailor_shop/screens/customers/customers_screen.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/auth/auth_controller.dart';
import 'package:tailor_shop/auth/auth_service.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/app/theme_controller.dart';
import 'package:tailor_shop/app/theme_controller_scope.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';
import 'package:tailor_shop/l10n/locale_controller_scope.dart';

import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late String databasePath;
  late AuthService authService;
  late AuthController authController;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (const bool.fromEnvironment('CAPTURE_RESPONSIVE')) {
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
    databasePath =
        '${Directory.systemTemp.path}${Platform.pathSeparator}'
        'dashboard_test_${DateTime.now().microsecondsSinceEpoch}.db';
    database = await ShopDatabase.openAt(databasePath);
    await database.saveSettings({'language': 'English'});
    await database.dashboard();
    authService = await AuthService.openAt(
      '${databasePath}_auth.db',
      MemorySecureTokenStore(),
      passwordIterations: 10000,
    );
    authController = AuthController(authService);
  });

  tearDown(() async {
    await database.db.close();
    authController.dispose();
    await authService.close();
    final file = File(databasePath);
    if (await file.exists()) await file.delete();
    final authFile = File('${databasePath}_auth.db');
    if (await authFile.exists()) await authFile.delete();
  });

  testWidgets(
    'navigation breakpoints preserve search, filters, sort, and scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (var index = 0; index < 40; index++) {
          await database.addCustomer(
            name: 'Ahmad Customer $index',
            phone: '070012${index.toString().padLeft(4, '0')}',
            opening: 100000,
          );
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
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
          home: MainShell(
            database: database,
            shopName: 'Test shop',
            authController: authController,
          ),
        ),
      );
      tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .onDestinationSelected!(1);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final search = find
          .descendant(
            of: find.byType(CustomersScreen),
            matching: find.byType(TextField, skipOffstage: false),
            skipOffstage: false,
          )
          .first;
      await tester.enterText(search, 'Ahmad');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CustomersScreen)),
      )!;
      await tester.tap(
        find.widgetWithText(FilterChip, l10n.filterWithOutstanding),
      );
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged!('balance');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final controller = tester.widget<TextField>(search).controller;
      final state = tester.state(find.byType(CustomersScreen));
      final list = find.descendant(
        of: find.byType(CustomersScreen),
        matching: find.byType(CustomScrollView),
      );
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      double offset() => tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position
          .pixels;
      final before = offset();
      expect(before, greaterThan(100));
      for (final size in const [
        Size(640, 560),
        Size(1920, 1080),
        Size(1024, 576),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CustomersScreen)), same(state));
        expect(tester.widget<TextField>(search).controller, same(controller));
        expect(controller!.text, 'Ahmad');
        expect(
          tester
              .widget<FilterChip>(
                find.widgetWithText(
                  FilterChip,
                  l10n.filterWithOutstanding,
                  skipOffstage: false,
                ),
              )
              .selected,
          isTrue,
        );
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(
                  DropdownButtonFormField<String>,
                  skipOffstage: false,
                ),
              )
              .initialValue,
          'balance',
        );
        expect(offset(), closeTo(before, 1));
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('all main screens resize between laptop sizes in $locale', (
      tester,
    ) async {
      if (const bool.fromEnvironment('CAPTURE_RESPONSIVE')) {
        final originalErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          originalErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalErrorHandler);
      }
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final customerId = await database.addCustomer(
          name: 'Ahmad Khan',
          phone: '0700123456',
        );
        await database.createOrder(
          customerId: customerId,
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
        await database.addSupplier(
          name: 'Kabul Fabric Supplier',
          phone: '0799123456',
          openingBalance: 500000,
        );
        await database.addFabric(
          name: 'Cotton',
          color: 'Navy',
          unit: 'meter',
          cost: 10000,
          price: 20000,
          lowStock: 2,
          openingQuantity: 20,
          openingDate: DateTime.now(),
        );
        await database.addExpense(
          category: 'Rent',
          amount: 500000,
          description: 'Shop rent',
          date: DateTime.now(),
          method: 'Cash',
        );
      });
      final localeController = LocaleController(database);
      final themeController = ThemeController(database);
      final captureKey = GlobalKey();
      final appTheme = buildAppTheme();
      final textScale = ValueNotifier<double>(1);
      addTearDown(textScale.dispose);
      addTearDown(localeController.dispose);
      addTearDown(themeController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: const bool.fromEnvironment('CAPTURE_RESPONSIVE')
              ? appTheme.copyWith(
                  navigationRailTheme: appTheme.navigationRailTheme.copyWith(
                    selectedLabelTextStyle: appTheme
                        .navigationRailTheme
                        .selectedLabelTextStyle
                        ?.copyWith(fontFamily: 'Roboto'),
                    unselectedLabelTextStyle: appTheme
                        .navigationRailTheme
                        .unselectedLabelTextStyle
                        ?.copyWith(fontFamily: 'Roboto'),
                  ),
                )
              : appTheme,
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: LocaleControllerScope(
              controller: localeController,
              child: ThemeControllerScope(
                controller: themeController,
                child: ValueListenableBuilder<double>(
                  valueListenable: textScale,
                  builder: (context, scale, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  child: Directionality(
                    textDirection: locale.languageCode == 'en'
                        ? TextDirection.ltr
                        : TextDirection.rtl,
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
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
          home: MainShell(
            database: database,
            shopName: 'Test shop',
            authController: authController,
          ),
        ),
      );
      for (var page = 0; page < 11; page++) {
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .onDestinationSelected!(page == 10 ? 6 : page);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pumpAndSettle();
        if (page == 7) {
          final l10n = AppLocalizations.of(
            tester.element(find.byType(MainShell)),
          )!;
          await tester.tap(find.text(l10n.reportGenerate).first);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await tester.pumpAndSettle();
        }
        if (page == 10) {
          tester
              .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
              .onSelectionChanged!({true});
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)),
          );
          await tester.pumpAndSettle();
        }
        for (final (size, dpi, scale) in const [
          (Size(1280, 720), 1.0, 1.0),
          (Size(1366, 768), 1.0, 1.0),
          (Size(1536, 864), 1.0, 1.0),
          (Size(1920, 1080), 1.0, 1.0),
          (Size(1280, 720), 1.25, 1.0),
          (Size(1366, 768), 1.5, 1.0),
          (Size(1280, 720), 1.5, 1.25),
        ]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = dpi;
          textScale.value = scale;
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Page $page at $size, DPI $dpi, text $scale in $locale',
          );
          if (const bool.fromEnvironment('CAPTURE_RESPONSIVE')) {
            if (locale.languageCode == 'en' &&
                (page == 0 || page == 4) &&
                dpi == 1 &&
                (size.width == 1280 || size.width == 1920)) {
              await tester.runAsync(() async {
                final boundary =
                    captureKey.currentContext!.findRenderObject()
                        as RenderRepaintBoundary;
                final rendered = await boundary.toImage(pixelRatio: 1);
                final bytes = await rendered.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final directory = await Directory('artifacts/responsive')
                    .create(recursive: true);
                final name = page == 0 ? 'dashboard' : 'fabric';
                await File(
                  '${directory.path}/$name-${size.width.toInt()}x${size.height.toInt()}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                rendered.dispose();
              });
            }
          }
          if (size.width == 1366 && dpi == 1.5) {
            await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: 'Page $page with expanded sidebar in $locale',
            );
            await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
            await tester.pumpAndSettle();
          }
        }
      }
    });
  }

  for (final (size, locale) in const [
    (Size(390, 844), Locale('en')),
    (Size(800, 900), Locale('en')),
    (Size(1440, 1000), Locale('en')),
    (Size(1366, 650), Locale('en')),
    (Size(800, 900), Locale('ps')),
    (Size(1440, 1000), Locale('fa', 'AF')),
  ]) {
    testWidgets('dashboard lays out and sidebar toggles at $size in $locale', (
      tester,
    ) async {
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
          home: MainShell(
            database: database,
            shopName: 'Test shop',
            authController: authController,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      if (size.width >= 700) {
        final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
        final originalWidth = tester.getSize(find.byType(NavigationRail)).width;
        await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          !rail.extended,
        );
        expect(
          tester.getSize(find.byType(NavigationRail)).width,
          rail.extended ? lessThan(originalWidth) : greaterThan(originalWidth),
        );
        expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          0,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('sidebar-toggle')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          rail.extended,
        );
        expect(tester.takeException(), isNull);
      }
      final l10n = AppLocalizations.of(tester.element(find.byType(MainShell)))!;
      final newOrder = find.text(l10n.newOrder).first;
      await tester.ensureVisible(newOrder);
      await tester.tap(newOrder);
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(find.text(l10n.chooseCustomer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
