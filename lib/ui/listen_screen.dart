import 'package:caldav/caldav.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'login_screen.dart';

/// Übersicht der Aufgabenlisten (Collections mit VTODO) nach der Anmeldung.
///
/// Antippen einer Liste lädt später deren Aufgaben (Spec, Schritt 3).
class ListenScreen extends StatelessWidget {
  const ListenScreen({super.key});

  void _abmelden(BuildContext context) {
    context.read<AppState>().abmelden();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final listen = appState.aufgabenlisten;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Listen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Abmelden',
            onPressed: () => _abmelden(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (appState.fehlermeldung != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                appState.fehlermeldung!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<AppState>().listenNeuLaden(),
              child: listen.isEmpty
                  // ListView statt Text, damit Pull-to-Refresh auch bei
                  // leerer Liste funktioniert.
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Keine Aufgabenlisten gefunden.\n'
                            'Zum Aktualisieren nach unten ziehen.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: listen.length,
                      itemBuilder: (context, index) {
                        final liste = listen[index];
                        return ListTile(
                          leading: Icon(
                            Icons.checklist,
                            color: _farbeVon(liste) ??
                                Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(liste.displayName),
                          subtitle: (liste.description?.isNotEmpty ?? false)
                              ? Text(liste.description!)
                              : null,
                          onTap: () {
                            // Aufgaben laden kommt in Schritt 3 der Spec.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '"${liste.displayName}" – Aufgaben laden '
                                    'folgt im nächsten Schritt.'),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wandelt die Kalenderfarbe (#RRGGBB oder #RRGGBBAA) in eine
  /// Flutter-Farbe um. Liefert null bei fehlender/ungültiger Angabe.
  Color? _farbeVon(Calendar liste) {
    final hex = liste.color;
    if (hex == null || !hex.startsWith('#')) return null;
    final wert = hex.substring(1);
    try {
      if (wert.length == 6) {
        return Color(int.parse('FF$wert', radix: 16));
      }
      if (wert.length == 8) {
        // #RRGGBBAA → Flutter erwartet AARRGGBB
        return Color(int.parse(wert.substring(6) + wert.substring(0, 6),
            radix: 16));
      }
    } on FormatException {
      // Ungültige Farbangabe vom Server – einfach Standardfarbe nutzen.
    }
    return null;
  }
}
