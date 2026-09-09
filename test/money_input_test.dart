import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sitemanager/utils/money.dart';
import 'package:sitemanager/utils/money_input.dart';

void main() {
  TextEditingValue fmt(TextInputFormatter f, String text) =>
      f.formatEditUpdate(
        const TextEditingValue(),
        TextEditingValue(text: text),
      );

  test('MoneyInputFormatter accepts digits and decimal dot/comma', () {
    const f = MoneyInputFormatter();
    expect(fmt(f, '1234567').text, '1234567');
    expect(fmt(f, '850.50').text, '850.50');
    expect(fmt(f, '1234.5678').text, '1234.56');
    expect(fmt(f, '1,234').text, '1234');       // thousands comma
    expect(fmt(f, '123,45').text, '123.45');     // decimal comma
    expect(fmt(f, '1,234,56').text, '1234.56');  // thousands + decimal comma
    expect(fmt(f, '123.').text, '123.');          // trailing dot preserved
    expect(fmt(f, '123,').text, '123.');          // trailing comma → dot
    // European thousands + decimal comma must keep full value.
    expect(fmt(f, '1.234,56').text, '1234.56');
    expect(fmt(f, '1,234.56').text, '1234.56');
    expect(fmt(f, '150.000,5').text, '150000.5');
  });

  test('PhoneInputFormatter groups Turkish numbers without country code', () {
    const f = PhoneInputFormatter();
    expect(fmt(f, '05321234567').text, '0532 123 45 67');
    expect(fmt(f, '5321234567').text, '532 123 45 67');
  });

  test('PhoneInputFormatter groups numbers with a leading country code', () {
    const f = PhoneInputFormatter();
    expect(fmt(f, '+905321234567').text, '+90 532 123 45 67');
  });

  test('tryParseMoney agrees with the input formatter on separators', () {
    // A comma with >2 trailing digits is thousands, not a decimal marker.
    expect(tryParseMoney('1,234'), 123400);
    // Dot is always decimal, matching the formatter's "1.234" -> "1.23".
    expect(tryParseMoney('1.234'), 123);
    expect(tryParseMoney('1,234,56'), 123456);
    expect(tryParseMoney('1,234.56'), 123456);
    expect(tryParseMoney('150.000,5'), 15000050);
    expect(tryParseMoney('123,45'), 12345);
    expect(tryParseMoney('850'), 85000);
  });

  test('parse + format round-trip keeps exact minor units', () {
    for (final s in ['850', '850.5', '1,234', '1,234,56', '150.000,5']) {
      const f = MoneyInputFormatter();
      final normalized = fmt(f, s).text;
      final parsed = tryParseMoney(normalized);
      expect(parsed, tryParseMoney(s), reason: 'formatter + parser drift: $s');
      if (parsed != null) {
        expect(tryParseMoney(moneyInputText(parsed)), parsed);
      }
    }
  });
}