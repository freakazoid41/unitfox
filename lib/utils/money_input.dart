import 'package:flutter/services.dart';

final _phoneStripRe = RegExp(r'[^\d+]');

/// Plain text keyboard everywhere — avoids browser-locale issues with
/// native number inputs blocking comma/dot entry.
TextInputType get moneyKeyboardType => TextInputType.text;

/// Matches the 'YYYY-MM' billing-month format used for charges and salary
/// months. Rejects zero-padding mistakes (2026-8) and out-of-range months.
final RegExp _monthRe = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

bool isValidMonth(String? v) {
  final s = (v ?? '').trim();
  return s.isNotEmpty && _monthRe.hasMatch(s);
}

/// Formats numeric money entry: digits + optional dot as decimal separator.
/// Commas are stripped (no thousands grouping). Non-numeric chars are removed.
class MoneyInputFormatter extends TextInputFormatter {
  final int decimals;

  const MoneyInputFormatter({this.decimals = 2});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String s = newValue.text;
    s = s.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.isEmpty) {
      return TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: 0),
        composing: TextRange.empty,
      );
    }

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');

    // A separator is the decimal point when it's the LATER separator, or the
    // only one typed so far ("1.234,56" -> comma; "1234.56" -> dot). Mirrors
    // tryParseMoney so the field and the parser always agree on where the
    // fraction begins.
    final decimalIsComma =
        lastComma != -1 && (lastDot == -1 || lastComma > lastDot);
    final hasDecimal = lastComma != -1 || lastDot != -1;

    var intPart = s;
    var fraction = '';

    if (hasDecimal) {
      if (decimalIsComma) {
        // European style — a comma with > [decimals] trailing digits is a
        // thousands separator, not a fraction marker ("1,234").
        final digitsAfter = s
            .substring(lastComma + 1)
            .replaceAll(RegExp(r'[^\d]'), '')
            .length;
        if (digitsAfter > decimals) {
          intPart = s.replaceAll(',', '');
          fraction = '';
        } else {
          intPart = s.substring(0, lastComma);
          fraction = s.substring(lastComma + 1);
        }
      } else {
        intPart = s.substring(0, lastDot);
        fraction = s.substring(lastDot + 1);
      }
    }

    intPart = intPart.replaceAll(RegExp(r'[^\d]'), '');
    fraction = fraction.replaceAll(RegExp(r'[^\d]'), '');
    if (fraction.length > decimals) fraction = fraction.substring(0, decimals);
    if (intPart.isEmpty) intPart = '0';

    // A separator typed with no fraction digits yet ("123." / "123,") must
    // stay visible so the user can keep typing decimals.
    final trailingSeparator =
        hasDecimal && !decimalIsComma && fraction.isEmpty && lastDot != -1
            ? true
            : hasDecimal &&
                    decimalIsComma &&
                    fraction.isEmpty &&
                    lastComma + 1 >= s.length
                ? true
                : false;
    final hasDotTrailing =
        hasDecimal && (fraction.isNotEmpty || trailingSeparator);

    final out = !hasDecimal
        ? intPart
        : hasDotTrailing
            ? '$intPart.$fraction'
            : intPart;

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
      composing: TextRange.empty,
    );
  }
}

/// Formats a phone number inline as digits + optional leading '+'. Turkish
/// grouping: `+90 532 123 45 67` (12 digits after '+') or `0532 123 45 67`
/// without a country code. Non-numeric characters are stripped automatically.
class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String s = newValue.text.replaceAll(_phoneStripRe, '');
    if (s.startsWith('+') && s.indexOf('+', 1) != -1) {
      s = s.substring(0, 1) + s.substring(1).replaceAll('+', '');
    } else if (s.indexOf('+') > 0) {
      s = s.replaceAll('+', '');
    }
    final hasPlus = s.startsWith('+');
    final digits = s.replaceAll('+', '');
    // Cap at 15 digits (longest E.164 number) so international formats aren't
    // silently dropped.
    final trimmed = digits.length > 15 ? digits.substring(0, 15) : digits;

    final buf = StringBuffer();
    if (hasPlus) buf.write('+');
    // Group sizes (by country, common formats):
    //   +90 532 123 45 67   -> 2 + 3-3-2-2
    //   0532 123 45 67      -> leading 0: 4-3-2-2
    //   532 123 45 67       -> otherwise: 3-3-2-2
    final sizes = hasPlus
        ? const [2, 3, 3, 2, 2]
        : (trimmed.isNotEmpty && trimmed[0] == '0'
            ? const [4, 3, 2, 2]
            : const [3, 3, 2, 2]);
    var idx = 0;
    for (final size in sizes) {
      if (idx >= trimmed.length) break;
      if (idx > 0) buf.write(' ');
      final end = idx + size > trimmed.length ? trimmed.length : idx + size;
      buf.write(trimmed.substring(idx, end));
      idx = end;
    }
    // Append any remaining digits that didn't fit the predefined group sizes
    // (e.g. longer E.164 numbers) instead of silently dropping them.
    if (idx < trimmed.length) {
      buf.write(' ');
      buf.write(trimmed.substring(idx));
    }
    final out = buf.toString();
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
      composing: TextRange.empty,
    );
  }
}