import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tailor_shop/app/app_theme.dart';
import 'package:tailor_shop/app/theme_controller.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/data/shop_database.dart';

void main() {
  late ShopDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await ShopDatabase.openAt(inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.db.close();
  });

  test('uses light by default and restores a saved dark preference', () async {
    final controller = ThemeController(database);
    await controller.load(database.settings());
    expect(controller.isReady, isTrue);
    expect(controller.themeMode, ThemeMode.light);

    await controller.setThemeMode(ThemeMode.dark);
    final restored = ThemeController(database);
    await restored.load(database.settings());
    expect(restored.themeMode, ThemeMode.dark);
  });

  test(
    'theme preference does not change language or calendar settings',
    () async {
      await database.saveSettings({
        'language': 'fa-AF',
        'calendar_type': CalendarService.gregorian,
        'show_both_dates': 'true',
      });
      final controller = ThemeController(database);
      await controller.load(database.settings());
      await controller.setThemeMode(ThemeMode.dark);

      final settings = await database.settings();
      expect(settings['theme_mode'], 'dark');
      expect(settings['language'], 'fa-AF');
      expect(settings['calendar_type'], CalendarService.gregorian);
      expect(settings['show_both_dates'], 'true');
    },
  );

  testWidgets('switching theme preserves an open form value', (tester) async {
    final controller = ThemeController(database);
    await tester.runAsync(() => controller.load(database.settings()));
    final input = TextEditingController();
    addTearDown(input.dispose);

    await tester.pumpWidget(_ThemeSwitchFixture(controller, input));
    await tester.enterText(find.byType(TextField), 'Entered before switching');
    await tester.pump();
    expect(
      Theme.of(tester.element(find.byType(TextField))).brightness,
      Brightness.light,
    );

    await tester.runAsync(() => controller.setThemeMode(ThemeMode.dark));
    await tester.pumpWidget(_ThemeSwitchFixture(controller, input));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(TextField))).brightness,
      Brightness.dark,
    );
    expect(input.text, 'Entered before switching');
    controller.dispose();
  });

  test('restores the previous mode when saving the preference fails', () async {
    final controller = ThemeController(database);
    await controller.load(database.settings());
    await database.db.execute('DROP TABLE settings');

    await expectLater(
      controller.setThemeMode(ThemeMode.dark),
      throwsA(anything),
    );
    expect(controller.themeMode, ThemeMode.light);
    expect(controller.isSaving, isFalse);
  });
}

class _ThemeSwitchFixture extends StatelessWidget {
  const _ThemeSwitchFixture(this.controller, this.input);

  final ThemeController controller;
  final TextEditingController input;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: controller.themeMode,
      home: Scaffold(body: TextField(controller: input)),
    ),
  );
}
