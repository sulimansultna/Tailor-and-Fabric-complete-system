import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/dialogs/customer_dialog.dart';
import 'package:tailor_shop/dialogs/measurement_dialog.dart';
import 'package:tailor_shop/dialogs/order_dialog.dart';
import 'package:tailor_shop/l10n/generated/app_localizations.dart';
import 'package:tailor_shop/l10n/pashto_cupertino_localizations.dart';
import 'package:tailor_shop/models/garment.dart';

void main() {
  late ShopDatabase database;
  late Map<String, Object?> customer;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
    final id = await database.addCustomer(
      name: 'Ahmad Khan',
      phone: '0700123456',
    );
    customer = (await database.customerDetails(id))!;
  });
  tearDown(() => database.db.close());

  Future<void> open(
    WidgetTester tester,
    Locale locale,
    Future<void> Function(BuildContext context) action,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1536, 864);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildDarkAppTheme(),
        themeMode: locale.languageCode == 'fa'
            ? ThemeMode.dark
            : ThemeMode.light,
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
        builder: (context, child) => Directionality(
          textDirection: locale.languageCode == 'en'
              ? TextDirection.ltr
              : TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.25)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => action(context),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> resize(WidgetTester tester, void Function() verify) async {
    for (final (size, dpi) in const [
      (Size(1280, 720), 1.5),
      (Size(1366, 768), 1.25),
      (Size(1920, 1080), 1.0),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = dpi;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size at $dpi');
      verify();
    }
  }

  Finder field(String label) => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );

  for (final locale in const [Locale('en'), Locale('ps'), Locale('fa', 'AF')]) {
    testWidgets('order fields and draft survive live resizing in $locale', (
      tester,
    ) async {
      await open(
        tester,
        locale,
        (context) => showOrderDialog(context, database, customer),
      );
      final l10n = AppLocalizations.of(tester.element(find.byType(Dialog)))!;
      await tester.ensureVisible(field(l10n.quantity));
      await tester.enterText(field(l10n.quantity), '2');
      await tester.enterText(field(l10n.pricePerItem), '1250');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.reviewMeasurements));
      await tester.tap(find.text(l10n.reviewMeasurements));
      await tester.pumpAndSettle();
      final hemField = find
          .byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.suffixText == 'in',
          )
          .at(5);
      await tester.ensureVisible(hemField);
      await tester.enterText(hemField, '25');
      final roundHem = find.byKey(const ValueKey('design-choice-roundHem'));
      await tester.ensureVisible(roundHem);
      await tester.tap(roundHem);
      await tester.pump();
      await tester.tap(find.text(l10n.useMeasurementsForOrder));
      await tester.pumpAndSettle();
      await resize(tester, () {
        expect(
          tester.widget<TextField>(field(l10n.quantity)).controller!.text,
          '2',
        );
        expect(
          tester.widget<TextField>(field(l10n.pricePerItem)).controller!.text,
          '1250',
        );
        expect(find.text(l10n.reviewOrder).hitTestable(), findsOneWidget);
        expect(find.text(l10n.workerSaveDraft).hitTestable(), findsOneWidget);
      });
      await tester.tap(find.text(l10n.workerSaveDraft));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final drafts = (await tester.runAsync(() => database.orderDrafts()))!;
      expect(drafts, hasLength(1));
      final draftData = jsonDecode(drafts.single['payload'] as String) as Map;
      final line = (draftData['lines'] as List).single as Map;
      expect(line['snapshot']['Hem width'], '25');
      expect(line['designChoices']['roundHem'], isTrue);
      expect(
        await tester.runAsync(
          () => database.measurements(customer['id'] as int, 'shalwar'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'measurements retain input and physical-left drawing in $locale',
      (tester) async {
        Map<String, Object?>? savedProfile = {
          'profile_name': 'Standard',
          'unit': 'in',
          'data': jsonEncode({
            'Upper arm': '13',
            'Design choices': {'belt': true},
          }),
        };
        await open(
          tester,
          locale,
          (context) => showMeasurementDialog(
            context,
            database,
            customer,
            Garment.shalwar,
            existing: savedProfile,
            onSaved: () async {},
          ),
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(AlertDialog)),
        )!;
        final numeric = find
            .byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.decoration?.suffixText == 'in',
            )
            .first;
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.suffixText == 'in',
          ),
          findsNWidgets(8),
        );
        final roundHem = find.byKey(const ValueKey('design-choice-roundHem'));
        final straightHem = find.byKey(
          const ValueKey('design-choice-straightHem'),
        );
        await tester.ensureVisible(roundHem);
        await tester.tap(roundHem);
        await tester.pump();
        await tester.ensureVisible(straightHem);
        await tester.tap(straightHem);
        await tester.pump();
        bool checked(Finder tile) => tester
            .widget<Checkbox>(
              find.descendant(of: tile, matching: find.byType(Checkbox)),
            )
            .value!;
        expect(checked(roundHem), isFalse);
        expect(checked(straightHem), isTrue);
        await tester.ensureVisible(numeric);
        await tester.enterText(numeric, '39.5');
        await tester.pump();
        await resize(tester, () {
          expect(tester.widget<TextField>(numeric).controller!.text, '39.5');
          final drawing = find.byKey(const ValueKey('measurement-drawing'));
          final fields = find.byKey(const ValueKey('measurement-fields'));
          expect(
            tester.getTopLeft(drawing).dx,
            lessThan(tester.getTopLeft(fields).dx),
          );
          expect(
            find.text(l10n.saveMeasurements).hitTestable(),
            findsOneWidget,
          );
        });
        await tester.tap(find.text(l10n.saveMeasurements));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pumpAndSettle();
        final profiles = (await tester.runAsync(
          () => database.measurements(customer['id'] as int, 'shalwar'),
        ))!;
        expect(profiles.single['data'], contains('39.5'));
        final data = jsonDecode(profiles.single['data'] as String) as Map;
        expect(data['Upper arm'], '13');
        expect(data['Design choices']['straightHem'], isTrue);
        expect(data['Design choices']['roundHem'], isFalse);
        expect(data['Design choices']['belt'], isTrue);
        savedProfile = profiles.single;
        await tester.tap(find.text('Open form'));
        await tester.pumpAndSettle();
        expect(checked(straightHem), isTrue);
        expect(tester.widget<TextField>(numeric).controller!.text, '39.5');
        await tester.tap(find.text(l10n.cancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('customer dialog keeps entered data and saves after resize', (
    tester,
  ) async {
    await open(tester, const Locale('en'), (context) async {
      await showCustomerDialog(context, database);
    });
    await tester.enterText(find.byType(TextFormField).first, 'Laptop Customer');
    await tester.enterText(find.byType(TextFormField).at(1), '0799123456');
    await resize(tester, () {
      expect(find.text('Laptop Customer'), findsOneWidget);
      expect(find.text('0799123456'), findsOneWidget);
    });
    final save = find.widgetWithText(FilledButton, 'Save customer');
    await tester.tap(save);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(
        () => database.searchCustomers('Laptop Customer'),
      ))!,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}
