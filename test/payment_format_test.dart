import 'package:test/test.dart';
import 'package:tailor_shop/core/formatters.dart';

void main() {
  test('payment amounts keep whole AFN compact and preserve minor units', () {
    expect(formatPaymentMoney(24000), '240 AFN');
    expect(formatPaymentMoney(24050), '240.50 AFN');
    expect(formatPaymentMoney(50), '0.50 AFN');
  });

  test('payment amount keeps a readable AFN suffix in Pashto', () {
    expect(formatPaymentMoney(24050, locale: 'ps-AF'), endsWith(' AFN'));
    expect(formatPaymentMoney(24050, locale: 'ps-AF'), contains('٫'));
  });
}
