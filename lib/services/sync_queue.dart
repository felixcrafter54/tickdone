// Offline-Sync-Queue: sammelt Änderungen, die (noch) nicht zum Server
// geschrieben werden konnten, damit sie später verlustfrei nachgeholt werden.
//
// Bewusst kein Patch-Objekt (Patches sind Funktionen, nicht serialisierbar).
// Stattdessen wird die konkrete HTTP-Absicht gespeichert: das fertige
// Ziel-iCalendar (das die App bei optimistischen Updates ohnehin baut) plus
// href und ETag-Vorbedingung. So überlebt eine Änderung auch einen Neustart.

/// Art einer ausstehenden Änderung.
enum AenderungsArt {
  /// Ressource anlegen oder überschreiben (PUT mit [AusstehendeAenderung.ical]).
  put,

  /// Ressource löschen (DELETE).
  loeschen,
}

/// Eine einzelne ausstehende Änderung an genau einer Aufgabe.
class AusstehendeAenderung {
  final AenderungsArt art;

  /// UID der betroffenen Aufgabe – dient dem Zusammenfassen (nur EINE
  /// ausstehende Änderung je Aufgabe) und der Anzeige.
  final String uid;

  /// Ziel-Ressource (`.ics`-URL) als String.
  final String href;

  /// Fertiges Ziel-iCalendar bei [AenderungsArt.put]; null beim Löschen.
  final String? ical;

  /// ETag-Vorbedingung (If-Match) – der zuletzt bekannte Serverstand.
  /// null, wenn keiner bekannt ist (z.B. Neuanlage).
  final String? ifMatch;

  /// true = Neuanlage: PUT mit `If-None-Match: *` (darf nichts überschreiben).
  final bool neu;

  /// Zeitpunkt der ersten Erfassung (Reihenfolge/Debug).
  final DateTime erstellt;

  const AusstehendeAenderung({
    required this.art,
    required this.uid,
    required this.href,
    this.ical,
    this.ifMatch,
    this.neu = false,
    required this.erstellt,
  });

  Map<String, dynamic> toJson() => {
        'art': art.name,
        'uid': uid,
        'href': href,
        'ical': ical,
        'ifMatch': ifMatch,
        'neu': neu,
        'erstellt': erstellt.toIso8601String(),
      };

  static AusstehendeAenderung vonJson(Map<String, dynamic> j) =>
      AusstehendeAenderung(
        art: AenderungsArt.values.firstWhere(
          (a) => a.name == j['art'],
          orElse: () => AenderungsArt.put,
        ),
        uid: j['uid'] as String,
        href: j['href'] as String,
        ical: j['ical'] as String?,
        ifMatch: j['ifMatch'] as String?,
        neu: j['neu'] as bool? ?? false,
        erstellt: DateTime.tryParse(j['erstellt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Verwaltet die ausstehenden Änderungen im Speicher (Persistenz erledigt der
/// Aufrufer über [zuJson]/[SyncQueue.ausJson]).
///
/// Kernidee: Je Aufgabe gibt es höchstens EINE ausstehende Änderung. Neue
/// Änderungen werden mit der bestehenden zusammengefasst ("collapse") – so
/// entfällt das fehleranfällige Aneinanderreihen vieler PUTs mit veralteten
/// ETags, und die Queue bleibt klein.
class SyncQueue {
  final List<AusstehendeAenderung> _liste;

  SyncQueue([List<AusstehendeAenderung>? start])
      : _liste = List<AusstehendeAenderung>.from(start ?? const []);

  List<AusstehendeAenderung> get ausstehend => List.unmodifiable(_liste);
  bool get istLeer => _liste.isEmpty;
  int get anzahl => _liste.length;

  int _indexVon(String uid) => _liste.indexWhere((a) => a.uid == uid);

  /// Anlegen/Ändern vormerken. Bei bereits vorhandener Änderung derselben
  /// Aufgabe wird zusammengefasst: Eine Neuanlage bleibt Neuanlage, sonst wird
  /// der zuerst bekannte Server-ETag beibehalten und nur das iCal aktualisiert.
  void merkePut({
    required String uid,
    required String href,
    required String ical,
    String? ifMatch,
    bool neu = false,
    DateTime? jetzt,
  }) {
    final index = _indexVon(uid);
    if (index >= 0) {
      final alt = _liste[index];
      final bleibtNeu = (alt.art == AenderungsArt.put && alt.neu) || neu;
      _liste[index] = AusstehendeAenderung(
        art: AenderungsArt.put,
        uid: uid,
        href: href,
        ical: ical,
        neu: bleibtNeu,
        // Neuanlage hat keinen ETag; sonst den bereits gemerkten behalten.
        ifMatch: bleibtNeu
            ? null
            : (alt.art == AenderungsArt.put ? alt.ifMatch : ifMatch),
        erstellt: alt.erstellt,
      );
    } else {
      _liste.add(AusstehendeAenderung(
        art: AenderungsArt.put,
        uid: uid,
        href: href,
        ical: ical,
        neu: neu,
        ifMatch: neu ? null : ifMatch,
        erstellt: jetzt ?? DateTime.now(),
      ));
    }
  }

  /// Löschen vormerken. War die Aufgabe nur lokal neu (noch nie am Server),
  /// wird die ausstehende Neuanlage einfach verworfen – es gibt nichts zu tun.
  void merkeLoeschen({
    required String uid,
    required String href,
    String? ifMatch,
    DateTime? jetzt,
  }) {
    final index = _indexVon(uid);
    if (index >= 0) {
      final alt = _liste[index];
      if (alt.art == AenderungsArt.put && alt.neu) {
        _liste.removeAt(index);
        return;
      }
      _liste[index] = AusstehendeAenderung(
        art: AenderungsArt.loeschen,
        uid: uid,
        href: href,
        ifMatch: ifMatch ?? alt.ifMatch,
        erstellt: alt.erstellt,
      );
    } else {
      _liste.add(AusstehendeAenderung(
        art: AenderungsArt.loeschen,
        uid: uid,
        href: href,
        ifMatch: ifMatch,
        erstellt: jetzt ?? DateTime.now(),
      ));
    }
  }

  /// Eine Änderung nach erfolgreichem Sync entfernen (per UID).
  void entferne(String uid) => _liste.removeWhere((a) => a.uid == uid);

  void leeren() => _liste.clear();

  List<Map<String, dynamic>> zuJson() =>
      [for (final a in _liste) a.toJson()];

  static SyncQueue ausJson(List<dynamic> roh) => SyncQueue([
        for (final j in roh)
          AusstehendeAenderung.vonJson(j as Map<String, dynamic>),
      ]);
}
