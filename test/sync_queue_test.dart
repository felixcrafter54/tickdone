// Tests für die Offline-Sync-Queue (Zusammenfassen von Änderungen je Aufgabe,
// JSON-Round-Trip und Persistenz über LokalerSpeicher).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tickdone/services/lokaler_speicher.dart';
import 'package:tickdone/services/sync_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncQueue Zusammenfassen', () {
    test('mehrere Änderungen an derselben Aufgabe = eine Änderung', () {
      final q = SyncQueue();
      q.merkePut(uid: 'u1', href: 'h1', ical: 'ICAL-1', ifMatch: 'e1');
      q.merkePut(uid: 'u1', href: 'h1', ical: 'ICAL-2', ifMatch: 'e1');
      expect(q.anzahl, 1);
      // Neuestes iCal gewinnt, der zuerst bekannte ETag bleibt erhalten.
      expect(q.ausstehend.single.ical, 'ICAL-2');
      expect(q.ausstehend.single.ifMatch, 'e1');
    });

    test('Neuanlage bleibt Neuanlage (ohne ifMatch) trotz Folge-Änderung', () {
      final q = SyncQueue();
      q.merkePut(uid: 'neu', href: 'h', ical: 'A', neu: true);
      q.merkePut(uid: 'neu', href: 'h', ical: 'B', ifMatch: 'sollte-egal');
      expect(q.anzahl, 1);
      final a = q.ausstehend.single;
      expect(a.neu, isTrue);
      expect(a.ical, 'B');
      expect(a.ifMatch, isNull);
    });

    test('Löschen einer nur lokal neuen Aufgabe verwirft die Neuanlage', () {
      final q = SyncQueue();
      q.merkePut(uid: 'neu', href: 'h', ical: 'A', neu: true);
      q.merkeLoeschen(uid: 'neu', href: 'h');
      expect(q.istLeer, isTrue);
    });

    test('Löschen nach Änderung ersetzt durch Löschen (ETag bleibt)', () {
      final q = SyncQueue();
      q.merkePut(uid: 'u1', href: 'h', ical: 'A', ifMatch: 'e1');
      q.merkeLoeschen(uid: 'u1', href: 'h');
      expect(q.anzahl, 1);
      final a = q.ausstehend.single;
      expect(a.art, AenderungsArt.loeschen);
      expect(a.ifMatch, 'e1');
      expect(a.ical, isNull);
    });

    test('verschiedene Aufgaben bleiben getrennt; entferne wirkt gezielt', () {
      final q = SyncQueue();
      q.merkePut(uid: 'a', href: 'ha', ical: 'A');
      q.merkePut(uid: 'b', href: 'hb', ical: 'B');
      expect(q.anzahl, 2);
      q.entferne('a');
      expect(q.ausstehend.single.uid, 'b');
    });
  });

  group('SyncQueue JSON', () {
    test('Round-Trip erhält alle Felder', () {
      final q = SyncQueue();
      q.merkePut(uid: 'u1', href: 'h1', ical: 'ICAL', ifMatch: 'e1');
      q.merkeLoeschen(uid: 'u2', href: 'h2', ifMatch: 'e2');

      final wieder = SyncQueue.ausJson(q.zuJson());
      expect(wieder.anzahl, 2);
      final put = wieder.ausstehend.firstWhere((a) => a.uid == 'u1');
      expect(put.art, AenderungsArt.put);
      expect(put.ical, 'ICAL');
      expect(put.ifMatch, 'e1');
      final del = wieder.ausstehend.firstWhere((a) => a.uid == 'u2');
      expect(del.art, AenderungsArt.loeschen);
      expect(del.ifMatch, 'e2');
    });
  });

  group('LokalerSpeicher Queue-Persistenz', () {
    test('speichern und laden erhält die Queue', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());

      final q = SyncQueue();
      q.merkePut(uid: 'u1', href: 'h1', ical: 'ICAL', ifMatch: 'e1');
      await speicher.speichereQueue(q);

      final geladen = await speicher.ladeQueue();
      expect(geladen.anzahl, 1);
      expect(geladen.ausstehend.single.ical, 'ICAL');
    });

    test('ladeQueue ohne Daten liefert leere Queue', () async {
      SharedPreferences.setMockInitialValues({});
      final speicher = LokalerSpeicher(SharedPreferences.getInstance());
      expect((await speicher.ladeQueue()).istLeer, isTrue);
    });
  });
}
