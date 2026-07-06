// Smoke-Tests für den Anmeldebildschirm.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:tickdone/state/app_state.dart';
import 'package:tickdone/services/zugangsspeicher.dart';
import 'package:tickdone/ui/login_screen.dart';

/// Speicher-Attrappe: liefert nie gespeicherte Zugangsdaten und schreibt
/// nichts (kein Plugin-Kanal im Test).
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

Widget _loginApp() => ChangeNotifierProvider(
      create: (_) => AppState(_FakeSpeicher()),
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  testWidgets('Anmeldebildschirm wird angezeigt', (tester) async {
    await tester.pumpWidget(_loginApp());

    expect(find.text('Server-URL'), findsOneWidget);
    expect(find.text('Benutzername'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Verbinden'), findsOneWidget);
  });

  testWidgets('Leere Eingaben zeigen Validierungsfehler', (tester) async {
    await tester.pumpWidget(_loginApp());

    await tester.tap(find.text('Verbinden'));
    await tester.pump();

    expect(find.text('Bitte Server-URL eingeben'), findsOneWidget);
    expect(find.text('Bitte Benutzername eingeben'), findsOneWidget);
    expect(find.text('Bitte Passwort eingeben'), findsOneWidget);
  });
}
