import 'dart:math';

import 'package:enough_icalendar/enough_icalendar.dart';

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

/// Priorität ändern (0 = keine = Property entfernen).
IcalPatch prioritaetPatch(int prioritaet) => (ical) => patcheVTodo(
    ical,
    (vtodo) => vtodo.priorityInt = prioritaet == 0 ? null : prioritaet);

/// Fälligkeit setzen oder (mit null) entfernen.
IcalPatch faelligPatch(DateTime? datum) =>
    (ical) => patcheVTodo(ical, (vtodo) => vtodo.due = datum);

/// Erzeugt eine neue eindeutige UID für eine Aufgabe.
String neueUid() {
  final zufall = Random().nextInt(0xFFFFFF).toRadixString(16);
  return '${DateTime.now().millisecondsSinceEpoch}-$zufall@tickdone';
}

/// Erzeugt das iCalendar für eine neue Aufgabe bzw. einen neuen Schritt
/// (mit [parentUid] als RELATED-TO;RELTYPE=PARENT, Spec Abschnitt 2).
String neuesVTodoIcal({
  required String uid,
  required String titel,
  String? parentUid,
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
