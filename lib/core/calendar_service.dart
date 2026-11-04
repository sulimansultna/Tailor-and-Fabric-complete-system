/// Offline Afghan Solar Hijri (Jalali) calendar conversion and date helpers.
/// Dates enter and leave this service as Gregorian DateTime values (canonical).
class CalendarService {
  CalendarService._();

  static String activeCalendar = solarHijri;
  static String activeLocale = 'ps';
  static bool showBothDates = false;

  /// Date-only operations use Kabul when the shop has no timezone setting.
  static DateTime shopToday() {
    final kabulNow = DateTime.now().toUtc().add(
      const Duration(hours: 4, minutes: 30),
    );
    return DateTime(kabulNow.year, kabulNow.month, kabulNow.day);
  }

  static const solarHijri = 'solar_hijri';
  static const gregorian = 'gregorian';
  static const _breaks = <int>[
    -61,
    9,
    38,
    199,
    426,
    686,
    756,
    818,
    1111,
    1181,
    1210,
    1635,
    2060,
    2097,
    2192,
    2262,
    2324,
    2394,
    2456,
    3178,
  ];
  static const _months = <String, List<String>>{
    'en': [
      'Hamal',
      'Sawer',
      'Jawza',
      'Saratan',
      'Asad',
      'Sonbola',
      'Mizan',
      'Aqrab',
      'Qaws',
      'Jadi',
      'Dalwa',
      'Hut',
    ],
    'fa': [
      'حمل',
      'ثور',
      'جوزا',
      'سرطان',
      'اسد',
      'سنبله',
      'میزان',
      'عقرب',
      'قوس',
      'جدی',
      'دلو',
      'حوت',
    ],
    'ps': [
      'وری',
      'غویی',
      'غبرګولی',
      'چنګاښ',
      'زمری',
      'وږی',
      'تله',
      'لړم',
      'لیندۍ',
      'مرغومی',
      'سلواغه',
      'کب',
    ],
  };
  static SolarDate fromGregorian(DateTime date) {
    final g = DateTime(date.year, date.month, date.day);
    final gy = g.year;
    final jy = gy - 621;
    final r = _jalCal(jy);
    final jdn = _gregorianToJdn(g.year, g.month, g.day);
    final newYearJdn = _gregorianToJdn(gy, 3, r.march);
    var year = jy;
    var k = jdn - newYearJdn;
    if (k < 0) {
      year--;
      k += isLeapYear(year) ? 366 : 365;
    }
    final month = k < 186 ? 1 + k ~/ 31 : 7 + (k - 186) ~/ 30;
    final day = 1 + (k < 186 ? k % 31 : (k - 186) % 30);
    return SolarDate(year, month, day);
  }

  static DateTime toGregorian(SolarDate date) {
    if (date.month < 1 ||
        date.month > 12 ||
        date.day < 1 ||
        date.day > monthLength(date.year, date.month)) {
      throw ArgumentError('Invalid Solar Hijri date: $date');
    }
    final r = _jalCal(date.year);
    final dayOfYear = date.month <= 6
        ? (date.month - 1) * 31 + date.day - 1
        : 186 + (date.month - 7) * 30 + date.day - 1;
    final jdn = _gregorianToJdn(date.year + 621, 3, r.march) + dayOfYear;
    // JDN to Gregorian date.
    var j = jdn + 32044;
    final g = j ~/ 146097;
    final dg = j % 146097;
    final c = (dg ~/ 36524 + 1) * 3 ~/ 4;
    final dc = dg - c * 36524;
    final b = dc ~/ 1461;
    final db = dc % 1461;
    final a = (db ~/ 365 + 1) * 3 ~/ 4;
    final da = db - a * 365;
    final y = g * 400 + c * 100 + b * 4 + a;
    final m = (da * 5 + 308) ~/ 153 - 2;
    final d = da - (m + 4) * 153 ~/ 5 + 122;
    final year = y - 4800 + (m + 2) ~/ 12;
    final month = (m + 2) % 12 + 1;
    final day = d + 1;
    return DateTime(year, month, day);
  }

  static int monthLength(int year, int month) => month <= 6
      ? 31
      : month <= 11
      ? 30
      : isLeapYear(year)
      ? 30
      : 29;
  static bool isLeapYear(int year) => _jalCal(year).leap == 0;
  static String solarMonthName(int month, String locale) {
    final lang = locale.split(RegExp('[-_]')).first;
    final normalized = lang == 'fa'
        ? 'fa'
        : lang == 'ps'
        ? 'ps'
        : 'en';
    return _months[normalized]![month - 1];
  }

  static String format(
    DateTime date, {
    required String calendar,
    required String locale,
    bool includeYear = true,
  }) {
    if (calendar != solarHijri) {
      final lang = locale.split(RegExp('[-_]')).first;
      final normalized = lang == 'fa'
          ? 'fa'
          : lang == 'ps'
          ? 'ps'
          : 'en';
      final value =
          '${date.day} ${_gregorianMonths[normalized]![date.month - 1]}${includeYear ? ' ${date.year}' : ''}';
      return value;
    }
    final solar = fromGregorian(date);
    final lang = locale.split(RegExp('[-_]')).first;
    final normalized = lang == 'fa'
        ? 'fa'
        : lang == 'ps'
        ? 'ps'
        : 'en';
    final months = _months[normalized]!;
    return '${solar.day} ${months[solar.month - 1]}${includeYear ? ' ${solar.year}' : ''}';
  }

  static String formatActive(DateTime date, {required String locale}) {
    final primary = format(date, calendar: activeCalendar, locale: locale);
    if (!showBothDates) return primary;
    final secondaryCalendar = activeCalendar == solarHijri
        ? gregorian
        : solarHijri;
    final secondary = format(date, calendar: secondaryCalendar, locale: locale);
    final language = locale.split(RegExp('[-_]')).first;
    final label = secondaryCalendar == solarHijri
        ? (language == 'ps'
              ? 'لمریز'
              : language == 'fa'
              ? 'هجری شمسی'
              : 'Solar Hijri')
        : (language == 'ps'
              ? 'میلادي'
              : language == 'fa'
              ? 'میلادی'
              : 'Gregorian');
    return '$primary\n$label: $secondary';
  }

  static DateTime startOfMonth(DateTime date, {required String calendar}) {
    if (calendar != solarHijri) return DateTime(date.year, date.month);
    final solar = fromGregorian(date);
    return toGregorian(SolarDate(solar.year, solar.month, 1));
  }

  static DateTime startOfYear(DateTime date, {required String calendar}) {
    if (calendar != solarHijri) return DateTime(date.year);
    final solar = fromGregorian(date);
    return toGregorian(SolarDate(solar.year, 1, 1));
  }

  static String? canonicalDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    // ISO date-only values stay date-only; timestamp values retain their instant.
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return value;
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    ).toIso8601String().substring(0, 10);
  }

  /// Convert stored timestamps to the Kabul wall date for display. Date-only
  /// database values are kept as calendar dates and never timezone shifted.
  static DateTime? dateForDisplay(String value) {
    final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    final hasExplicitOffset = RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
    final displayValue = dateOnly
        ? parsed
        : parsed.isUtc || hasExplicitOffset
        ? parsed.toUtc().add(const Duration(hours: 4, minutes: 30))
        : parsed;
    return DateTime(displayValue.year, displayValue.month, displayValue.day);
  }

  static int _gregorianToJdn(int year, int month, int day) {
    final a = (14 - month) ~/ 12;
    final y = year + 4800 - a;
    final m = month + 12 * a - 3;
    return day +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
  }

  static const _gregorianMonths = <String, List<String>>{
    'en': [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    'fa': [
      'جنوری',
      'فبروری',
      'مارچ',
      'اپریل',
      'می',
      'جون',
      'جولای',
      'آگست',
      'سپتامبر',
      'اکتوبر',
      'نوامبر',
      'دسمبر',
    ],
    'ps': [
      'جنوري',
      'فبروري',
      'مارچ',
      'اپرېل',
      'مې',
      'جون',
      'جولای',
      'اګست',
      'سپتمبر',
      'اکتوبر',
      'نومبر',
      'دسمبر',
    ],
  };
  static _JalaliResult _jalCal(int jy) {
    final gy = jy + 621;
    var leapJ = -14;
    var jp = _breaks.first;
    var jump = 0;
    for (final jm in _breaks.skip(1)) {
      jump = jm - jp;
      if (jy < jm) break;
      leapJ += (jump ~/ 33) * 8 + (jump % 33) ~/ 4;
      jp = jm;
    }
    var n = jy - jp;
    leapJ += (n ~/ 33) * 8 + ((n % 33) + 3) ~/ 4;
    if (jump % 33 == 4 && jump - n == 4) leapJ++;
    final leapG = gy ~/ 4 - ((gy ~/ 100 + 1) * 3) ~/ 4 - 150;
    final march = 20 + leapJ - leapG;
    if (jump - n < 6) n = n - jump + ((jump + 4) ~/ 33) * 33;
    var leap = (((n + 1) % 33) - 1) % 4;
    if (leap == -1) leap = 4;
    return _JalaliResult(leap, march);
  }
}

class SolarDate {
  const SolarDate(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;
  @override
  String toString() => '$year-$month-$day';
}

class _JalaliResult {
  const _JalaliResult(this.leap, this.march);
  final int leap;
  final int march;
}
