import 'package:caldav/caldav.dart';

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
  /// Probiert nacheinander: eingegebene URL → `<basis>/caldav` →
  /// `<basis>/radicale`. Bei falschen Zugangsdaten (401) wird sofort
  /// abgebrochen, weitere Pfade zu probieren bringt dann nichts.
  Future<void> verbinden({
    required String serverUrl,
    required String benutzer,
    required String passwort,
  }) async {
    trennen();
    final basis = _normalisiereUrl(serverUrl);
    final kandidaten = <String>[
      basis,
      '$basis/caldav',
      '$basis/radicale',
    ];

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
