// Manueller CalDAV-Verbindungstest auf der Kommandozeile.
//
// Umgeht die CORS-Sperre des Browsers, indem er direkt auf der Dart-VM
// läuft – nutzt aber denselben CalDavService wie die App.
//
// Aufruf im Projektordner:  dart run tool/caldav_probe.dart
import 'dart:io';

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
  } catch (fehler) {
    stdout.writeln('FEHLER: $fehler');
    exitCode = 1;
  } finally {
    dienst.trennen();
  }
}
