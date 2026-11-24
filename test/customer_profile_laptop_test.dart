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
import 'package:tailor_shop/screens/customers/widgets/garment_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ShopDatabase database;
  late Map<String, Object?> customer;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    if (const bool.fromEnvironment('CAPTURE_PROFILE_LAYOUT')) {
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
    final id = await database.addCustomer(
      name: 'Bashir Ahmad',
      phone: '079845334',
    );
    customer = (await database.customerDetails(id))!;
    for (final garment in ['shalwar', 'waistcoat']) {
      await database.saveMeasurement(
        customerId: id,
        garment: garment,
        name: 'Standard',
        unit: 'in',
        json: '{"Chest":"40"}',
      );
    }
    await database.createOrder(
      customerId: id,
      total: 200000,
      advance: 50000,
      billNumber: '00125',
      lines: [
        {
          'garment': 'shalwar',
          'quantity': 1,
          'measurement_profile': 'Standard',
          'measurement_snapshot': '{"Chest":"40"}',
          'price_each': 200000,
        },
      ],
    );
  });

  tearDown(() => database.db.close());

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('profile leaves orders visible on laptops in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          darkTheme: buildDarkAppTheme(),
          themeMode: ThemeMode.dark,
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
          home: CustomerProfileScreen(database: database, customer: customer),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;

      for (final (size, dpi) in const [
        (Size(1280, 720), 1.0),
        (Size(1366, 768), 1.25),
        (Size(1920, 1080), 1.5),
        (Size(1920, 1080), 1.0),
        (Size(1280, 720), 1.0),
      ]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = dpi;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size at $dpi');
        expect(find.byType(GarmentCard).hitTestable(), findsNWidgets(3));
        expect(
          find.textContaining('00125').hitTestable(),
          findsWidgets,
          reason: 'Orders should be visible without scrolling at $size / $dpi',
        );
        expect(find.byType(TabBar).hitTestable(), findsOneWidget);

        if (const bool.fromEnvironment('CAPTURE_PROFILE_LAYOUT')) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final rendered = await boundary.toImage(pixelRatio: 1);
            final bytes = await rendered.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = await Directory('tmp/profile_layout')
                .create(recursive: true);
            await File(
              '${directory.path}/${locale.toLanguageTag()}-${size.width.toInt()}-${dpi}x.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      }
      await tester.enterText(search, '00125');
      for (final size in const [Size(1920, 1080), Size(1280, 720)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<TextField>(search).controller!.text, '00125');
        expect(find.textContaining('00125').hitTestable(), findsWidgets);
      }
    });
  }
}
