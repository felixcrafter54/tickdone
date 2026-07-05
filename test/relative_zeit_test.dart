// Tests für die relativen Zeitangaben (Design-Doc, Abschnitt 8)
// und das kurze Fälligkeitsdatum (MS-To-Do-Stil).
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/ui/relative_zeit.dart';

void main() {
  // Fester Bezugspunkt: Sonntag, 5. Juli 2026, 15:00.
  final jetzt = DateTime(2026, 7, 5, 15);

  group('faelligText', () {
    test('Gestern / Heute / Morgen', () {
      expect(faelligText(DateTime(2026, 7, 4), jetzt: jetzt), 'Gestern');
      expect(faelligText(DateTime(2026, 7, 5), jetzt: jetzt), 'Heute');
      expect(faelligText(DateTime(2026, 7, 6), jetzt: jetzt), 'Morgen');
    });

    test('gleiches Jahr: Wochentag + Tag + Monat ohne Jahr', () {
      // 7. Juli 2026 ist ein Dienstag.
      expect(faelligText(DateTime(2026, 7, 7), jetzt: jetzt), 'Di, 7. Jul');
    });

    test('anderes Jahr: mit Jahresangabe', () {
      // 7. Januar 2027 ist ein Donnerstag.
      expect(faelligText(DateTime(2027, 1, 7), jetzt: jetzt),
          'Do, 7. Jan 2027');
    });
  });

  test('unter einer Minute: gerade eben', () {
    expect(
        relativeZeit(jetzt.subtract(const Duration(seconds: 30)),
            jetzt: jetzt),
        'gerade eben');
  });

  test('unter einer Stunde: vor X Minuten (mit Singular)', () {
    expect(
        relativeZeit(jetzt.subtract(const Duration(minutes: 1)),
            jetzt: jetzt),
        'vor 1 Minute');
    expect(
        relativeZeit(jetzt.subtract(const Duration(minutes: 45)),
            jetzt: jetzt),
        'vor 45 Minuten');
  });

  test('unter 24 Stunden: vor X Stunden (mit Singular)', () {
    expect(
        relativeZeit(jetzt.subtract(const Duration(hours: 1)), jetzt: jetzt),
        'vor 1 Stunde');
    expect(
        relativeZeit(jetzt.subtract(const Duration(hours: 20)),
            jetzt: jetzt),
        'vor 20 Stunden');
  });

  test('unter 7 Tagen: ausgeschriebener Wochentag', () {
    // 3. Juli 2026 war ein Freitag.
    expect(relativeZeit(DateTime(2026, 7, 3, 12), jetzt: jetzt), 'Freitag');
  });

  test('gleiches Jahr: Tag und Monat', () {
    expect(relativeZeit(DateTime(2026, 6, 25), jetzt: jetzt), '25. Juni');
  });

  test('älteres Jahr: Tag, Monat und Jahr', () {
    expect(
        relativeZeit(DateTime(2024, 6, 25), jetzt: jetzt), '25. Juni 2024');
  });
}
