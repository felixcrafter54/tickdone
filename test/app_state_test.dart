// Tests für die Aufgaben-Helfer im AppState (Schritte, Fortschritt).
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/services/einstellungen_speicher.dart';
import 'package:tickdone/state/app_state.dart';

Aufgabe aufgabe(
  String uid, {
  String? parentUid,
  bool erledigt = false,
  int? sortOrder,
  bool favorit = false,
  bool meinTag = false,
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
      meinTag: meinTag,
      faellig: faellig,
      prioritaet: prioritaet,
      erstellt: erstellt,
      rohIcal: '',
    );

void main() {
  group('Smart-Listen-Filter', () {
    late AppState state;

    setUp(() {
      state = AppState();
      state.aufgaben = [
        aufgabe('mein-tag', meinTag: true),
        aufgabe('wichtig', favorit: true),
        // Fälligkeit klar in der Zukunft (nie "heute"), damit sie nicht
        // automatisch in "Mein Tag" landet.
        aufgabe('geplant',
            faellig: DateTime.now().add(const Duration(days: 30))),
        aufgabe('nichts'),
        // Schritte tauchen in Smart-Listen nicht als Wurzel auf.
        aufgabe('schritt', parentUid: 'mein-tag', meinTag: true),
      ];
    });

    test('Mein Tag zeigt nur markierte Wurzel-Aufgaben', () {
      state.aktiveSmartliste = Smartliste.meinTag;
      expect(state.wurzelAufgaben.map((a) => a.uid), ['mein-tag']);
    });

    test('Mein Tag zeigt heute fällige Aufgaben automatisch', () {
      state.aufgaben = [
        aufgabe('heute', faellig: DateTime.now()),
        aufgabe('morgen',
            faellig: DateTime.now().add(const Duration(days: 1))),
        aufgabe('markiert', meinTag: true),
        aufgabe('nichts'),
      ];
      state.aktiveSmartliste = Smartliste.meinTag;
      expect(state.wurzelAufgaben.map((a) => a.uid).toSet(),
          {'heute', 'markiert'});
    });

    test('Geplant: überfälligste zuerst, ignoriert globale Sortierung', () {
      // Global auf Titel gestellt – "Geplant" muss das ignorieren.
      state.sortierung = Sortierung.titel;
      state.aufgaben = [
        aufgabe('z-frueh', faellig: DateTime(2026, 7, 1)),
        aufgabe('a-spaet', faellig: DateTime(2026, 9, 1)),
        aufgabe('m-mitte', faellig: DateTime(2026, 8, 1)),
      ];
      state.aktiveSmartliste = Smartliste.geplant;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          ['z-frueh', 'm-mitte', 'a-spaet']);
    });

    test('Wichtig zeigt nur wichtige', () {
      state.aktiveSmartliste = Smartliste.wichtig;
      expect(state.wurzelAufgaben.map((a) => a.uid), ['wichtig']);
    });

    test('Geplant zeigt nur mit Fälligkeit', () {
      state.aktiveSmartliste = Smartliste.geplant;
      expect(state.wurzelAufgaben.map((a) => a.uid), ['geplant']);
    });

    test('ohne Smart-Liste alle Wurzel-Aufgaben', () {
      state.aktiveSmartliste = null;
      expect(state.wurzelAufgaben.map((a) => a.uid).toSet(),
          {'mein-tag', 'wichtig', 'geplant', 'nichts'});
    });
  });

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

    test('schritteVon ohne sortOrder: stabil nach Erstell-Zeit', () {
      final s = AppState();
      // Absichtlich verkehrte Listenreihenfolge – soll nach CREATED sortiert
      // werden (früher erstellt = weiter oben), stabil nach Reload.
      s.aufgaben = [
        aufgabe('spaeter',
            parentUid: 'p', erstellt: DateTime(2026, 7, 5, 12)),
        aufgabe('frueher',
            parentUid: 'p', erstellt: DateTime(2026, 7, 5, 10)),
        aufgabe('mitte',
            parentUid: 'p', erstellt: DateTime(2026, 7, 5, 11)),
      ];
      expect(s.schritteVon('p').map((a) => a.uid),
          ['frueher', 'mitte', 'spaeter']);
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
      // Basissortierung testen (ohne "Wichtige oben").
      state.einstellungen = const Einstellungen(wichtigeOben: false);
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

    test('Filter offen/erledigt/wichtig', () {
      state.filter = AufgabenFilter.offen;
      expect(state.wurzelAufgaben.map((a) => a.uid),
          isNot(contains('a-erledigt')));

      state.filter = AufgabenFilter.erledigt;
      expect(state.wurzelAufgaben.map((a) => a.uid), ['a-erledigt']);

      // Wichtig = hohe Priorität ODER alter FAVORITE-Marker.
      state.filter = AufgabenFilter.wichtig;
      expect(state.wurzelAufgaben.map((a) => a.uid).toSet(),
          {'a-erledigt', 'c-favorit'});
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

    test('Sortierung Wichtig: wichtige zuerst', () {
      state.sortierung = Sortierung.wichtig;
      final uids = state.wurzelAufgaben.map((a) => a.uid).toList();
      // a-erledigt (PRIORITY 1) und c-favorit (FAVORITE) sind wichtig,
      // b-offen (PRIORITY 5) nicht.
      expect(uids.sublist(0, 2).toSet(), {'a-erledigt', 'c-favorit'});
      expect(uids.last, 'b-offen');
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

    test('Wichtige oben stellt wichtige Aufgaben voran', () {
      state.einstellungen = const Einstellungen(wichtigeOben: true);
      state.sortierung = Sortierung.titel;
      // a-erledigt (PRIORITY 1) und c-favorit sind wichtig -> zuerst.
      final uids = state.wurzelAufgaben.map((a) => a.uid).toList();
      expect(uids.sublist(0, 2).toSet(), {'a-erledigt', 'c-favorit'});
      expect(uids.last, 'b-offen');
    });
  });
}
