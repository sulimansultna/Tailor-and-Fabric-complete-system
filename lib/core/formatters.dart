import 'package:intl/intl.dart';

import 'calendar_service.dart';

String formatMoney(int amount, {String locale = 'en'}) => NumberFormat.currency(
  locale: locale.replaceAll('_', '-'),
  name: 'AFN',
  symbol: 'AFN',
  decimalDigits: 0,
).format((amount / 100).round());

/// Formats stored minor-unit amounts without discarding fractional AFN values.
/// Whole AFN amounts stay compact; values with minor units show two decimals.
String formatPaymentMoney(int amount, {String locale = 'en'}) {
  final normalizedLocale = locale.replaceAll('_', '-');
  final value = amount.abs() % 100 == 0
      ? NumberFormat.decimalPattern(normalizedLocale).format(amount ~/ 100)
      : NumberFormat.decimalPatternDigits(
          locale: normalizedLocale,
          decimalDigits: 2,
        ).format(amount / 100);
  return '$value AFN';
}

String formatDate(String value, {String? locale}) {
  final parsed = CalendarService.dateForDisplay(value);
  if (parsed == null) {
    return value.length >= 10 ? value.substring(0, 10) : value;
  }
  return CalendarService.formatActive(
    parsed,
    locale: locale ?? CalendarService.activeLocale,
  );
}

String normalizeLocalizedDigits(String value) {
  const localizedDigits = <String, String>{
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };
  final normalized = StringBuffer();
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (localizedDigits.containsKey(character)) {
      normalized.write(localizedDigits[character]);
    } else if (character == '٫') {
      normalized.write('.');
    } else if (character == '٬' || character == '،' || character == ',') {
      continue;
    } else {
      normalized.write(character);
    }
  }
  return normalized.toString();
}

int? parseMoneyMinor(String value) {
  final normalized = normalizeLocalizedDigits(value).replaceAll(',', '').trim();
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
  final parts = normalized.split('.');
  final whole = int.tryParse(parts.first);
  if (whole == null) return null;
  final fraction = parts.length == 1
      ? 0
      : int.parse(parts.last.padRight(2, '0'));
  return whole * 100 + fraction;
}
