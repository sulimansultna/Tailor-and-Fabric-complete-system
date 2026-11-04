import 'package:flutter/material.dart';

import '../data/shop_database.dart';
import '../core/calendar_service.dart';

class LocaleController extends ChangeNotifier {
  LocaleController(this._database);

  final ShopDatabase _database;
  Locale _locale = const Locale('ps');
  bool _changedBeforeLoad = false;
  String _calendar = CalendarService.solarHijri;
  bool _showBothDates = false;
  bool _calendarChangedBeforeLoad = false;

  Locale get locale => _locale;
  String get calendar => _calendar;
  bool get showBothDates => _showBothDates;

  Future<void> load(Future<Map<String, Object?>> settingsFuture) async {
    final settings = await settingsFuture;
    if (!_changedBeforeLoad) {
      _locale = parse(settings['language']);
      CalendarService.activeLocale = _locale.toLanguageTag();
      notifyListeners();
    }
    if (!_calendarChangedBeforeLoad) {
      _calendar = settings['calendar_type'] == CalendarService.gregorian
          ? CalendarService.gregorian
          : CalendarService.solarHijri;
      _showBothDates = settings['show_both_dates'] == 'true';
      CalendarService.activeCalendar = _calendar;
      CalendarService.showBothDates = _showBothDates;
      notifyListeners();
    }
  }

  Future<void> reloadFromDatabase() async {
    final settings = await _database.settings();
    _changedBeforeLoad = false;
    _calendarChangedBeforeLoad = false;
    _locale = parse(settings['language']);
    _calendar = settings['calendar_type'] == CalendarService.gregorian
        ? CalendarService.gregorian
        : CalendarService.solarHijri;
    _showBothDates = settings['show_both_dates'] == 'true';
    CalendarService.activeLocale = _locale.toLanguageTag();
    CalendarService.activeCalendar = _calendar;
    CalendarService.showBothDates = _showBothDates;
    notifyListeners();
  }

  Future<void> setLocale(Locale value) async {
    _changedBeforeLoad = true;
    final next = parse(value.toLanguageTag());
    if (next != _locale) {
      _locale = next;
      CalendarService.activeLocale = next.toLanguageTag();
      notifyListeners();
    }
    await _database.saveSettings({'language': next.toLanguageTag()});
  }

  Future<void> setCalendar(String value) async {
    _calendarChangedBeforeLoad = true;
    _calendar = value == CalendarService.gregorian
        ? CalendarService.gregorian
        : CalendarService.solarHijri;
    CalendarService.activeCalendar = _calendar;
    notifyListeners();
    await _database.saveSettings({'calendar_type': _calendar});
  }

  Future<void> setShowBothDates(bool value) async {
    _calendarChangedBeforeLoad = true;
    _showBothDates = value;
    CalendarService.showBothDates = value;
    notifyListeners();
    await _database.saveSettings({'show_both_dates': value.toString()});
  }

  static Locale parse(Object? storedValue) {
    final value = '$storedValue'.trim().toLowerCase().replaceAll('-', '_');
    return switch (value) {
      'en' || 'english' => const Locale('en'),
      'fa' || 'fa_af' || 'dari' => const Locale('fa', 'AF'),
      'ps' || 'pashto' || 'pushto' => const Locale('ps'),
      _ => const Locale('ps'),
    };
  }

  static String nativeName(Locale locale) => switch (locale.languageCode) {
    'en' => 'English',
    'fa' => 'دری',
    _ => 'پښتو',
  };

  static const supportedLocales = <Locale>[
    Locale('ps'),
    Locale('fa', 'AF'),
    Locale('en'),
  ];
}
