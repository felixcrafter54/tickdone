// Tests für die relativen Zeitangaben (Design-Doc, Abschnitt 8).
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/ui/relative_zeit.dart';

void main() {
  // Fester Bezugspunkt: Sonntag, 5. Juli 2026, 15:00.
  final jetzt = DateTime(2026, 7, 5, 15);

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
