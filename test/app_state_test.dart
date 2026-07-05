// Tests für die Aufgaben-Helfer im AppState (Schritte, Fortschritt).
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/state/app_state.dart';

Aufgabe aufgabe(
  String uid, {
  String? parentUid,
  bool erledigt = false,
  int? sortOrder,
}) =>
    Aufgabe(
      uid: uid,
      titel: uid,
      erledigt: erledigt,
      parentUid: parentUid,
      sortOrder: sortOrder,
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
}
