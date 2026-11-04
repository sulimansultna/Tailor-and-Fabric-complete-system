import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class PashtoCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const PashtoCupertinoLocalizations();

  static const months = <String>[
    'جنوري',
    'فبروري',
    'مارچ',
    'اپرېل',
    'مۍ',
    'جون',
    'جولای',
    'اګست',
    'سپتمبر',
    'اکتوبر',
    'نومبر',
    'دسمبر',
  ];

  static const shortWeekdays = <String>[
    'دوش',
    'سې ش',
    'چهار',
    'پنج',
    'جمعه',
    'شنبه',
    'یک',
  ];

  @override
  String datePickerMonth(int monthIndex) => months[monthIndex - 1];

  @override
  String datePickerStandaloneMonth(int monthIndex) => months[monthIndex - 1];

  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) => weekDay == null
      ? '$dayIndex'
      : '${shortWeekdays[weekDay - DateTime.monday]} $dayIndex';

  @override
  String datePickerMediumDate(DateTime date) =>
      '${shortWeekdays[date.weekday - DateTime.monday]} '
      '${months[date.month - 1]} ${date.day}';

  @override
  DatePickerDateOrder get datePickerDateOrder => DatePickerDateOrder.dmy;

  @override
  DatePickerDateTimeOrder get datePickerDateTimeOrder =>
      DatePickerDateTimeOrder.date_time_dayPeriod;

  @override
  String datePickerHourSemanticsLabel(int hour) => '$hour بجې';

  @override
  String datePickerMinuteSemanticsLabel(int minute) => '$minute دقیقې';

  @override
  String get anteMeridiemAbbreviation => 'ق.ظ.';

  @override
  String get postMeridiemAbbreviation => 'ب.ظ.';

  @override
  String get todayLabel => 'نن';

  @override
  String get alertDialogLabel => 'خبرتیا';

  @override
  String tabSemanticsLabel({required int tabIndex, required int tabCount}) =>
      'ټب $tabIndex له $tabCount څخه';

  @override
  String timerPickerHourLabel(int hour) => 'ساعت';

  @override
  List<String> get timerPickerHourLabels => const ['ساعت'];

  @override
  String timerPickerMinuteLabel(int minute) => 'دقیقه';

  @override
  List<String> get timerPickerMinuteLabels => const ['دقیقه'];

  @override
  String timerPickerSecondLabel(int second) => 'ثانیه';

  @override
  List<String> get timerPickerSecondLabels => const ['ثانیه'];

  @override
  String get cutButtonLabel => 'پرې کول';

  @override
  String get copyButtonLabel => 'کاپي';

  @override
  String get pasteButtonLabel => 'نښلول';

  @override
  String get clearButtonLabel => 'پاکول';

  @override
  String get noSpellCheckReplacementsLabel => 'بدیل ونه موندل شو';

  @override
  String get selectAllButtonLabel => 'ټول ټاکل';

  @override
  String get lookUpButtonLabel => 'پلټل';

  @override
  String get searchWebButtonLabel => 'په وېب کې لټون';

  @override
  String get shareButtonLabel => 'شریکول';

  @override
  String get searchTextFieldPlaceholderLabel => 'لټون';

  @override
  String get modalBarrierDismissLabel => 'بندول';

  @override
  String get menuDismissLabel => 'مینو بندول';

  @override
  String get cancelButtonLabel => 'لغوه';

  @override
  String get backButtonLabel => 'شاته';

  @override
  String get expansionTileExpandedHint => 'د بندولو لپاره دوه ځله کېکاږئ';

  @override
  String get expansionTileCollapsedHint => 'د پرانیستلو لپاره دوه ځله کېکاږئ';

  @override
  String get expansionTileExpandedTapHint => 'بندول';

  @override
  String get expansionTileCollapsedTapHint => 'د نورو جزیاتو لپاره پرانیستل';

  @override
  String get expandedHint => 'بند شوی';

  @override
  String get collapsedHint => 'پرانېستل شوی';
}

class TailorShopCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const TailorShopCupertinoLocalizationsDelegate();

  static const delegate = TailorShopCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const {'ps', 'fa', 'en'}.contains(locale.languageCode);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      locale.languageCode == 'ps'
      ? SynchronousFuture(const PashtoCupertinoLocalizations())
      : GlobalCupertinoLocalizations.delegate.load(locale);

  @override
  bool shouldReload(TailorShopCupertinoLocalizationsDelegate old) => false;
}
