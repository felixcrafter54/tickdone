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

const _wochentageKurz = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

const _monateKurz = [
  'Jan',
  'Feb',
  'Mär',
  'Apr',
  'Mai',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Okt',
  'Nov',
  'Dez',
];

/// Kurzes Fälligkeitsdatum (MS-To-Do-Stil):
/// Gestern / Heute / Morgen, sonst "Di, 7. Jul" (Jahr nur bei Abweichung).
String faelligText(DateTime faellig, {DateTime? jetzt}) {
  final referenz = jetzt ?? DateTime.now();
  final tag = DateTime(faellig.year, faellig.month, faellig.day);
  final heute = DateTime(referenz.year, referenz.month, referenz.day);
  final diff = tag.difference(heute).inDays;

  if (diff == 0) return 'Heute';
  if (diff == 1) return 'Morgen';
  if (diff == -1) return 'Gestern';

  final wochentag = _wochentageKurz[tag.weekday - 1];
  final monat = _monateKurz[tag.month - 1];
  final basis = '$wochentag, ${tag.day}. $monat';
  return tag.year == heute.year ? basis : '$basis ${tag.year}';
}
