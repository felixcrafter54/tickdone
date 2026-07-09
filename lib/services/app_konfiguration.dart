import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Läuft die App als Same-Origin-PWA im Web, kennt sie den echten CalDAV-Host
/// nicht (die Verbindung geht über den Proxy `/caldav/`). Der Deploy legt ihn
/// in der Umgebungsvariablen `CALDAV_HOST` ab; der nginx liefert ihn als
/// `/app-config.json`. So kann die Anmeldung „Verbunden mit `<host>`" zeigen.
class AppKonfiguration {
  /// Holt den anzuzeigenden CalDAV-Host (nur im Web sinnvoll). Gibt den
  /// normalisierten Host zurück oder `null`, wenn er nicht ermittelbar ist.
  static Future<String?> ladeCaldavHost({Dio? dio}) async {
    if (!kIsWeb) return null;
    try {
      final client = dio ?? Dio();
      final antwort = await client.get<dynamic>(
        '/app-config.json',
        options: Options(responseType: ResponseType.plain),
      );
      final daten = antwort.data;
      final map = daten is String
          ? jsonDecode(daten) as Map<String, dynamic>
          : (daten as Map).cast<String, dynamic>();
      return normalisiereHost(map['caldavHost'] as String?);
    } catch (_) {
      // Kein Config-Endpunkt (z.B. lokaler Dev-Server) – dann kein Host.
      return null;
    }
  }

  /// Bereitet den Host für die Anzeige auf – tolerant gegenüber dem, was
  /// verschiedene Dienste (OpenCloud/ownCloud, Nextcloud, Radicale, Baïkal …)
  /// ausgeben: mit oder ohne Schema (`https://`), mit oder ohne Pfad, mit oder
  /// ohne End-Slash. Ergebnis ist Host (plus evtl. Pfad) ohne Schema/Slashes.
  static String? normalisiereHost(String? wert) {
    if (wert == null) return null;
    var s = wert.trim();
    // Leer oder eine nicht ersetzte envsubst-Variable ($ {CALDAV_HOST}) →
    // nichts anzeigen.
    if (s.isEmpty || s.contains(r'${')) return null;
    // Schema (http://, https://, …) entfernen.
    s = s.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://'), '');
    // Führende und abschließende Slashes entfernen.
    s = s.replaceAll(RegExp(r'^/+|/+$'), '');
    return s.isEmpty ? null : s;
  }
}
