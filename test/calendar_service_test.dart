import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tailor_shop/core/calendar_service.dart';
import 'package:tailor_shop/core/formatters.dart';
import 'package:tailor_shop/data/shop_database.dart';
import 'package:tailor_shop/l10n/locale_controller.dart';

void main() {
  group('Afghan Solar Hijri conversion', () {
    test('converts new year dates and round trips', () {
      expect(
        CalendarService.fromGregorian(DateTime(2024, 3, 20)).toString(),
        '1403-1-1',
      );
      expect(
        CalendarService.toGregorian(const SolarDate(1403, 1, 1)),
        DateTime(2024, 3, 20),
      );
      expect(
        CalendarService.fromGregorian(DateTime(2025, 3, 20)).toString(),
        '1403-12-30',
      );
      expect(
        CalendarService.fromGregorian(DateTime(2025, 3, 21)).toString(),
        '1404-1-1',
      );
      expect(
        CalendarService.toGregorian(const SolarDate(1404, 1, 1)),
        DateTime(2025, 3, 21),
      );
    });

    test('validates Solar Hijri leap month and common month lengths', () {
      expect(CalendarService.isLeapYear(1399), isTrue);
      expect(CalendarService.monthLength(1399, 12), 30);
      expect(CalendarService.isLeapYear(1400), isFalse);
      expect(CalendarService.monthLength(1400, 12), 29);
      expect(
        () => CalendarService.toGregorian(const SolarDate(1400, 12, 30)),
        throwsArgumentError,
      );
    });

    test('preserves Gregorian leap day in both directions', () {
      final leapDay = DateTime(2024, 2, 29);
      expect(
        CalendarService.toGregorian(CalendarService.fromGregorian(leapDay)),
        leapDay,
      );
    });

    test('Solar Hijri month and year boundaries map to actual dates', () {
      const calendar = CalendarService.solarHijri;
      expect(
        CalendarService.startOfMonth(DateTime(2025, 5, 10), calendar: calendar),
        DateTime(2025, 4, 21),
      );
      expect(
        CalendarService.startOfYear(DateTime(2025, 3, 21), calendar: calendar),
        DateTime(2025, 3, 21),
      );
    });

    test(
      'display parsing preserves date-only values and uses Kabul for UTC',
      () {
        expect(
          CalendarService.dateForDisplay('2025-03-20'),
          DateTime(2025, 3, 20),
        );
        expect(
          CalendarService.dateForDisplay('2025-03-20T20:00:00Z'),
          DateTime(2025, 3, 21),
        );
        expect(CalendarService.dateForDisplay('not a date'), isNull);
      },
    );

    test(
      'date formatting uses the active app locale and calendar by default',
      () {
        final oldCalendar = CalendarService.activeCalendar;
        final oldLocale = CalendarService.activeLocale;
        final oldBoth = CalendarService.showBothDates;
        CalendarService.activeCalendar = CalendarService.solarHijri;
        CalendarService.activeLocale = 'ps';
        CalendarService.showBothDates = false;
        expect(
          formatDate('2025-03-21'),
          '1 ${CalendarService.solarMonthName(1, 'ps')} 1404',
        );
        CalendarService.activeCalendar = oldCalendar;
        CalendarService.activeLocale = oldLocale;
        CalendarService.showBothDates = oldBoth;
      },
    );

    test(
      'Pashto and Dari month names and secondary calendar labels are readable',
      () {
        expect(CalendarService.solarMonthName(1, 'ps'), 'وری');
        expect(CalendarService.solarMonthName(1, 'fa_AF'), 'حمل');
        expect(
          CalendarService.format(
            DateTime(2025, 3, 21),
            calendar: CalendarService.gregorian,
            locale: 'fa_AF',
          ),
          '21 مارچ 2025',
        );

        final oldCalendar = CalendarService.activeCalendar;
        final oldBoth = CalendarService.showBothDates;
        CalendarService.activeCalendar = CalendarService.gregorian;
        CalendarService.showBothDates = true;
        expect(
          CalendarService.formatActive(DateTime(2025, 3, 21), locale: 'ps'),
          contains('لمریز: 1 وری 1404'),
        );
        CalendarService.activeCalendar = oldCalendar;
        CalendarService.showBothDates = oldBoth;
      },
    );

    test('calendar month/year starts preserve the same actual date basis', () {
      final date = DateTime(2025, 3, 21);
      expect(
        CalendarService.startOfYear(date, calendar: CalendarService.solarHijri),
        DateTime(2025, 3, 21),
      );
      expect(
        CalendarService.startOfYear(date, calendar: CalendarService.gregorian),
        DateTime(2025, 1, 1),
      );
      expect(
        CalendarService.toGregorian(
          CalendarService.fromGregorian(DateTime(2025, 3, 20)),
        ),
        DateTime(2025, 3, 20),
      );
    });

    test('calendar preference defaults to Solar Hijri and persists', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final folder = await Directory.systemTemp.createTemp('calendar_pref_');
      final path = '${folder.path}${Platform.pathSeparator}settings.db';
      var database = await ShopDatabase.openAt(path);
      var controller = LocaleController(database);
      await controller.load(database.settings());
      expect(controller.calendar, CalendarService.solarHijri);
      expect(controller.showBothDates, isFalse);
      await controller.setCalendar(CalendarService.gregorian);
      await controller.setShowBothDates(true);
      controller.dispose();
      await database.db.close();

      database = await ShopDatabase.openAt(path);
      controller = LocaleController(database);
      await controller.load(database.settings());
      expect(controller.calendar, CalendarService.gregorian);
      expect(controller.showBothDates, isTrue);
      controller.dispose();
      await database.db.close();
      await folder.delete(recursive: true);
    });
  });
}
