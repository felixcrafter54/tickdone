import 'dart:convert';

import 'package:caldav/caldav.dart';
import 'package:dio/dio.dart';

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
  /// `<basis>/.well-known/caldav` → `<basis>/caldav` → `<basis>/radicale`
  /// (Reihenfolge aus der Spec, Abschnitt 2). Bei falschen Zugangsdaten
  /// (401) wird sofort abgebrochen, weitere Pfade bringen dann nichts.
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
    final basis = _normalisiereUrl(serverUrl);
    // Protokoll aller Versuche – landet bei Misserfolg in der Fehlermeldung,
    // damit man sieht, welcher Kandidat woran gescheitert ist.
    final diagnose = <String>[];

    final kandidaten = <String>[basis];
    final wellKnownZiel =
        await _loeseWellKnownAuf(basis, benutzer, passwort, diagnose);
    if (wellKnownZiel != null && !kandidaten.contains(wellKnownZiel)) {
      kandidaten.add(wellKnownZiel);
    }
    kandidaten.addAll(['$basis/caldav', '$basis/radicale']);

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
          final aufgeloest = Uri.parse('$basis/').resolve(ziel).toString();
          diagnose.add('.well-known/caldav → HTTP $status nach $aufgeloest');
          return _normalisiereUrl(aufgeloest);
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

  /// Ergänzt fehlendes Schema (https) und entfernt abschließende Slashes,
  /// damit die Pfad-Kandidaten sauber angehängt werden können.
  String _normalisiereUrl(String eingabe) {
    var url = eingabe.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
