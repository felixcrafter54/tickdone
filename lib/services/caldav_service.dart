import 'dart:convert';

import 'package:caldav/caldav.dart';
import 'package:dio/dio.dart';

import '../models/aufgabe.dart';
import 'vtodo_patch.dart';

/// Kapselt die CalDAV-Verbindung zum Server.
///
/// Der Nutzer gibt meist nur die Domain ein. Das Paket `caldav` übernimmt die
/// eigentliche Discovery (.well-known/caldav, Principal, Calendar-Home).
/// Zusätzlich probieren wir gängige Pfad-Kandidaten durch (siehe Spec,
/// Abschnitt 2), falls der Server kein .well-known anbietet.
class CalDavService {
  CalDavClient? _client;
  String? _verbundeneUrl;

  bool get istVerbunden => _client != null;

  /// Die URL, mit der die Verbindung geklappt hat
  /// (wird später gecacht, um Discovery-Requests zu sparen).
  String? get verbundeneUrl => _verbundeneUrl;

  CalDavClient get client {
    final c = _client;
    if (c == null) {
      throw StateError('Nicht verbunden – zuerst verbinden() aufrufen.');
    }
    return c;
  }

  /// Baut die Verbindung auf und prüft die Zugangsdaten.
  ///
  /// Probiert nacheinander: eingegebene URL → Ziel von
  /// `<basis>/.well-known/caldav` → `<basis>/caldav/` → `<basis>/radicale/`
  /// (Reihenfolge aus der Spec, Abschnitt 2). Bei falschen Zugangsdaten
  /// (401) wird sofort abgebrochen, weitere Pfade bringen dann nichts.
  ///
  /// WICHTIG: Abschließende Slashes werden bei Kandidaten NICHT entfernt –
  /// manche Server beantworten PROPFIND auf /caldav mit 405,
  /// auf /caldav/ aber korrekt.
  ///
  /// Das .well-known-Ziel muss VOR connect() selbst aufgelöst werden:
  /// connect() prüft die Zugangsdaten per PROPFIND auf der Basis-URL und
  /// scheitert bei Servern wie Nextcloud (CalDAV unter /remote.php/dav),
  /// bevor die paket-interne Discovery .well-known überhaupt probiert.
  Future<void> verbinden({
    required String serverUrl,
    required String benutzer,
    required String passwort,
  }) async {
    trennen();
    // Eingegebene URL nur um das Schema ergänzen, sonst unangetastet lassen
    // (ein evtl. vorhandener End-Slash bleibt bewusst erhalten).
    final eingegeben = _ergaenzeSchema(serverUrl.trim());
    final basis = _ohneEndSlash(eingegeben);
    // Protokoll aller Versuche – landet bei Misserfolg in der Fehlermeldung,
    // damit man sieht, welcher Kandidat woran gescheitert ist.
    final diagnose = <String>[];

    final kandidaten = <String>[eingegeben];
    final wellKnownZiel =
        await _loeseWellKnownAuf(basis, benutzer, passwort, diagnose);
    if (wellKnownZiel != null && !kandidaten.contains(wellKnownZiel)) {
      kandidaten.add(wellKnownZiel);
    }
    for (final pfad in ['$basis/caldav/', '$basis/radicale/']) {
      if (!kandidaten.contains(pfad)) {
        kandidaten.add(pfad);
      }
    }

    for (final url in kandidaten) {
      try {
        _client = await CalDavClient.connect(
          baseUrl: url,
          username: benutzer,
          password: passwort,
          // HTTP nur für lokale Test-Server zulassen (z.B. Radicale im LAN).
          allowInsecure: url.startsWith('http://'),
        );
        _verbundeneUrl = url;
        return;
      } on CalDavException catch (fehler) {
        if (fehler.statusCode == 401) {
          throw Exception('Anmeldung fehlgeschlagen: '
              'Benutzername oder Passwort ist falsch.');
        }
        diagnose.add('$url → $fehler');
      } on DioException catch (fehler) {
        final status = fehler.response?.statusCode;
        diagnose.add(
            '$url → ${status != null ? 'HTTP $status' : fehler.type.name}');
      } catch (fehler) {
        diagnose.add('$url → $fehler');
      }
    }
    throw Exception('Keine CalDAV-Verbindung zu "$basis" möglich.\n'
        'Versuchte Wege:\n${diagnose.map((z) => '  $z').join('\n')}');
  }

  /// Lädt alle Collections des Nutzers und filtert auf solche,
  /// die Aufgaben (VTODO) unterstützen.
  Future<List<Calendar>> ladeAufgabenlisten() async {
    final alle = await client.getCalendars();
    final mitVtodo = alle.where((liste) => liste.supportsTodos).toList();
    // Manche Server melden kein supported-calendar-component-set.
    // Dann lieber alle Collections anzeigen statt gar keine.
    return mitVtodo.isEmpty ? alle : mitVtodo;
  }

  /// Lädt alle Aufgaben einer Liste – in EINEM REPORT.
  ///
  /// getTodos() schickt genau den calendar-query aus der Spec
  /// (comp-filter VTODO, calendar-data + getetag, KEIN STATUS-Filter)
  /// und liefert das unveränderte iCalendar je Aufgabe mit. Daraus
  /// parsen wir unser eigenes Model.
  Future<List<Aufgabe>> ladeAufgaben(Calendar liste) async {
    final todos = await client.getTodos(liste);
    final aufgaben = <Aufgabe>[];
    for (final todo in todos) {
      final roh = todo.rawIcalendar;
      if (roh == null || roh.isEmpty) continue;
      final aufgabe = Aufgabe.ausICalendar(roh, etag: todo.etag, href: todo.href);
      if (aufgabe != null) {
        aufgaben.add(aufgabe);
      }
    }
    return aufgaben;
  }

  /// Neue Aufgabenliste anlegen – MKCALENDAR mit
  /// supported-calendar-component-set VTODO (Spec, Abschnitt 2).
  Future<void> erstelleListe(String name) async {
    await client.createCalendar(name, supportedComponents: const ['VTODO']);
  }

  /// Liste samt Inhalt löschen (DELETE auf die Collection).
  Future<void> loescheListe(Calendar liste) async {
    await client.deleteCalendar(liste);
  }

  /// Aufgabe in eine andere Liste verschieben: unverändertes iCalendar
  /// in die Ziel-Collection legen (If-None-Match: *), dann das Original
  /// löschen. Erst nach erfolgreichem Anlegen wird gelöscht –
  /// so geht bei einem Fehler nichts verloren.
  Future<void> verschiebeAufgabe(Aufgabe aufgabe, Calendar ziel) async {
    final dateiname = aufgabe.href?.pathSegments.lastOrNull ??
        '${aufgabe.uid}.ics';
    final zielHref = ziel.href.resolve(dateiname);
    await client.webdavClient.put(
      zielHref.toString(),
      body: aufgabe.rohIcal,
      ifNoneMatch: '*',
    );
    await loescheAufgabe(aufgabe);
  }

  /// Einzelne Aufgabe löschen (DELETE mit If-Match).
  /// 404 gilt als Erfolg – dann war sie schon weg.
  Future<void> loescheAufgabe(Aufgabe aufgabe) async {
    final href = aufgabe.href;
    if (href == null) return;
    try {
      await client.webdavClient
          .delete(href.toString(), ifMatch: aufgabe.etag);
    } on DioException catch (fehler) {
      if (fehler.response?.statusCode == 404) return;
      rethrow;
    }
  }

  /// Speichert eine Änderung an einer Aufgabe verlustfrei.
  ///
  /// Ablauf nach Spec, Abschnitt 2: Roh-iCalendar patchen (SEQUENCE +1,
  /// LAST-MODIFIED), PUT mit ETag als If-Match. Bei 412 (jemand anders hat
  /// zwischenzeitlich gespeichert): Objekt frisch holen, [patch] erneut
  /// anwenden, nochmal speichern.
  Future<Aufgabe> speichereAenderung(Aufgabe aufgabe, IcalPatch patch) async {
    final href = aufgabe.href;
    if (href == null) {
      throw StateError('Aufgabe ohne href kann nicht gespeichert werden.');
    }
    try {
      return await _putAufgabe(href, patch(aufgabe.rohIcal), aufgabe.etag);
    } on DioException catch (fehler) {
      if (fehler.response?.statusCode != 412) rethrow;
      final frisch = await _holeAufgabe(href);
      return _putAufgabe(href, patch(frisch.ical), frisch.etag);
    }
  }

  /// Legt eine neue Aufgabe (oder mit [parentUid] einen Schritt) an.
  ///
  /// If-None-Match: * verhindert, dass eine bestehende Ressource
  /// überschrieben wird.
  Future<void> erstelleAufgabe(
    Calendar liste, {
    required String titel,
    String? parentUid,
  }) async {
    final uid = neueUid();
    final ical = neuesVTodoIcal(uid: uid, titel: titel, parentUid: parentUid);
    final href = liste.href.resolve('$uid.ics');
    await client.webdavClient.put(
      href.toString(),
      body: ical,
      ifNoneMatch: '*',
    );
  }

  /// PUT einer Aufgabe; liefert das Model zum neuen Serverstand.
  Future<Aufgabe> _putAufgabe(Uri href, String ical, String? etag) async {
    final antwort = await client.webdavClient.put(
      href.toString(),
      body: ical,
      ifMatch: etag,
    );
    final neuerEtag = antwort.headers.value('etag');
    if (neuerEtag == null) {
      // Server liefert beim PUT keinen ETag – Stand frisch holen.
      final frisch = await _holeAufgabe(href);
      final aufgabe =
          Aufgabe.ausICalendar(frisch.ical, etag: frisch.etag, href: href);
      if (aufgabe != null) return aufgabe;
    }
    return Aufgabe.ausICalendar(ical, etag: neuerEtag, href: href)!;
  }

  /// Holt das aktuelle iCalendar + ETag einer einzelnen Aufgabe.
  Future<({String ical, String? etag})> _holeAufgabe(Uri href) async {
    final antwort = await client.webdavClient.get(href.toString());
    return (
      ical: antwort.data ?? '',
      etag: antwort.headers.value('etag'),
    );
  }

  /// Verbindung schließen und Zustand zurücksetzen.
  void trennen() {
    _client?.close();
    _client = null;
    _verbundeneUrl = null;
  }

  /// Löst `<basis>/.well-known/caldav` auf (RFC 6764) und liefert das
  /// Ziel als zusätzlichen Verbindungs-Kandidaten – oder null, wenn der
  /// Server kein .well-known anbietet.
  ///
  /// Mit Zugangsdaten, weil manche Server (z.B. hinter einem Auth-Proxy)
  /// schon auf .well-known ein 401 schicken statt direkt umzuleiten.
  /// Erlaubt der Server kein GET (405), wird PROPFIND probiert.
  Future<String?> _loeseWellKnownAuf(String basis, String benutzer,
      String passwort, List<String> diagnose) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      followRedirects: false,
      // Nichts als Fehler werten – wir wollen den Status selbst auswerten.
      validateStatus: (status) => status != null,
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$benutzer:$passwort'))}',
      },
    ));
    final wellKnownUrl = '$basis/.well-known/caldav';
    const redirects = {301, 302, 307, 308};
    try {
      var antwort = await dio.get<void>(wellKnownUrl);
      var status = antwort.statusCode ?? 0;

      // Manche Server erlauben auf .well-known kein GET,
      // leiten aber bei PROPFIND um.
      if (status == 405) {
        antwort = await dio.request<void>(
          wellKnownUrl,
          options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
        );
        status = antwort.statusCode ?? 0;
      }

      if (redirects.contains(status)) {
        final ziel = antwort.headers.value('location');
        if (ziel != null && ziel.isNotEmpty) {
          // Ziel unverändert übernehmen – insbesondere den End-Slash
          // NICHT abschneiden (sonst z.B. 405 statt 207).
          final aufgeloest = Uri.parse('$basis/').resolve(ziel).toString();
          diagnose.add('.well-known/caldav → HTTP $status nach $aufgeloest');
          return aufgeloest;
        }
        diagnose.add('.well-known/caldav → HTTP $status ohne Location');
        return null;
      }
      // 2xx ohne Redirect: .well-known ist selbst der Endpunkt.
      if (status >= 200 && status < 300) {
        diagnose.add('.well-known/caldav → HTTP $status (direkter Endpunkt)');
        return wellKnownUrl;
      }
      diagnose.add('.well-known/caldav → HTTP $status (kein Redirect)');
    } catch (fehler) {
      diagnose.add('.well-known/caldav → $fehler');
    } finally {
      dio.close();
    }
    return null;
  }

  /// Ergänzt fehlendes Schema (https), lässt die URL sonst unangetastet.
  String _ergaenzeSchema(String eingabe) {
    if (!eingabe.startsWith('http://') && !eingabe.startsWith('https://')) {
      return 'https://$eingabe';
    }
    return eingabe;
  }

  /// Entfernt abschließende Slashes – nur für die Basis, an die
  /// Pfad-Kandidaten angehängt werden.
  String _ohneEndSlash(String url) {
    var ergebnis = url;
    while (ergebnis.endsWith('/')) {
      ergebnis = ergebnis.substring(0, ergebnis.length - 1);
    }
    return ergebnis;
  }
}
