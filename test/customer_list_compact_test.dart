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
import 'package:tailor_shop/screens/customers/customer_profile_screen.dart';
import 'package:tailor_shop/screens/customers/customers_screen.dart';
import 'package:tailor_shop/screens/customers/widgets/customer_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (const bool.fromEnvironment('CAPTURE_CUSTOMER_LIST')) {
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
    for (final name in [
      'Abdul Wali Khan',
      'Bashir Ahmad',
      'Irfan',
      'Khan Wali',
      'Majid Mama',
      'Samiullah',
      'Umair Safi',
      'Muhammad Dawood',
    ]) {
      final customerId = await database.addCustomer(
        name: name,
        phone: '0778990005',
        opening: 1208000,
      );
      if (name == 'Bashir Ahmad') {
        await database.createOrder(
          customerId: customerId,
          total: 50000,
          advance: 0,
          billNumber: '00125',
          lines: [
            {
              'garment': 'shalwar',
              'quantity': 1,
              'measurement_snapshot': '{}',
              'price_each': 50000,
            },
          ],
        );
      }
    }
  });
  tearDown(() => database.db.close());

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('customer rows stay small on laptop and monitor in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: ThemeMode.dark,
          debugShowCheckedModeBanner: false,
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
          builder: (context, child) => RepaintBoundary(
            key: captureKey,
            child: Directionality(
              textDirection: locale.languageCode == 'en'
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 72),
                Expanded(child: CustomersScreen(database: database)),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      double? monitorRowHeight;
      for (final (size, dpi) in const [
        (Size(1920, 1080), 1.0),
        (Size(1920, 1080), 1.5),
        (Size(1366, 768), 1.25),
        (Size(1280, 720), 1.5),
        (Size(1920, 1080), 1.0),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpi;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size at $dpi');
        final first = find.byType(CustomerTile).first;
        expect(tester.widget<CustomerTile>(first).wide, isTrue);
        final rowHeight = tester.getSize(first).height;
        monitorRowHeight ??= rowHeight;
        expect(rowHeight, lessThanOrEqualTo(76));
        expect(rowHeight, closeTo(monitorRowHeight, 2));
        expect(
          find.byType(CustomerTile).hitTestable().evaluate().length,
          greaterThanOrEqualTo(3),
        );
        if (const bool.fromEnvironment('CAPTURE_CUSTOMER_LIST')) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = await Directory('tmp/customer_list_compact')
                .create(recursive: true);
            await File(
              '${directory.path}/${locale.toLanguageTag()}-${size.width.toInt()}-${dpi}x.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      }

      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.5;
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;
      await tester.enterText(search, 'Bashir');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bashir Ahmad'), findsOneWidget);
      expect(find.text('Abdul Wali Khan'), findsNothing);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CustomersScreen)),
      )!;
      await tester.tap(find.byTooltip(l10n.openProfile));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomerProfileScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(CustomerProfileScreen))).pop();
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, 'Bashir');
      expect(tester.takeException(), isNull);
    });
  }
}
