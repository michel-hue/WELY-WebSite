import '../features/listings/models.dart';

const _thin = ' ';

/// `650000` -> `650 000 F` (espace fine insécable entre les milliers).
String formatPrice(int amount) {
  final digits = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(_thin);
    buf.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buf F';
}

String priceSuffix(OfferType type) => switch (type) {
      OfferType.monthly => '/ mois',
      OfferType.nightly => '/ nuit',
      OfferType.sale => '',
    };

/// `800` -> `800 m`, `1234` -> `1,2 km`.
String formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = (meters / 100).round() / 10;
  final s = km.toStringAsFixed(1).replaceAll('.', ',');
  return '${s.endsWith(',0') ? s.substring(0, s.length - 2) : s} km';
}

const _monthsShort = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const _monthsLong = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// `1 déc.` ; avec [long] : `1er décembre` (+ année si [withYear]).
String formatDate(DateTime d, {bool long = false, bool withYear = false}) {
  final day = long && d.day == 1 ? '1er' : '${d.day}';
  final month = (long ? _monthsLong : _monthsShort)[d.month - 1];
  return '$day $month${withYear ? ' ${d.year}' : ''}';
}
