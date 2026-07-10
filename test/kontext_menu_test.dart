// Widget-Test der gemeinsamen Kontextmenü-Komponente.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tickdone/ui/app_theme.dart';
import 'package:tickdone/ui/kontext_menu.dart';

void main() {
  testWidgets('KontextMenuKnopf öffnet das Menü und löst die Aktion aus',
      (tester) async {
    var umbenannt = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: tickdoneTheme(),
        home: Scaffold(
          body: KontextMenuKnopf(
            tooltip: 'Aktionen',
            eintraege: [
              KontextAktion(
                icon: Icons.edit_outlined,
                text: 'Umbenennen',
                onTap: () => umbenannt = true,
              ),
              const KontextTrenner(),
              KontextAktion(
                icon: Icons.delete_outline,
                text: 'Löschen',
                rot: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    // Menü über den Drei-Punkte-Button öffnen.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Umbenennen'), findsOneWidget);
    expect(find.text('Löschen'), findsOneWidget);

    // Aktion auslösen.
    await tester.tap(find.text('Umbenennen'));
    await tester.pumpAndSettle();
    expect(umbenannt, isTrue);
  });
}
