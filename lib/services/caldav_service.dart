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
    final kandidaten = <String>[basis];
    final wellKnownZiel = await _loeseWellKnownAuf(basis, benutzer, passwort);
    if (wellKnownZiel != null && !kandidaten.contains(wellKnownZiel)) {
      kandidaten.add(wellKnownZiel);
    }
    kandidaten.addAll(['$basis/caldav', '$basis/radicale']);

    Object? letzterFehler;
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
        letzterFehler = fehler;
      } catch (fehler) {
        letzterFehler = fehler;
      }
    }
    throw Exception('Keine CalDAV-Verbindung zu "$basis" möglich. '
        'Letzter Fehler: $letzterFehler');
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
  Future<String?> _loeseWellKnownAuf(
      String basis, String benutzer, String passwort) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      followRedirects: false,
      // 3xx nicht als Fehler werten – genau die wollen wir ja sehen.
      validateStatus: (status) => status != null && status < 400,
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$benutzer:$passwort'))}',
      },
    ));
    final wellKnownUrl = '$basis/.well-known/caldav';
    try {
      final antwort = await dio.get<void>(wellKnownUrl);
      const redirects = {301, 302, 307, 308};
      if (redirects.contains(antwort.statusCode)) {
        final ziel = antwort.headers.value('location');
        if (ziel != null && ziel.isNotEmpty) {
          final aufgeloest = Uri.parse('$basis/').resolve(ziel).toString();
          return _normalisiereUrl(aufgeloest);
        }
      }
      // 2xx ohne Redirect: .well-known ist selbst der Endpunkt.
      if (antwort.statusCode != null && antwort.statusCode! < 300) {
        return wellKnownUrl;
      }
    } catch (_) {
      // Kein .well-known vorhanden – dann eben ohne diesen Kandidaten.
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
