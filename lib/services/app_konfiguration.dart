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
      return anzeigeHost(map['caldavHost'] as String?);
    } catch (_) {
      // Kein Config-Endpunkt (z.B. lokaler Dev-Server) – dann kein Host.
      return null;
    }
  }

  /// Der anzuzeigende Host – GENAU SO, wie er in der Deploy-ENV `CALDAV_HOST`
  /// eingetragen wurde (nur Leerraum getrimmt). Leerer Wert oder eine nicht
  /// ersetzte envsubst-Variable (`$` `{CALDAV_HOST}`) ergibt `null`, damit
  /// stattdessen der Fallback greift.
  static String? anzeigeHost(String? wert) {
    if (wert == null) return null;
    final s = wert.trim();
    if (s.isEmpty || s.contains(r'${')) return null;
    return s;
  }
}
