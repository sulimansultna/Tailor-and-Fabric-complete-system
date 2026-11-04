import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/auth/auth_controller.dart';
import 'package:tailor_shop/auth/auth_screens.dart';
import 'package:tailor_shop/auth/auth_service.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late AuthService auth;
  late AuthController controller;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('tailor-login-widget-');
    auth = await AuthService.openAt(
      '${directory.path}${Platform.pathSeparator}owner_auth.db',
      MemorySecureTokenStore(),
      passwordIterations: 10000,
    );
    controller = AuthController(auth);
  });

  tearDown(() async {
    controller.dispose();
    await auth.close();
    await directory.delete(recursive: true);
  });

  Widget app(Locale locale, {double scale = 1, bool reducedMotion = false}) =>
      MaterialApp(
        locale: locale,
        supportedLocales: const [
          Locale('ps'),
          Locale('fa', 'AF'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          TailorShopCupertinoLocalizationsDelegate.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: const {'ps', 'fa'}.contains(locale.languageCode)
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
        ),
        home: LoginScreen(controller: controller, appName: 'Needle & Thread'),
      );

  testWidgets('login adapts across common sizes and loads local artwork', (
    tester,
  ) async {
    for (final size in const [
      Size(390, 844),
      Size(800, 900),
      Size(1280, 600),
      Size(1280, 720),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(app(const Locale('en')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Needle & Thread'), findsOneWidget);
      expect(find.text('Your shop, organized.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('RTL language changes preserve entered login values', (
    tester,
  ) async {
    await tester.pumpWidget(app(const Locale('ps')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      Directionality.of(tester.element(find.byType(LoginScreen))),
      TextDirection.rtl,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'TailorOwner');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    await tester.pumpWidget(app(const Locale('fa', 'AF')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      Directionality.of(tester.element(find.byType(LoginScreen))),
      TextDirection.rtl,
    );
    expect(find.text('TailorOwner'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    for (final (size, dpi) in const [
      (Size(1280, 720), 1.5),
      (Size(1366, 768), 1.25),
      (Size(1920, 1080), 1.0),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpi;
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'TailorOwner',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'wrong-password',
      );
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(tester.takeException(), isNull);
  });

  testWidgets('larger text and reduced motion keep the login usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      app(const Locale('ps'), scale: 1.35, reducedMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Needle & Thread'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    expect(find.byType(LoginFormCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('required fields prevent an empty submission', (tester) async {
    await tester.pumpWidget(app(const Locale('en'), reducedMotion: true));
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
