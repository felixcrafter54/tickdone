// Manueller CalDAV-Verbindungstest auf der Kommandozeile.
//
// Umgeht die CORS-Sperre des Browsers, indem er direkt auf der Dart-VM
// läuft – nutzt aber denselben CalDavService wie die App.
//
// Aufruf im Projektordner:  dart run tool/caldav_probe.dart
import 'dart:io';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/services/caldav_service.dart';

Future<void> main() async {
  stdout.write('Server-URL: ');
  final url = stdin.readLineSync() ?? '';
  stdout.write('Benutzername: ');
  final benutzer = stdin.readLineSync() ?? '';
  stdout.write('Passwort (Eingabe unsichtbar): ');
  stdin.echoMode = false;
  final passwort = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  stdout.writeln();

  final dienst = CalDavService();
  try {
    await dienst.verbinden(
      serverUrl: url,
      benutzer: benutzer,
      passwort: passwort,
    );
    stdout.writeln('Verbunden über: ${dienst.verbundeneUrl}');

    final listen = await dienst.ladeAufgabenlisten();
    stdout.writeln('Gefundene Aufgabenlisten (${listen.length}):');
    for (final liste in listen) {
      stdout.writeln('  - ${liste.displayName}'
          ' [${liste.supportedComponents.join(", ")}]');
    }

    // Aufgaben jeder Liste laden (je EIN REPORT) und als Baum ausgeben.
    for (final liste in listen) {
      final aufgaben = await dienst.ladeAufgaben(liste);
      stdout.writeln();
      stdout.writeln('${liste.displayName} (${aufgaben.length} Aufgaben):');
      final wurzeln = aufgaben.where((a) => !a.istSchritt);
      for (final aufgabe in wurzeln) {
        stdout.writeln('  ${_symbol(aufgabe)} ${aufgabe.titel}'
            '${_details(aufgabe)}');
        final schritte =
            aufgaben.where((s) => s.parentUid == aufgabe.uid);
        for (final schritt in schritte) {
          stdout.writeln('      ${_symbol(schritt)} ${schritt.titel}');
        }
      }
      // Verwaiste Schritte (Eltern-UID unbekannt) sichtbar machen.
      final bekannteUids = aufgaben.map((a) => a.uid).toSet();
      for (final verwaist in aufgaben.where((a) =>
          a.istSchritt && !bekannteUids.contains(a.parentUid))) {
        stdout.writeln('  ?? ${verwaist.titel}'
            ' (Eltern-UID ${verwaist.parentUid} nicht gefunden)');
      }
    }
  } catch (fehler) {
    stdout.writeln('FEHLER: $fehler');
    exitCode = 1;
  } finally {
    dienst.trennen();
  }
}

String _symbol(Aufgabe aufgabe) => aufgabe.erledigt ? '[x]' : '[ ]';

String _details(Aufgabe aufgabe) {
  final teile = <String>[
    if (aufgabe.favorit) 'Favorit',
    if (aufgabe.meinTag) 'Mein Tag',
    if (aufgabe.faellig != null) 'fällig ${aufgabe.faellig}',
    if (aufgabe.prioritaet != 0) 'Prio ${aufgabe.prioritaet}',
    if (aufgabe.sortOrder != null) 'Sort ${aufgabe.sortOrder}',
  ];
  return teile.isEmpty ? '' : '  (${teile.join(', ')})';
}
