/// Préfixe proposé par défaut dans les champs téléphone.
const phonePrefix = '+225 ';

/// Normalise une saisie au format E.164 (Côte d'Ivoire par défaut) :
/// `07 12 34 56 78` -> `+2250712345678`. `null` si le numéro est illisible.
/// L'API revalide de toute façon (libphonenumber).
String? normalizePhone(String input) {
  var s = input.trim().replaceAll(RegExp(r'[\s.\-()]'), '');
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  if (!s.startsWith('+')) {
    // Numéro ivoirien local : 10 chiffres.
    return RegExp(r'^\d{10}$').hasMatch(s) ? '+225$s' : null;
  }
  final digits = s.substring(1);
  if (!RegExp(r'^\d+$').hasMatch(digits)) return null;
  if (digits.startsWith('225')) return digits.length == 13 ? s : null;
  return digits.length >= 8 && digits.length <= 15 ? s : null;
}
