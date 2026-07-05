// Tests für das verlustfreie Patchen von VTODO-iCalendar.
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/services/vtodo_patch.dart';

/// Beispiel wie vom Server: mit X-Properties, CATEGORIES und RELATED-TO,
/// die beim Speichern auf keinen Fall verloren gehen dürfen.
final beispielIcal = [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//Radicale//Test//DE',
  'BEGIN:VTODO',
  'UID:patch-test-uid',
  'DTSTAMP:20260705T120000Z',
  'SUMMARY:Original-Titel',
  'STATUS:NEEDS-ACTION',
  'SEQUENCE:4',
  'PRIORITY:5',
  'X-APPLE-SORT-ORDER:3072.0',
  'CATEGORIES:FAVORITE,MYDAY-2026-07-05',
  'RELATED-TO;RELTYPE=PARENT:eltern-uid',
  'X-FREMDES-FELD:unbekannt aber wichtig',
  'END:VTODO',
  'END:VCALENDAR',
  '',
].join('\r\n');

void main() {
  group('patcheVTodo', () {
    test('erhöht SEQUENCE und setzt LAST-MODIFIED', () {
      final jetzt = DateTime.utc(2026, 7, 5, 14, 30);
      final ergebnis = patcheVTodo(beispielIcal, (_) {}, jetzt: jetzt);
      expect(ergebnis, contains('SEQUENCE:5'));
      expect(ergebnis, contains('LAST-MODIFIED:20260705T143000Z'));
    });

    test('fehlende SEQUENCE wird zu 1', () {
      final ohneSequence = beispielIcal.replaceAll('SEQUENCE:4\r\n', '');
      final ergebnis = patcheVTodo(ohneSequence, (_) {});
      expect(ergebnis, contains('SEQUENCE:1'));
    });

    test('unbekannte Properties und Marker bleiben erhalten', () {
      final ergebnis =
          patcheVTodo(beispielIcal, (vtodo) => vtodo.summary = 'Neu');
      expect(ergebnis, contains('X-APPLE-SORT-ORDER:3072.0'));
      expect(ergebnis, contains('X-FREMDES-FELD:unbekannt aber wichtig'));
      expect(ergebnis, contains('FAVORITE'));
      expect(ergebnis, contains('MYDAY-2026-07-05'));
      expect(ergebnis, contains('RELTYPE=PARENT'));
      expect(ergebnis, contains('eltern-uid'));
    });
  });

  group('Patches', () {
    test('erledigtPatch: COMPLETED, 100 Prozent, Zeitstempel', () {
      final ergebnis = erledigtPatch(true,
          jetzt: DateTime.utc(2026, 7, 5, 15))(beispielIcal);
      expect(ergebnis, contains('STATUS:COMPLETED'));
      expect(ergebnis, contains('PERCENT-COMPLETE:100'));
      expect(ergebnis, contains('COMPLETED:20260705T150000Z'));

      // Rundreise durchs eigene Model: bleibt konsistent lesbar.
      final aufgabe = Aufgabe.ausICalendar(ergebnis,
          heute: DateTime(2026, 7, 5))!;
      expect(aufgabe.erledigt, isTrue);
      expect(aufgabe.prozent, 100);
      expect(aufgabe.sequence, 5);
      expect(aufgabe.favorit, isTrue);
      expect(aufgabe.meinTag, isTrue);
      expect(aufgabe.parentUid, 'eltern-uid');
      expect(aufgabe.sortOrder, 3072);
    });

    test('erledigtPatch(false): wieder öffnen räumt auf', () {
      final erledigt = erledigtPatch(true)(beispielIcal);
      final wiederOffen = erledigtPatch(false)(erledigt);
      expect(wiederOffen, contains('STATUS:NEEDS-ACTION'));
      expect(wiederOffen, isNot(contains('PERCENT-COMPLETE')));
      expect(wiederOffen, isNot(contains('COMPLETED:')));
    });

    test('titelPatch escapt Sonderzeichen vollständig', () {
      final ergebnis =
          titelPatch(r'A; B, C\D')(beispielIcal);
      expect(ergebnis, contains(r'SUMMARY:A\; B\, C\\D'));
      expect(Aufgabe.ausICalendar(ergebnis)!.titel, r'A; B, C\D');
    });

    test('titelPatch ändert nur den Titel', () {
      final ergebnis = titelPatch('Neuer Titel')(beispielIcal);
      final aufgabe = Aufgabe.ausICalendar(ergebnis)!;
      expect(aufgabe.titel, 'Neuer Titel');
      expect(aufgabe.prioritaet, 5);
      expect(ergebnis, isNot(contains('Original-Titel')));
    });

    test('notizPatch setzt und entfernt die Beschreibung', () {
      final mitNotiz = notizPatch('Meine Notiz')(beispielIcal);
      expect(Aufgabe.ausICalendar(mitNotiz)!.notiz, 'Meine Notiz');

      final ohneNotiz = notizPatch('')(mitNotiz);
      expect(ohneNotiz, isNot(contains('DESCRIPTION')));
    });

    test('prioritaetPatch: 0 entfernt die Property', () {
      final hoch = prioritaetPatch(1)(beispielIcal);
      expect(Aufgabe.ausICalendar(hoch)!.prioritaet, 1);

      final keine = prioritaetPatch(0)(hoch);
      expect(keine, isNot(contains('PRIORITY')));
    });

    test('faelligPatch setzt und entfernt DUE', () {
      final mitDatum =
          faelligPatch(DateTime.utc(2026, 8, 1, 12))(beispielIcal);
      expect(Aufgabe.ausICalendar(mitDatum)!.faellig, isNotNull);

      final ohneDatum = faelligPatch(null)(mitDatum);
      expect(ohneDatum, isNot(contains('DUE')));
    });
  });

  group('Marker-Patches (Favorit, Mein Tag)', () {
    test('favoritPatch entfernt nur FAVORITE, andere Kategorien bleiben', () {
      final ohneFavorit = favoritPatch(false)(beispielIcal);
      final aufgabe = Aufgabe.ausICalendar(ohneFavorit,
          heute: DateTime(2026, 7, 5))!;
      expect(aufgabe.favorit, isFalse);
      // Der MYDAY-Marker bleibt unangetastet.
      expect(aufgabe.meinTag, isTrue);
    });

    test('favoritPatch setzt FAVORITE auch ohne vorhandene CATEGORIES', () {
      final ohneKategorien =
          beispielIcal.replaceAll('CATEGORIES:FAVORITE,MYDAY-2026-07-05\r\n', '');
      final mitFavorit = favoritPatch(true)(ohneKategorien);
      expect(Aufgabe.ausICalendar(mitFavorit)!.favorit, isTrue);
    });

    test('meinTagPatch erneuert den Marker mit heutigem Datum', () {
      final heute = DateTime(2026, 7, 6); // Beispiel trägt den 05.
      final ergebnis = meinTagPatch(true, heute: heute)(beispielIcal);
      expect(ergebnis, contains('MYDAY-2026-07-06'));
      // Der alte Marker ist weg – es gibt genau einen.
      expect(ergebnis, isNot(contains('MYDAY-2026-07-05')));
      final aufgabe = Aufgabe.ausICalendar(ergebnis, heute: heute)!;
      expect(aufgabe.meinTag, isTrue);
      expect(aufgabe.favorit, isTrue);
    });

    test('meinTagPatch(false) entfernt alle MYDAY-Marker', () {
      final ergebnis = meinTagPatch(false)(beispielIcal);
      expect(ergebnis, isNot(contains('MYDAY-')));
      expect(ergebnis, contains('FAVORITE'));
    });
  });

  group('neuesVTodoIcal', () {
    test('enthält Pflichtfelder und lässt sich parsen', () {
      final ical = neuesVTodoIcal(
        uid: 'neu-1',
        titel: 'Einkaufen; Obst, Gemüse',
        jetzt: DateTime.utc(2026, 7, 5, 16),
      );
      expect(ical, contains('UID:neu-1'));
      expect(ical, contains('DTSTAMP:20260705T160000Z'));
      expect(ical, contains('SEQUENCE:0'));
      // Sonderzeichen sind escaped
      expect(ical, contains('SUMMARY:Einkaufen\\; Obst\\, Gemüse'));

      final aufgabe = Aufgabe.ausICalendar(ical)!;
      expect(aufgabe.titel, 'Einkaufen; Obst, Gemüse');
      expect(aufgabe.erledigt, isFalse);
      expect(aufgabe.istSchritt, isFalse);
    });

    test('mit parentUid entsteht ein Schritt (RELTYPE=PARENT)', () {
      final ical = neuesVTodoIcal(
        uid: 'neu-2',
        titel: 'Schritt',
        parentUid: 'eltern-uid',
      );
      expect(ical, contains('RELATED-TO;RELTYPE=PARENT:eltern-uid'));
      expect(Aufgabe.ausICalendar(ical)!.parentUid, 'eltern-uid');
    });

    test('neueUid ist eindeutig genug', () {
      final uids = {for (var i = 0; i < 100; i++) neueUid()};
      expect(uids.length, 100);
      expect(uids.first, endsWith('@tickdone'));
    });
  });
}
