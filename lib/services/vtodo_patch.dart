import 'dart:math';

import 'package:enough_icalendar/enough_icalendar.dart';

import '../models/aufgabe.dart';

/// Eine Änderung am Roh-iCalendar einer Aufgabe: nimmt den Text vom Server
/// und liefert den geänderten Text. Als Funktion, damit sie bei einem
/// ETag-Konflikt (412) auf den frisch geholten Stand erneut angewendet
/// werden kann.
typedef IcalPatch = String Function(String ical);

/// Wendet [aenderung] auf die VTODO im iCalendar-Text an und erhöht dabei
/// SEQUENCE und setzt LAST-MODIFIED (Spec, Abschnitt 2 "Speichern/Sync").
///
/// Alle nicht angefassten Properties (X-APPLE-SORT-ORDER, CATEGORIES,
/// RELATED-TO, ...) bleiben erhalten: Das Dokument wird geparst, punktuell
/// geändert und komplett wieder serialisiert – nichts wird neu aufgebaut.
String patcheVTodo(
  String ical,
  void Function(VTodo vtodo) aenderung, {
  DateTime? jetzt,
}) {
  final komponente = VComponent.parse(ical);
  final VComponent wurzel;
  final VTodo vtodo;
  if (komponente is VCalendar) {
    wurzel = komponente;
    vtodo = komponente.children.whereType<VTodo>().first;
  } else if (komponente is VTodo) {
    wurzel = komponente;
    vtodo = komponente;
  } else {
    throw ArgumentError('Text enthält kein VTODO');
  }

  aenderung(vtodo);
  vtodo.sequence = (vtodo.sequence ?? 0) + 1;
  vtodo.lastModified = (jetzt ?? DateTime.now()).toUtc();

  return wurzel.toString();
}

/// Abhaken bzw. wieder öffnen.
IcalPatch erledigtPatch(bool erledigt, {DateTime? jetzt}) =>
    (ical) => patcheVTodo(ical, (vtodo) {
          if (erledigt) {
            vtodo.status = TodoStatus.completed;
            vtodo.percentComplete = 100;
            vtodo.completed = (jetzt ?? DateTime.now()).toUtc();
          } else {
            vtodo.status = TodoStatus.needsAction;
            vtodo.percentComplete = null;
            vtodo.completed = null;
          }
        }, jetzt: jetzt);

/// Titel ändern.
IcalPatch titelPatch(String titel) =>
    (ical) => patcheVTodo(ical, (vtodo) => _setzeText(vtodo, 'SUMMARY', titel));

/// Notiz ändern (leer = Property entfernen).
IcalPatch notizPatch(String notiz) => (ical) => patcheVTodo(
    ical,
    (vtodo) => _setzeText(vtodo, 'DESCRIPTION', notiz.isEmpty ? null : notiz));

/// Setzt eine Text-Property mit vollständigem RFC-5545-Escaping.
/// (Die Setter des Pakets escapen Semikolon und Backslash nicht.)
void _setzeText(VTodo vtodo, String name, String? wert) {
  vtodo.setOrRemoveProperty(
    name,
    wert == null ? null : TextProperty('$name:${_escapeText(wert)}'),
  );
}

/// Fälligkeit setzen oder (mit null) entfernen.
IcalPatch faelligPatch(DateTime? datum) =>
    (ical) => patcheVTodo(ical, (vtodo) => vtodo.due = datum);

/// "Wichtig" (Stern) setzen/entfernen – gespeichert als hohe Priorität
/// (PRIORITY 1). Beim Entfernen wird auch der FAVORITE-Marker aus
/// Bestandsdaten mit ausgeräumt, sonst bliebe der Stern hängen.
IcalPatch wichtigPatch(bool wichtig) =>
    (ical) => patcheVTodo(ical, (vtodo) {
          vtodo.priorityInt = wichtig ? 1 : null;
          if (!wichtig) {
            final kategorien =
                List<String>.from(vtodo.categories ?? const [])
                  ..removeWhere((k) => k == 'FAVORITE');
            vtodo.categories = kategorien.isEmpty ? null : kategorien;
          }
        });

/// "Mein Tag" setzen/entfernen – Marker `MYDAY-<heute>` in CATEGORIES.
/// Alte MYDAY-Marker (auch die alte Schreibweise FELIX-MYDAY-…) werden
/// dabei immer entfernt, so verfällt die Markierung über Nacht von selbst.
IcalPatch meinTagPatch(bool meinTag, {DateTime? heute}) =>
    (ical) => patcheVTodo(ical, (vtodo) {
          final kategorien = List<String>.from(vtodo.categories ?? const [])
            ..removeWhere((k) => k.contains('MYDAY-'));
          if (meinTag) {
            kategorien.add(Aufgabe.mydayMarker(heute ?? DateTime.now()));
          }
          vtodo.categories = kategorien.isEmpty ? null : kategorien;
        });

/// Schritt zur eigenständigen Aufgabe höherstufen: Der Eltern-Bezug
/// (RELATED-TO mit RELTYPE=PARENT oder ohne RELTYPE) wird entfernt
/// (Design-Doc, Abschnitt 4).
IcalPatch hochstufenPatch() => (ical) => patcheVTodo(ical, (vtodo) {
      vtodo.properties.removeWhere((prop) {
        if (prop.name != 'RELATED-TO') return false;
        final reltype = prop.parameters['RELTYPE'];
        return reltype == null ||
            (reltype is RelationshipParameter &&
                reltype.relationship == Relationship.parent);
      });
    });

/// Kopiert ein VTODO mit NEUER UID und (optional) umgehängtem Eltern-Bezug –
/// fürs Duplizieren einer Liste. SEQUENCE wird auf 0 gesetzt, LAST-MODIFIED
/// aktualisiert; alle übrigen Properties bleiben erhalten.
String kopiereVTodo(
  String ical, {
  required String neueUid,
  String? neuerParent,
  DateTime? jetzt,
}) {
  final komponente = VComponent.parse(ical);
  final VComponent wurzel;
  final VTodo vtodo;
  if (komponente is VCalendar) {
    wurzel = komponente;
    vtodo = komponente.children.whereType<VTodo>().first;
  } else if (komponente is VTodo) {
    wurzel = komponente;
    vtodo = komponente;
  } else {
    throw ArgumentError('Text enthält kein VTODO');
  }

  // UID ersetzen.
  vtodo.properties.removeWhere((p) => p.name == 'UID');
  vtodo.properties.add(TextProperty('UID:$neueUid'));

  // Eltern-Bezug (RELATED-TO PARENT / ohne RELTYPE) neu setzen.
  vtodo.properties.removeWhere((p) {
    if (p.name != 'RELATED-TO') return false;
    final reltype = p.parameters['RELTYPE'];
    return reltype == null ||
        (reltype is RelationshipParameter &&
            reltype.relationship == Relationship.parent);
  });
  if (neuerParent != null) {
    vtodo.properties.add(TextProperty('RELATED-TO;RELTYPE=PARENT:$neuerParent'));
  }

  vtodo.sequence = 0;
  vtodo.lastModified = (jetzt ?? DateTime.now()).toUtc();
  return wurzel.toString();
}

/// Erzeugt eine neue eindeutige UID für eine Aufgabe.
String neueUid() {
  final zufall = Random().nextInt(0xFFFFFF).toRadixString(16);
  return '${DateTime.now().millisecondsSinceEpoch}-$zufall@tickdone';
}

/// Erzeugt das iCalendar für eine neue Aufgabe bzw. einen neuen Schritt
/// (mit [parentUid] als RELATED-TO;RELTYPE=PARENT, Spec Abschnitt 2).
/// [sortOrder] setzt X-APPLE-SORT-ORDER (kleiner = weiter oben).
String neuesVTodoIcal({
  required String uid,
  required String titel,
  String? parentUid,
  int? sortOrder,
  DateTime? jetzt,
}) {
  final stempel = _utcStempel((jetzt ?? DateTime.now()).toUtc());
  final zeilen = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Tickdone//DE',
    'BEGIN:VTODO',
    'UID:$uid',
    'DTSTAMP:$stempel',
    'CREATED:$stempel',
    'LAST-MODIFIED:$stempel',
    'SUMMARY:${_escapeText(titel)}',
    'STATUS:NEEDS-ACTION',
    'SEQUENCE:0',
    if (sortOrder != null) 'X-APPLE-SORT-ORDER:$sortOrder',
    if (parentUid != null) 'RELATED-TO;RELTYPE=PARENT:$parentUid',
    'END:VTODO',
    'END:VCALENDAR',
    '',
  ];
  return zeilen.join('\r\n');
}

/// UTC-Zeitstempel im iCalendar-Format, z.B. 20260705T143000Z.
String _utcStempel(DateTime utc) {
  String zweistellig(int wert) => wert.toString().padLeft(2, '0');
  return '${utc.year}${zweistellig(utc.month)}${zweistellig(utc.day)}'
      'T${zweistellig(utc.hour)}${zweistellig(utc.minute)}'
      '${zweistellig(utc.second)}Z';
}

/// Escaped Text nach RFC 5545 (Backslash, Semikolon, Komma, Zeilenumbruch).
String _escapeText(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\n', '\\n');
