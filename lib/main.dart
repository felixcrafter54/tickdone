import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/einstellungen_speicher.dart';
import 'state/app_state.dart';
import 'ui/app_theme.dart';
import 'ui/start_screen.dart';

void main() {
  runApp(const TickdoneApp());
}

/// Einstiegspunkt: stellt den AppState per Provider bereit und startet mit
/// dem Start-Screen (versucht automatische Anmeldung).
class TickdoneApp extends StatelessWidget {
  const TickdoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, app, _) => MaterialApp(
          title: 'Tickdone',
          // Karten bleiben am Listenrand formstabil (kein Stretch).
          scrollBehavior: const TickdoneScrollBehavior(),
          // Helles + dunkles Theme, Auswahl per Einstellung.
          theme: tickdoneThemeHell(),
          darkTheme: tickdoneTheme(),
          themeMode: switch (app.einstellungen.theme) {
            ThemeWahl.hell => ThemeMode.light,
            ThemeWahl.dunkel => ThemeMode.dark,
            ThemeWahl.system => ThemeMode.system,
          },
          home: const StartScreen(),
        ),
      ),
    );
  }
}
