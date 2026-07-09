// Tests für den lokalen Cache (Schnappschuss speichern/laden) und den
// Cache-Sofortstart im AppState.
import 'package:caldav/caldav.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/services/lokaler_speicher.dart';
import 'package:tickdone/services/vtodo_patch.dart';
import 'package:tickdone/state/app_state.dart';

Calendar liste(String uid, {String? color}) => Calendar(
      uid: uid,
      href: Uri.parse('https://server/$uid/'),
      displayName: 'Liste $uid',
      supportedComponents: const ['VTODO'],
      color: color,
    );

Aufgabe ausIcal(String uid, String titel, {int? sortOrder, String? etag}) {
  final ical = neuesVTodoIcal(uid: uid, titel: titel, sortOrder: sortOrder);
  return Aufgabe.ausICalendar(ical,
      etag: etag, href: Uri.parse('https://server/l1/$uid.ics'))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LokalerSpeicher', () {
    test('Round-Trip erhält Listen und Aufgaben', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());

      await speicher.speichern(Schnappschuss(
        listen: [liste('l1', color: '#FF0000')],
        aufgabenProListe: {
          'l1': [ausIcal('u1', 'Test', sortOrder: 1024, etag: 'e1')],
        },
      ));

      final geladen = await speicher.laden();
      expect(geladen, isNotNull);
      expect(geladen!.listen.single.displayName, 'Liste l1');
      expect(geladen.listen.single.color, '#FF0000');
      final aufg = geladen.aufgabenProListe['l1']!.single;
      expect(aufg.titel, 'Test');
      expect(aufg.etag, 'e1');
      expect(aufg.sortOrder, 1024);
    });

    test('laden ohne Daten liefert null', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());
      expect(await speicher.laden(), isNull);
    });

    test('loeschen entfernt den Schnappschuss', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());
      await speicher.speichern(Schnappschuss(
        listen: [liste('l1')],
        aufgabenProListe: {'l1': [ausIcal('u1', 'Test')]},
      ));
      await speicher.loeschen();
      expect(await speicher.laden(), isNull);
    });

    test('Sortierungen je Ansicht: Round-Trip', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());
      await speicher.speichereSortierungen({
        'liste:l1': 'titel,absteigend',
        'smart:meinTag': 'faelligkeit,aufsteigend',
      });
      final geladen = await speicher.ladeSortierungen();
      expect(geladen['liste:l1'], 'titel,absteigend');
      expect(geladen['smart:meinTag'], 'faelligkeit,aufsteigend');
    });

    test('Sortierungen ohne Daten liefern leere Map', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());
      expect(await speicher.ladeSortierungen(), isEmpty);
    });
  });

  group('AppState.ladeCache', () {
    test('füllt Listen, öffnet erste Liste und zeigt Aufgaben', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = LokalerSpeicher(SharedPreferences.getInstance());
      await cache.speichern(Schnappschuss(
        listen: [liste('l1')],
        aufgabenProListe: {
          'l1': [ausIcal('u1', 'Aus Cache')],
        },
      ));

      final state = AppState(null, null, cache);
      await state.ladeCache();

      expect(state.aufgabenlisten.single.uid, 'l1');
      expect(state.aktiveListe?.uid, 'l1');
      expect(state.wurzelAufgaben.single.titel, 'Aus Cache');
      // Offen-Zähler ist aus dem Cache abgeleitet.
      expect(state.offeneAnzahl('l1'), 1);
    });

    test('ladeCache überschreibt vorhandene Serverdaten nicht', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = LokalerSpeicher(SharedPreferences.getInstance());
      await cache.speichern(Schnappschuss(
        listen: [liste('cache-liste')],
        aufgabenProListe: const {},
      ));

      final state = AppState(null, null, cache);
      // So, als wären schon Serverdaten geladen.
      state.aufgabenlisten = [liste('server-liste')];
      await state.ladeCache();

      expect(state.aufgabenlisten.single.uid, 'server-liste');
    });
  });
}
