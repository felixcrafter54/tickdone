import 'dart:convert';

import 'package:caldav/caldav.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/aufgabe.dart';
import 'sync_queue.dart';

/// Ein lokal gespeicherter Schnappschuss der zuletzt vom Server geladenen
/// Daten: die Aufgabenlisten und die Aufgaben je Liste. Damit startet die App
/// sofort mit den letzten Daten und zeigt sie auch ohne Verbindung (lesend).
class Schnappschuss {
  final List<Calendar> listen;

  /// Aufgaben je Listen-UID (wie [AppState._cacheProListe]).
  final Map<String, List<Aufgabe>> aufgabenProListe;

  const Schnappschuss({required this.listen, required this.aufgabenProListe});
}

/// Persistiert den Schnappschuss über `shared_preferences` – funktioniert mit
/// EINER Codebasis auf Android, Desktop und (später) Web.
///
/// Der Cache ist reine Optimierung: Schlägt Lesen/Schreiben fehl, arbeitet die
/// App normal weiter (Fehler werden bewusst verschluckt).
class LokalerSpeicher {
  static const _schluessel = 'tickdone.schnappschuss.v1';
  static const _queueSchluessel = 'tickdone.syncqueue.v1';

  /// Optional injizierte Instanz (für Tests). Sonst wird sie erst bei Bedarf
  /// geholt – so löst der Konstruktor ohne Flutter-Binding keinen Fehler aus.
  final Future<SharedPreferences>? _injiziert;

  LokalerSpeicher([Future<SharedPreferences>? prefs]) : _injiziert = prefs;

  Future<SharedPreferences> _prefs() =>
      _injiziert ?? SharedPreferences.getInstance();

  /// Schnappschuss speichern.
  Future<void> speichern(Schnappschuss schnappschuss) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(_schluessel, jsonEncode(_zuJson(schnappschuss)));
    } catch (_) {
      // Cache ist optional – Fehler ignorieren.
    }
  }

  /// Schnappschuss laden – null, wenn keiner da oder er nicht lesbar ist.
  Future<Schnappschuss?> laden() async {
    try {
      final prefs = await _prefs();
      final text = prefs.getString(_schluessel);
      if (text == null || text.isEmpty) return null;
      return _vonJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Cache UND Sync-Queue leeren (z.B. beim Abmelden).
  Future<void> loeschen() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(_schluessel);
      await prefs.remove(_queueSchluessel);
    } catch (_) {
      // Ignorieren.
    }
  }

  /// Ausstehende Änderungen (Sync-Queue) speichern.
  Future<void> speichereQueue(SyncQueue queue) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(_queueSchluessel, jsonEncode(queue.zuJson()));
    } catch (_) {
      // Queue ist optional persistiert – Fehler ignorieren.
    }
  }

  /// Ausstehende Änderungen laden – leere Queue, wenn nichts da/lesbar ist.
  Future<SyncQueue> ladeQueue() async {
    try {
      final prefs = await _prefs();
      final text = prefs.getString(_queueSchluessel);
      if (text == null || text.isEmpty) return SyncQueue();
      return SyncQueue.ausJson(jsonDecode(text) as List<dynamic>);
    } catch (_) {
      return SyncQueue();
    }
  }

  Map<String, dynamic> _zuJson(Schnappschuss s) => {
        'version': 1,
        'listen': [for (final l in s.listen) _listeZuJson(l)],
        'aufgaben': {
          for (final eintrag in s.aufgabenProListe.entries)
            eintrag.key: [for (final a in eintrag.value) _aufgabeZuJson(a)],
        },
      };

  Schnappschuss _vonJson(Map<String, dynamic> j) {
    final listen = [
      for (final l in (j['listen'] as List? ?? const []))
        _listeVonJson(l as Map<String, dynamic>),
    ];
    final aufgaben = <String, List<Aufgabe>>{};
    final roh = j['aufgaben'] as Map<String, dynamic>? ?? const {};
    for (final eintrag in roh.entries) {
      final liste = <Aufgabe>[];
      for (final a in (eintrag.value as List)) {
        final aufgabe = _aufgabeVonJson(a as Map<String, dynamic>);
        if (aufgabe != null) liste.add(aufgabe);
      }
      aufgaben[eintrag.key] = liste;
    }
    return Schnappschuss(listen: listen, aufgabenProListe: aufgaben);
  }

  Map<String, dynamic> _listeZuJson(Calendar c) => {
        'uid': c.uid,
        'href': c.href.toString(),
        'displayName': c.displayName,
        'description': c.description,
        'color': c.color,
        'supportedComponents': c.supportedComponents,
        'timezone': c.timezone,
        'ctag': c.ctag,
        'isReadOnly': c.isReadOnly,
      };

  Calendar _listeVonJson(Map<String, dynamic> j) => Calendar(
        uid: j['uid'] as String,
        href: Uri.parse(j['href'] as String),
        displayName: j['displayName'] as String? ?? '',
        description: j['description'] as String?,
        color: j['color'] as String?,
        supportedComponents:
            (j['supportedComponents'] as List?)?.cast<String>() ??
                const ['VTODO'],
        timezone: j['timezone'] as String?,
        ctag: j['ctag'] as String?,
        isReadOnly: j['isReadOnly'] as bool? ?? false,
      );

  // Quelle der Wahrheit je Aufgabe ist das Roh-iCalendar (+ ETag + href);
  // das Model wird daraus per Aufgabe.ausICalendar rekonstruiert.
  Map<String, dynamic> _aufgabeZuJson(Aufgabe a) => {
        'ical': a.rohIcal,
        'etag': a.etag,
        'href': a.href?.toString(),
      };

  Aufgabe? _aufgabeVonJson(Map<String, dynamic> j) {
    final hrefText = j['href'] as String?;
    return Aufgabe.ausICalendar(
      j['ical'] as String,
      etag: j['etag'] as String?,
      href: hrefText != null ? Uri.parse(hrefText) : null,
    );
  }
}
