// Tests für den Offline-Schreibpfad im AppState: Änderungen wandern bei
// Verbindungsproblemen in die Queue und werden online abgearbeitet.
import 'package:caldav/caldav.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/services/caldav_service.dart';
import 'package:tickdone/services/lokaler_speicher.dart';
import 'package:tickdone/services/sync_queue.dart';
import 'package:tickdone/services/vtodo_patch.dart';
import 'package:tickdone/state/app_state.dart';

/// Fake-CalDavService: kann Verbindungsprobleme simulieren und zählt die
/// Schreib-/Löschaufrufe der Queue-Abarbeitung.
class FakeCalDav extends CalDavService {
  final bool online;
  final bool wirftNetzwerkfehler;
  int puts = 0;
  int deletes = 0;

  FakeCalDav({this.online = false, this.wirftNetzwerkfehler = true});

  @override
  bool get istVerbunden => online;

  DioException get _netz =>
      DioException(requestOptions: RequestOptions(path: ''));

  @override
  Future<Aufgabe> speichereAenderung(Aufgabe aufgabe, IcalPatch patch) async {
    if (wirftNetzwerkfehler) throw _netz;
    return Aufgabe.ausICalendar(patch(aufgabe.rohIcal),
        etag: 'neu', href: aufgabe.href)!;
  }

  @override
  Future<String?> legeAnMitIcal(
      {required Uri href, required String ical}) async {
    if (wirftNetzwerkfehler) throw _netz;
    return 'neu';
  }

  @override
  Future<Aufgabe> schreibeRoh(Uri href, String ical,
      {String? ifMatch, bool ifNoneMatch = false}) async {
    puts++;
    return Aufgabe.ausICalendar(ical, etag: 'srv', href: href)!;
  }

  @override
  Future<void> loescheHref(Uri href, String? ifMatch) async {
    deletes++;
  }
}

Aufgabe serverAufgabe(String uid) => Aufgabe.ausICalendar(
      neuesVTodoIcal(uid: uid, titel: uid),
      etag: 'e-$uid',
      href: Uri.parse('https://server/liste/$uid.ics'),
    )!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LokalerSpeicher neuerCache() {
    SharedPreferences.setMockInitialValues({});
    return LokalerSpeicher(SharedPreferences.getInstance());
  }

  group('Offline vormerken', () {
    test('Änderung bei Verbindungsproblem landet in der Queue', () async {
      final cache = neuerCache();
      final state = AppState(null, null, cache, FakeCalDav());
      state.aufgaben = [serverAufgabe('u1')];

      await state.setzeErledigt('u1', true);

      expect(state.ausstehendeAnzahl, 1);
      // Optimistisch trotzdem lokal erledigt.
      expect(state.aufgabeMitUid('u1')!.erledigt, isTrue);
      // Und persistiert.
      expect((await cache.ladeQueue()).anzahl, 1);
    });

    test('mehrere Änderungen an derselben Aufgabe bleiben EINE', () async {
      final cache = neuerCache();
      final state = AppState(null, null, cache, FakeCalDav());
      state.aufgaben = [serverAufgabe('u1')];

      await state.setzeErledigt('u1', true);
      await state.setzeTitel('u1', 'Neuer Titel');

      expect(state.ausstehendeAnzahl, 1);
    });

    test('Neuanlage offline bleibt lokal und wird vorgemerkt', () async {
      final cache = neuerCache();
      final state = AppState(null, null, cache, FakeCalDav());
      state.aktiveListe = Calendar(
        uid: 'l1',
        href: Uri.parse('https://server/liste/'),
        displayName: 'L1',
        supportedComponents: const ['VTODO'],
      );

      final ok = await state.erstelleAufgabe('Offline-Aufgabe');

      expect(ok, isTrue);
      expect(state.wurzelAufgaben.any((a) => a.titel == 'Offline-Aufgabe'),
          isTrue);
      expect(state.ausstehendeAnzahl, 1);
    });
  });

  group('Online-Synchronisierung', () {
    test('arbeitet Queue ab (put + delete) und leert sie', () async {
      final cache = neuerCache();
      final vorbereitet = SyncQueue();
      vorbereitet.merkePut(
        uid: 'u1',
        href: 'https://server/liste/u1.ics',
        ical: neuesVTodoIcal(uid: 'u1', titel: 'A'),
        ifMatch: 'e1',
      );
      vorbereitet.merkeLoeschen(
        uid: 'u2',
        href: 'https://server/liste/u2.ics',
        ifMatch: 'e2',
      );
      await cache.speichereQueue(vorbereitet);

      final fake = FakeCalDav(online: true);
      final state = AppState(null, null, cache, fake);
      await state.ladeCache();
      expect(state.ausstehendeAnzahl, 2);

      await state.synchronisiereJetzt();

      expect(state.ausstehendeAnzahl, 0);
      expect(fake.puts, 1);
      expect(fake.deletes, 1);
      expect((await cache.ladeQueue()).istLeer, isTrue);
    });

    test('offline (nicht verbunden) tut nichts', () async {
      final cache = neuerCache();
      final vorbereitet = SyncQueue();
      vorbereitet.merkePut(
        uid: 'u1',
        href: 'https://server/liste/u1.ics',
        ical: neuesVTodoIcal(uid: 'u1', titel: 'A'),
        ifMatch: 'e1',
      );
      await cache.speichereQueue(vorbereitet);

      final fake = FakeCalDav(online: false);
      final state = AppState(null, null, cache, fake);
      await state.ladeCache();

      await state.synchronisiereJetzt();

      expect(state.ausstehendeAnzahl, 1);
      expect(fake.puts, 0);
    });
  });
}
