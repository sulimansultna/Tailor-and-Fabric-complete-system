import 'package:test/test.dart';
import 'package:tailor_shop/core/phone.dart';

void main() {
  group('Afghan phone normalization', () {
    test('converts Dari and Arabic digits and removes separators', () {
      expect(normalizePhone('۰۷۰-۱۲۳ ۴۵۶۷'), '0701234567');
      expect(normalizePhone('٠٧٠ ١٢٣ ٤٥٦٧'), '0701234567');
    });

    test('keeps an international prefix', () {
      expect(normalizePhone('+93 (70) 123-4567'), '+93701234567');
    });
  });
}
