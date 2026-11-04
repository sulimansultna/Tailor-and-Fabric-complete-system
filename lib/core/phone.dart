/// Normalizes Afghan and localized phone input without discarding an optional
/// international dialing prefix.
String normalizePhone(String value) {
  const localized = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩';
  const latin = '01234567890123456789';
  var result = value;
  for (var i = 0; i < localized.length; i++) {
    result = result.replaceAll(localized[i], latin[i]);
  }
  return result.replaceAll(RegExp(r'[^0-9+]'), '');
}
