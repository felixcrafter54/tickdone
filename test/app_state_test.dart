// Tests für die Aufgaben-Helfer im AppState (Schritte, Fortschritt).
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/state/app_state.dart';

Aufgabe aufgabe(
  String uid, {
  String? parentUid,
  bool erledigt = false,
  int? sortOrder,
  bool favorit = false,
  DateTime? faellig,
  int prioritaet = 0,
  DateTime? erstellt,
}) =>
    Aufgabe(
      uid: uid,
      titel: uid,
      erledigt: erledigt,
      parentUid: parentUid,
      sortOrder: sortOrder,
      favorit: favorit,
      faellig: faellig,
      prioritaet: prioritaet,
      erstellt: erstellt,
      rohIcal: '',
    );

void main() {
  group('AppState-Aufgabenhelfer', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.aufgaben = [
        aufgabe('haupt-1'),
        aufgabe('haupt-2'),
        aufgabe('s1', parentUid: 'haupt-1', erledigt: true, sortOrder: 2048),
        aufgabe('s2', parentUid: 'haupt-1', sortOrder: 1024),
        aufgabe('s3', parentUid: 'haupt-1'),
      ];
    });

    test('wurzelAufgaben enthält keine Schritte', () {
      expect(state.wurzelAufgaben.map((a) => a.uid), ['haupt-1', 'haupt-2']);
    });

    test('schritteVon sortiert nach sortOrder, ohne Wert ans Ende', () {
      expect(
        state.schritteVon('haupt-1').map((a) => a.uid),
        ['s2', 's1', 's3'],
      );
    });

    test('fortschrittVon zählt erledigte und gesamte Schritte', () {
      final fortschritt = state.fortschrittVon('haupt-1')!;
      expect(fortschritt.erledigt, 1);
      expect(fortschritt.gesamt, 3);
    });

    test('fortschrittVon ist null ohne Schritte', () {
      expect(state.fortschrittVon('haupt-2'), isNull);
    });

    test('aufgabeMitUid findet Aufgabe oder liefert null', () {
      expect(state.aufgabeMitUid('haupt-1')?.uid, 'haupt-1');
      expect(state.aufgabeMitUid('gibt-es-nicht'), isNull);
    });
  });

  group('Filtern und Sortieren', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.aufgaben = [
        aufgabe('b-offen',
            sortOrder: 2048,
            faellig: DateTime(2026, 8, 1),
            prioritaet: 5,
            erstellt: DateTime(2026, 7, 1)),
        aufgabe('a-erledigt',
            erledigt: true,
            sortOrder: 1024,
            prioritaet: 1,
            erstellt: DateTime(2026, 7, 3)),
        aufgabe('c-favorit',
            favorit: true,
            faellig: DateTime(2026, 7, 10),
            erstellt: DateTime(2026, 7, 2)),
      ];
    });

    test('Filter offen/erledigt/Favoriten', () {
      state.filter = AufgabenFilter.offen;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          isNot(contains('a-erledigt')));

      state.filter = AufgabenFilter.erledigt;
      expect(state.wurzelAufgaben.map((a) => a.uid), ['a-erledigt']);

      state.filter = AufgabenFilter.favoriten;
      expect(state.wurzelAufgaben.map((a) => a.uid), ['c-favorit']);
    });

    test('Sortierung manuell: sortOrder, ohne Wert ans Ende', () {
      state.sortierung = Sortierung.manuell;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          ['a-erledigt', 'b-offen', 'c-favorit']);
    });

    test('Sortierung Fälligkeit aufsteigend, ohne Wert ans Ende', () {
      state.sortierung = Sortierung.faelligkeit;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          ['c-favorit', 'b-offen', 'a-erledigt']);
    });

    test('Sortierung Priorität: hoch zuerst, keine ans Ende', () {
      state.sortierung = Sortierung.prioritaet;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          ['a-erledigt', 'b-offen', 'c-favorit']);
    });

    test('Sortierung Titel alphabetisch', () {
      state.sortierung = Sortierung.titel;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          ['a-erledigt', 'b-offen', 'c-favorit']);
    });

    test('Sortierung Erstellt: neueste zuerst', () {
      state.sortierung = Sortierung.erstellt;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          ['a-erledigt', 'c-favorit', 'b-offen']);
    });
  });
}
