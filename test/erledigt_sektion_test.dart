// Widget-Test für die einklappbare "Erledigt"-Sektion der Aufgabenliste.
import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tickdone/models/aufgabe.dart';
import 'package:tickdone/services/zugangsspeicher.dart';
import 'package:tickdone/state/app_state.dart';
import 'package:tickdone/ui/app_theme.dart';
import 'package:tickdone/ui/aufgaben_screen.dart';

class _FakeSpeicher extends Zugangsspeicher {
  @override
  Future<Zugang?> laden() async => null;
  @override
  Future<void> speichern({
    required String server,
    required String benutzer,
    required String passwort,
    String? aufloesung,
  }) async {}
  @override
  Future<void> loeschen() async {}
}

Aufgabe _aufgabe(String uid, {bool erledigt = false, int? sortOrder}) => Aufgabe(
      uid: uid,
      titel: uid,
      erledigt: erledigt,
      sortOrder: sortOrder,
      rohIcal: '',
    );

Widget _app(AppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: tickdoneTheme(),
        home: const AufgabenScreen(),
      ),
    );

void main() {
  AppState _mitAufgaben() {
    final state = AppState(_FakeSpeicher());
    state.aktiveListe = Calendar(
      uid: 'l1',
      href: Uri.parse('https://server/l1/'),
      displayName: 'Meine Liste',
      supportedComponents: const ['VTODO'],
    );
    state.aufgaben = [
      _aufgabe('Offen A', sortOrder: 1024),
      _aufgabe('Offen B', sortOrder: 2048),
      _aufgabe('Fertig X', erledigt: true, sortOrder: 512),
    ];
    return state;
  }

  testWidgets('Erledigte liegen eingeklappt unter "Erledigt N"',
      (tester) async {
    await tester.pumpWidget(_app(_mitAufgaben()));
    await tester.pump();

    // Offene Aufgaben sind sichtbar.
    expect(find.text('Offen A'), findsOneWidget);
    expect(find.text('Offen B'), findsOneWidget);

    // Erledigt-Kopf mit Anzahl da, erledigte Aufgabe aber (eingeklappt) NICHT.
    expect(find.text('Erledigt'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Fertig X'), findsNothing);
  });

  testWidgets('Tippen auf den Kopf klappt die erledigten Aufgaben auf',
      (tester) async {
    await tester.pumpWidget(_app(_mitAufgaben()));
    await tester.pump();

    await tester.tap(find.text('Erledigt'));
    await tester.pumpAndSettle();

    expect(find.text('Fertig X'), findsOneWidget);
  });
}
