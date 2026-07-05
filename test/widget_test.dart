// Smoke-Tests für den Anmeldebildschirm.
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/main.dart';

void main() {
  testWidgets('Anmeldebildschirm wird beim Start angezeigt', (tester) async {
    await tester.pumpWidget(const TickdoneApp());

    expect(find.text('Server-URL'), findsOneWidget);
    expect(find.text('Benutzername'), findsOneWidget);
    expect(find.text('Passwort'), findsOneWidget);
    expect(find.text('Verbinden'), findsOneWidget);
  });

  testWidgets('Leere Eingaben zeigen Validierungsfehler', (tester) async {
    await tester.pumpWidget(const TickdoneApp());

    await tester.tap(find.text('Verbinden'));
    await tester.pump();

    expect(find.text('Bitte Server-URL eingeben'), findsOneWidget);
    expect(find.text('Bitte Benutzername eingeben'), findsOneWidget);
    expect(find.text('Bitte Passwort eingeben'), findsOneWidget);
  });
}
