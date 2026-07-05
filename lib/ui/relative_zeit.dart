/// Relative Zeitangaben nach TICKDONE_DESIGN.md, Abschnitt 8.
library;

const _wochentage = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];

const _monate = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

/// Formatiert einen Zeitpunkt relativ zu [jetzt] (Standard: aktuelle Zeit):
/// "gerade eben" → "vor X Minuten" → "vor X Stunden" → Wochentag →
/// "25. Juni" → "25. Juni 2024".
String relativeZeit(DateTime zeitpunkt, {DateTime? jetzt}) {
  final referenz = jetzt ?? DateTime.now();
  final lokal = zeitpunkt.toLocal();
  final abstand = referenz.difference(lokal);

  if (abstand.inMinutes < 1) return 'gerade eben';
  if (abstand.inHours < 1) {
    final minuten = abstand.inMinutes;
    return minuten == 1 ? 'vor 1 Minute' : 'vor $minuten Minuten';
  }
  if (abstand.inHours < 24) {
    final stunden = abstand.inHours;
    return stunden == 1 ? 'vor 1 Stunde' : 'vor $stunden Stunden';
  }
  if (abstand.inDays < 7) return _wochentage[lokal.weekday - 1];
  if (lokal.year == referenz.year) {
    return '${lokal.day}. ${_monate[lokal.month - 1]}';
  }
  return '${lokal.day}. ${_monate[lokal.month - 1]} ${lokal.year}';
}
