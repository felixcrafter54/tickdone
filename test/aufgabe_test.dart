// Tests für das Parsen von VTODO-iCalendar ins Aufgaben-Model.
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/models/aufgabe.dart';

/// Baut ein minimales VCALENDAR um die übergebenen VTODO-Zeilen.
String vtodoIcal(List<String> zeilen) => [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Test//DE',
      'BEGIN:VTODO',
      'UID:test-uid-1',
      'DTSTAMP:20260705T120000Z',
      ...zeilen,
      'END:VTODO',
      'END:VCALENDAR',
    ].join('\r\n');

void main() {
  group('Aufgabe.ausICalendar', () {
    test('parst die Grundfelder', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Einkaufen gehen',
        'DESCRIPTION:Milch und Brot',
        'DUE;VALUE=DATE:20260710',
        'PRIORITY:1',
        'PERCENT-COMPLETE:40',
        'SEQUENCE:3',
        'CREATED:20260701T080000Z',
      ]))!;

      expect(aufgabe.uid, 'test-uid-1');
      expect(aufgabe.titel, 'Einkaufen gehen');
      expect(aufgabe.notiz, 'Milch und Brot');
      expect(aufgabe.faellig, DateTime(2026, 7, 10));
      expect(aufgabe.prioritaet, 1);
      expect(aufgabe.prozent, 40);
      expect(aufgabe.sequence, 3);
      expect(aufgabe.erstellt, DateTime.utc(2026, 7, 1, 8));
      expect(aufgabe.erledigt, isFalse);
      expect(aufgabe.istSchritt, isFalse);
    });

    test('escapte Sonderzeichen im Titel werden aufgelöst', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        r'SUMMARY:Einkaufen\; Obst\, Gemüse',
      ]))!;
      expect(aufgabe.titel, 'Einkaufen; Obst, Gemüse');
    });

    test('fehlender STATUS bedeutet offen, COMPLETED bedeutet erledigt', () {
      final ohneStatus = Aufgabe.ausICalendar(vtodoIcal(['SUMMARY:A']))!;
      expect(ohneStatus.erledigt, isFalse);

      final erledigt = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:B',
        'STATUS:COMPLETED',
      ]))!;
      expect(erledigt.erledigt, isTrue);
    });

    test('RELATED-TO ohne RELTYPE zählt als Elternverweis', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Schritt',
        'RELATED-TO:eltern-uid',
      ]))!;
      expect(aufgabe.parentUid, 'eltern-uid');
      expect(aufgabe.istSchritt, isTrue);
    });

    test('RELATED-TO mit RELTYPE=PARENT zählt als Elternverweis', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Schritt',
        'RELATED-TO;RELTYPE=PARENT:eltern-uid',
      ]))!;
      expect(aufgabe.parentUid, 'eltern-uid');
    });

    test('RELATED-TO mit RELTYPE=CHILD wird ignoriert', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Eltern-Aufgabe',
        'RELATED-TO;RELTYPE=CHILD:kind-uid',
      ]))!;
      expect(aufgabe.parentUid, isNull);
      expect(aufgabe.istSchritt, isFalse);
    });

    test('mehrwertiges RELATED-TO (jtx Board): nur PARENT zählt', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Schritt',
        'RELATED-TO;RELTYPE=CHILD:kind-uid',
        'RELATED-TO;RELTYPE=PARENT:eltern-uid',
      ]))!;
      expect(aufgabe.parentUid, 'eltern-uid');
    });

    test('CATEGORIES-Marker: FAVORITE und tagesaktueller MYDAY', () {
      final heute = DateTime(2026, 7, 5);
      final aufgabe = Aufgabe.ausICalendar(
        vtodoIcal([
          'SUMMARY:Wichtig',
          'CATEGORIES:FAVORITE,MYDAY-2026-07-05',
        ]),
        heute: heute,
      )!;
      expect(aufgabe.favorit, isTrue);
      // FAVORITE aus Bestandsdaten zählt als "wichtig".
      expect(aufgabe.wichtig, isTrue);
      expect(aufgabe.meinTag, isTrue);
    });

    test('alte FELIX-MYDAY-Schreibweise wird beim Lesen erkannt', () {
      final aufgabe = Aufgabe.ausICalendar(
        vtodoIcal([
          'SUMMARY:Alt markiert',
          'CATEGORIES:FELIX-MYDAY-2026-07-05',
        ]),
        heute: DateTime(2026, 7, 5),
      )!;
      expect(aufgabe.meinTag, isTrue);
    });

    test('wichtig = hohe Priorität (1–4), nicht mittel/niedrig', () {
      final hoch = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Hoch',
        'PRIORITY:1',
      ]))!;
      expect(hoch.wichtig, isTrue);

      final mittel = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Mittel',
        'PRIORITY:5',
      ]))!;
      expect(mittel.wichtig, isFalse);
    });

    test('MYDAY-Marker von gestern verfällt', () {
      final heute = DateTime(2026, 7, 5);
      final aufgabe = Aufgabe.ausICalendar(
        vtodoIcal([
          'SUMMARY:Gestern geplant',
          'CATEGORIES:FELIX-MYDAY-2026-07-04',
        ]),
        heute: heute,
      )!;
      expect(aufgabe.meinTag, isFalse);
      expect(aufgabe.favorit, isFalse);
    });

    test('X-APPLE-SORT-ORDER wird als sortOrder übernommen', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Sortiert',
        'X-APPLE-SORT-ORDER:42',
      ]))!;
      expect(aufgabe.sortOrder, 42);
    });

    test('X-APPLE-SORT-ORDER als Kommazahl (Radicale/MS To Do)', () {
      final aufgabe = Aufgabe.ausICalendar(vtodoIcal([
        'SUMMARY:Sortiert',
        'X-APPLE-SORT-ORDER:3072.0',
      ]))!;
      expect(aufgabe.sortOrder, 3072);
    });

    test('Roh-iCalendar bleibt unverändert erhalten', () {
      final ical = vtodoIcal([
        'SUMMARY:Original',
        'X-EIGENES-FELD:bleibt',
      ]);
      final aufgabe = Aufgabe.ausICalendar(ical)!;
      expect(aufgabe.rohIcal, ical);
      expect(aufgabe.rohIcal, contains('X-EIGENES-FELD:bleibt'));
    });

    test('liefert null ohne VTODO', () {
      final ical = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Test//DE',
        'END:VCALENDAR',
      ].join('\r\n');
      expect(Aufgabe.ausICalendar(ical), isNull);
    });
  });

  test('mydayMarker: neutral (ohne FELIX) und mit führenden Nullen', () {
    expect(Aufgabe.mydayMarker(DateTime(2026, 7, 5)), 'MYDAY-2026-07-05');
    expect(Aufgabe.mydayMarker(DateTime(2026, 11, 23)), 'MYDAY-2026-11-23');
  });
}
