String moneySymbol(String currency) {
  switch (currency) {
    case 'EUR':
      return '€';
    case 'USD':
      return '\$';
    case 'GBP':
      return '£';
    case 'TRY':
      return '₺';
    case 'INR':
      return '₹';
    case 'RUB':
      return '₽';
    default:
      return '$currency ';
  }
}

/// Formats an exact minor-unit (cents) amount with thousands separators and up
/// to 2 fractional digits (trailing zeros trimmed), e.g. 85050 -> "€850.5".
///
/// Money is stored and summed in minor units throughout the app — this keeps
/// every arithmetic operation exact and avoids floating-point drift.
/// Formats minor units as a grouped number without a currency symbol, e.g.
/// 85050 -> "850.5". Shared by [money] and [StatCard] so the two can never
/// drift apart.
String moneyNumber(int cents) {
  final neg = cents < 0;
  final c = cents.abs();
  final whole = c ~/ 100;
  var frac = (c % 100).toString().padLeft(2, '0');
  while (frac.endsWith('0') && frac.length > 1) {
    frac = frac.substring(0, frac.length - 1);
  }
  final out = frac == '0'
      ? _group(whole.toString())
      : '${_group(whole.toString())}.$frac';
  return neg ? '-$out' : out;
}

String money(int cents, {String currency = 'EUR'}) {
  final neg = cents < 0;
  final body = moneyNumber(cents);
  return '${neg ? '-' : ''}${moneySymbol(currency)}${neg ? body.substring(1) : body}';
}

/// Renders minor units as plain editable text without symbol or grouping, for
/// pre-filling input fields. 85050 -> '850.5', 100 -> '1', -500 -> '-5'.
String moneyInputText(int cents) {
  final neg = cents < 0;
  final c = cents.abs();
  final whole = c ~/ 100;
  var frac = (c % 100).toString().padLeft(2, '0');
  while (frac.endsWith('0') && frac.length > 1) {
    frac = frac.substring(0, frac.length - 1);
  }
  final out = frac.isEmpty || frac == '0' ? '$whole' : '$whole.$frac';
  return neg ? '-$out' : out;
}

/// Parses user-typed money into an EXACT minor-unit (percent / cent) amount,
/// or null when it isn't a valid number. Accepts any of these styles:
///   '850' / '850.5' / '850,5' / '1,234.56' / '1.234,56' / '1 234,56'
///
/// Locale logic: the LAST separator char (comma or dot) is the decimal
/// separator; earlier ones are thousands separators. Strings split by string
/// math only — no double is ever involved, so nothing is silently corrupted.
final _wsRe = RegExp(r'\s');
final _nonMoneyRe = RegExp(r'[^\d,.]');
final _nonDigitRe = RegExp(r'[^\d]');
const _maxWhole = 9007199254740991;

int? tryParseMoney(String s) {
  var raw = s.trim().replaceAll(_wsRe, '');
  if (raw.isEmpty) return null;

  final neg = raw.startsWith('-');
  raw = raw.replaceAll('-', '');
  if (raw.isEmpty) return null;
  raw = raw.replaceAll(_nonMoneyRe, '');
  if (raw.isEmpty) return null;

  String intPart;
  String fracPart;
  final lastComma = raw.lastIndexOf(',');
  final lastDot = raw.lastIndexOf('.');

  if (lastComma != -1 || lastDot != -1) {
    // The later of the two separator chars is the decimal separator.
    final decPos = lastComma > lastDot ? lastComma : lastDot;
    final sep = decPos == lastComma ? ',' : '.';
    var rawInt = raw.substring(0, decPos);
    var rawFrac = raw.substring(decPos + 1);
    // Guard against a stray separator left at the end ("850." or "850,").
    if (rawFrac.contains(sep)) rawFrac = rawFrac.split(sep).first;
    // European thousands: a comma followed by more than 2 digits is a
    // grouping separator ("1,234"), not a decimal marker — mirror the input
    // formatter so parsing and typing always agree.
    if (sep == ',' && rawFrac.replaceAll(_nonDigitRe, '').length > 2) {
      rawInt = raw.replaceAll(',', '');
      rawFrac = '';
    }
    intPart = rawInt.replaceAll(_nonDigitRe, '');
    fracPart = rawFrac.replaceAll(_nonDigitRe, '');
  } else {
    intPart = raw;
    fracPart = '';
  }

  if (intPart.isEmpty) intPart = '0';

  // Truncate to 2 fraction digits (never round — matches the input formatter).
  if (fracPart.length > 2) fracPart = fracPart.substring(0, 2);
  if (fracPart.isEmpty) fracPart = '0';
  fracPart = fracPart.padRight(2, '0');

  final whole = int.tryParse(intPart);
  final frac = int.tryParse(fracPart);
  if (whole == null || frac == null) return null;

  // Guard against absurd inputs overflowing 64-bit ints.
  if (whole > _maxWhole) return null;

  final cents = whole * 100 + frac;
  return neg ? -cents : cents;
}

String _group(String digits) {
  if (digits.isEmpty) return '0';
  final buf = StringBuffer();
  final n = digits.length;
  for (var i = 0; i < n; i++) {
    buf.write(digits[i]);
    final remaining = n - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buf.write(',');
  }
  return buf.toString();
}