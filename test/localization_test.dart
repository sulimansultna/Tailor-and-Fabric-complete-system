import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/core/formatters.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('unsupported or missing saved locale defaults to Pashto', () {
    expect(LocaleController.parse(null), const Locale('ps'));
    expect(LocaleController.parse('not-a-locale'), const Locale('ps'));
    expect(LocaleController.parse('fa_AF'), const Locale('fa', 'AF'));
    expect(LocaleController.parse('English'), const Locale('en'));
  });

  test('selected locale is restored from local settings', () async {
    final database = await ShopDatabase.openAt(inMemoryDatabasePath);
    addTearDown(() => database.db.close());

    final controller = LocaleController(database);
    await controller.setLocale(const Locale('fa', 'AF'));
    final restored = LocaleController(database);
    await restored.load(database.settings());
    expect(restored.locale, const Locale('fa', 'AF'));

    await database.saveSettings({'language': 'unsupported'});
    final fallback = LocaleController(database);
    await fallback.load(database.settings());
    expect(fallback.locale, const Locale('ps'));
    controller.dispose();
    restored.dispose();
    fallback.dispose();
  });

  test('localized digits normalize without changing Western digits', () {
    expect(normalizeLocalizedDigits('۱۲۳٫۴۵'), '123.45');
    expect(normalizeLocalizedDigits('١٢٣٬٤٥٦'), '123456');
    expect(normalizeLocalizedDigits('0700123456'), '0700123456');
  });

  testWidgets('locale changes update direction and preserve form input', (
    tester,
  ) async {
    await tester.pumpWidget(const _LocaleSwitchFixture());

    expect(find.text('خپل دوکان تنظیم کړئ'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.rtl,
    );
    await tester.enterText(find.byType(TextField), 'Kabul Tailors');

    await tester.tap(find.text('Switch to Dari'));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.rtl,
    );
    expect(find.text('تنظیم خیاطی'), findsOneWidget);
    expect(find.text('Kabul Tailors'), findsOneWidget);

    await tester.tap(find.text('Switch to English'));
    await tester.pumpAndSettle();
    expect(
      Directionality.of(tester.element(find.byType(TextField))),
      TextDirection.ltr,
    );
    expect(find.text('Set up your shop'), findsOneWidget);
    expect(find.text('Kabul Tailors'), findsOneWidget);
  });
}

class _LocaleSwitchFixture extends StatefulWidget {
  const _LocaleSwitchFixture();

  @override
  State<_LocaleSwitchFixture> createState() => _LocaleSwitchFixtureState();
}

class _LocaleSwitchFixtureState extends State<_LocaleSwitchFixture> {
  Locale locale = const Locale('ps');

  @override
  Widget build(BuildContext context) => MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ps'), Locale('fa', 'AF'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      TailorShopCupertinoLocalizationsDelegate.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            Text(AppLocalizations.of(context)!.setupTitle),
            const TextField(),
            TextButton(
              onPressed: () =>
                  setState(() => locale = const Locale('fa', 'AF')),
              child: const Text('Switch to Dari'),
            ),
            TextButton(
              onPressed: () => setState(() => locale = const Locale('en')),
              child: const Text('Switch to English'),
            ),
          ],
        ),
      ),
    ),
  );
}
