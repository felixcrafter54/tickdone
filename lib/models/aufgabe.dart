import 'package:enough_icalendar/enough_icalendar.dart';

/// Eine Aufgabe (VTODO) im App-Model (Spec, Abschnitt 4).
///
/// Das Original-iCalendar vom Server bleibt in [rohIcal] erhalten, damit beim
/// späteren Speichern keine unbekannten Properties verloren gehen
/// (z.B. X-APPLE-SORT-ORDER, CATEGORIES-Marker – Spec, Abschnitt 2 und 5).
class Aufgabe {
  final String uid;
  final String titel;
  final bool erledigt;

  /// UID der Eltern-Aufgabe (RELATED-TO;RELTYPE=PARENT) –
  /// null bei Wurzel-Aufgaben.
  final String? parentUid;
  final DateTime? faellig;

  /// 0 = keine, 1 = hoch, 5 = mittel, 9 = niedrig.
  final int prioritaet;
  final String notiz;

  /// PERCENT-COMPLETE, 0..100.
  final int prozent;

  /// Änderungszähler (SEQUENCE) – wird beim Speichern erhöht.
  final int sequence;

  /// Manuelle Reihenfolge (X-APPLE-SORT-ORDER), null wenn nicht gesetzt.
  final int? sortOrder;

  /// CATEGORIES enthält den Marker FAVORITE.
  final bool favorit;

  /// CATEGORIES enthält `MYDAY-<heute>` – verfällt damit über Nacht von selbst.
  final bool meinTag;
  final DateTime? erstellt;
  final String? etag;
  final Uri? href;

  /// Unverändertes iCalendar vom Server.
  final String rohIcal;

  const Aufgabe({
    required this.uid,
    required this.titel,
    required this.erledigt,
    this.parentUid,
    this.faellig,
    this.prioritaet = 0,
    this.notiz = '',
    this.prozent = 0,
    this.sequence = 0,
    this.sortOrder,
    this.favorit = false,
    this.meinTag = false,
    this.erstellt,
    this.etag,
    this.href,
    required this.rohIcal,
  });

  /// Schritte (Subtasks) sind Aufgaben mit Eltern-Verweis.
  bool get istSchritt => parentUid != null;

  /// Parst das iCalendar einer VTODO-Ressource vom Server.
  ///
  /// Liefert null, wenn der Text keine VTODO enthält.
  /// [heute] ist nur für Tests gedacht (Standard: aktuelles Datum).
  static Aufgabe? ausICalendar(
    String ical, {
    String? etag,
    Uri? href,
    DateTime? heute,
  }) {
    final komponente = VComponent.parse(ical);
    VTodo? vtodo;
    if (komponente is VCalendar) {
      vtodo = komponente.children.whereType<VTodo>().firstOrNull;
    } else if (komponente is VTodo) {
      vtodo = komponente;
    }
    if (vtodo == null) return null;

    final kategorien = vtodo.categories ?? const <String>[];
    final tagesMarker = mydayMarker(heute ?? DateTime.now());

    return Aufgabe(
      uid: vtodo.uid,
      titel: vtodo.summary ?? '',
      // STATUS kann fehlen – dann gilt die Aufgabe als offen (Spec).
      erledigt: vtodo.status == TodoStatus.completed,
      parentUid: _parentUidVon(vtodo),
      faellig: vtodo.due,
      prioritaet: vtodo.priorityInt ?? 0,
      notiz: vtodo.description ?? '',
      prozent: vtodo.percentComplete ?? 0,
      sequence: vtodo.sequence ?? 0,
      sortOrder: _parseSortOrder(
          vtodo.getProperty('X-APPLE-SORT-ORDER')?.textValue),
      favorit: kategorien.contains('FAVORITE'),
      meinTag: kategorien.contains(tagesMarker),
      erstellt: vtodo.created,
      etag: etag,
      href: href,
      rohIcal: ical,
    );
  }

  /// Der "Mein Tag"-Marker für ein Datum, z.B. MYDAY-2026-07-05.
  static String mydayMarker(DateTime tag) {
    final monat = tag.month.toString().padLeft(2, '0');
    final t = tag.day.toString().padLeft(2, '0');
    return 'MYDAY-${tag.year}-$monat-$t';
  }

  /// Manche Clients schreiben X-APPLE-SORT-ORDER als Kommazahl
  /// (z.B. "3072.0") – deshalb über num parsen und runden.
  static int? _parseSortOrder(String? wert) {
    if (wert == null || wert.isEmpty) return null;
    return num.tryParse(wert)?.round();
  }

  /// Ermittelt die Eltern-UID aus den RELATED-TO-Properties.
  ///
  /// jtx Board schreibt RELATED-TO teils mehrwertig (PARENT und CHILD).
  /// Nur der Eintrag mit RELTYPE=PARENT – oder ganz ohne RELTYPE –
  /// zählt als Elternverweis (Spec, Abschnitt 2).
  static String? _parentUidVon(VTodo vtodo) {
    for (final prop in vtodo.getProperties<TextProperty>('RELATED-TO')) {
      final reltype = prop.parameters['RELTYPE'];
      final istParent = reltype == null ||
          (reltype is RelationshipParameter &&
              reltype.relationship == Relationship.parent);
      if (istParent && prop.text.isNotEmpty) {
        return prop.text;
      }
    }
    return null;
  }
}
